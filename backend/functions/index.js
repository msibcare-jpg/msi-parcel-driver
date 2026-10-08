/**
 * MSI Parcel — Cloud Functions (server side).
 *
 * onOrderCreated   : secret 4-digit delivery code (orders/{id}/private/otp)
 *                    and the official delivery fee, recalculated on the server.
 * completeDelivery : driver sends the receiver's code; the server checks it
 *                    (5 tries max), marks the order delivered and books the money:
 *                      driver   +earning (driverSharePct of the fee), −COD cash held
 *                      customer +COD collected for them, −delivery fee
 * settleDriverCash : admin records cash handed over by a driver.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });
const db = getFirestore();

const MAX_TRIES = 5;
const round2 = (n) => Math.round(n * 100) / 100;

async function pricingRules() {
  const snap = await db.doc("pricing_rules/default").get();
  const p = snap.exists ? snap.data() : {};
  return {
    freeKg: p.freeKg ?? 5,
    perKgFee: p.perKgFee ?? 2,
    codFeePct: p.codFeePct ?? 1,
    driverSharePct: p.driverSharePct ?? 80,
  };
}

async function zoneBaseFee(city) {
  const q = await db.collection("service_zones").where("name", "==", city).limit(1).get();
  if (q.empty) return 20;
  return Number(q.docs[0].get("baseFee") ?? 20);
}

exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const orderId = event.params.orderId;
  const order = event.data ? event.data.data() : {};
  const code = String(crypto.randomInt(1000, 10000));
  await db.doc(`orders/${orderId}/private/otp`).set({
    code,
    tries: 0,
    createdAt: FieldValue.serverTimestamp(),
  });
  // Official fee: never trust the price sent by the phone.
  const p = await pricingRules();
  const base = await zoneBaseFee(order.city || "");
  const kg = Number(order.weightKg || 0);
  const cod = Number(order.codAmount || 0);
  const fee = round2(base + Math.max(0, kg - p.freeKg) * p.perKgFee + (cod * p.codFeePct) / 100);
  await db.doc(`orders/${orderId}`).update({ deliveryFee: fee });
});

function tx(t, uid, type, amount, order, note) {
  const ref = db.collection("wallet_transactions").doc();
  t.set(ref, {
    uid,
    type,
    amount: round2(amount),
    orderId: order.id || "",
    orderCode: order.code || "",
    note: note || "",
    createdAt: FieldValue.serverTimestamp(),
  });
  t.set(db.doc(`wallets/${uid}`), {
    balance: FieldValue.increment(round2(amount)),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

exports.completeDelivery = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in again.");

  const orderId = String((request.data && request.data.orderId) || "");
  const otp = String((request.data && request.data.otp) || "").trim();
  const codCollected = request.data && request.data.codCollected === true;
  if (!orderId || !/^\d{4}$/.test(otp)) {
    throw new HttpsError("invalid-argument", "Enter the 4-digit delivery code.");
  }
  const p = await pricingRules();

  const driverRef = db.doc(`drivers/${uid}`);
  const orderRef = db.doc(`orders/${orderId}`);
  const otpRef = db.doc(`orders/${orderId}/private/otp`);

  const result = await db.runTransaction(async (t) => {
    const [driverSnap, orderSnap, otpSnap] = await Promise.all([t.get(driverRef), t.get(orderRef), t.get(otpRef)]);
    if (!driverSnap.exists || driverSnap.get("status") !== "approved") {
      throw new HttpsError("permission-denied", "Your driver account is not active.");
    }
    if (!orderSnap.exists) throw new HttpsError("not-found", "Order not found.");
    const order = { id: orderId, ...orderSnap.data() };
    if (order.driverId !== uid) throw new HttpsError("permission-denied", "This order is not assigned to you.");
    if (order.status !== "out_for_delivery") throw new HttpsError("failed-precondition", "Start the delivery first.");
    if (!otpSnap.exists) throw new HttpsError("failed-precondition", "This order has no delivery code. Call the office.");

    const tries = otpSnap.get("tries") || 0;
    if (tries >= MAX_TRIES) {
      throw new HttpsError("resource-exhausted", "Too many wrong codes. Call the office to unlock.");
    }
    if (otpSnap.get("code") !== otp) {
      t.update(otpRef, { tries: tries + 1 });
      return { ok: false, message: `Wrong delivery code. ${MAX_TRIES - tries - 1} tries left.` };
    }
    const cod = Number(order.codAmount || 0);
    if (cod > 0 && !codCollected) {
      throw new HttpsError("failed-precondition", "Confirm that you collected the cash.");
    }
    const fee = Number(order.deliveryFee || 0);
    const earning = round2((fee * p.driverSharePct) / 100);

    const now = FieldValue.serverTimestamp();
    t.update(orderRef, {
      status: "delivered",
      deliveredAt: now,
      updatedAt: now,
      codCollected: cod > 0,
      codSettled: false,
      driverEarning: earning,
    });
    t.update(otpRef, { usedAt: now });
    t.set(db.collection("order_events").doc(), {
      orderId, status: "delivered", actorId: uid, actorRole: "driver", createdAt: now,
    });

    // Money
    tx(t, uid, "earning", earning, order);
    if (cod > 0) {
      tx(t, uid, "cod_collected", -cod, order);
      t.set(db.collection("cod_transactions").doc(orderId), {
        orderId, driverId: uid, customerId: order.customerId || "", amount: cod,
        status: "with_driver", collectedAt: now,
      });
    }
    if (order.customerId) {
      if (cod > 0) tx(t, order.customerId, "cod_received", cod, order);
      tx(t, order.customerId, "delivery_fee", -fee, order);
    }
    return { ok: true };
  });
  if (result.ok === false) throw new HttpsError("invalid-argument", result.message);
  return { ok: true };
});

/** Admin: driver handed COD cash to the office. */
exports.settleDriverCash = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in again.");
  const me = await db.doc(`users/${uid}`).get();
  if (!me.exists || me.get("role") !== "admin") throw new HttpsError("permission-denied", "Admins only.");
  const orderIds = Array.isArray(request.data && request.data.orderIds) ? request.data.orderIds.map(String) : [];
  if (!orderIds.length) throw new HttpsError("invalid-argument", "No orders selected.");

  let total = 0;
  await db.runTransaction(async (t) => {
    const snaps = await Promise.all(orderIds.map((id) => t.get(db.doc(`orders/${id}`))));
    for (const s of snaps) {
      if (!s.exists) continue;
      const o = { id: s.id, ...s.data() };
      if (!o.codCollected || o.codSettled) continue;
      const cod = Number(o.codAmount || 0);
      total += cod;
      t.update(s.ref, { codSettled: true, codSettledAt: FieldValue.serverTimestamp() });
      t.set(db.doc(`cod_transactions/${s.id}`), { status: "settled", settledAt: FieldValue.serverTimestamp() }, { merge: true });
      tx(t, o.driverId, "cod_settled", cod, o);
    }
  });
  return { ok: true, total: round2(total) };
});
