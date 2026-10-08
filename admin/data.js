// MSI Parcel Admin — data layer.
// DemoStore keeps realistic sample data in this browser.
// FirebaseStore talks to the live Firestore database (same schema as the apps).

import { firebaseConfig } from "./config.js";

export const STATUS = {
  pending: "New",
  assigned: "Assigned",
  accepted: "Accepted",
  picked_up: "Picked up",
  out_for_delivery: "Out for delivery",
  delivered: "Delivered",
  cancelled: "Cancelled",
};
export const ACTIVE = ["pending", "assigned", "accepted", "picked_up", "out_for_delivery"];

const round2 = (n) => Math.round(n * 100) / 100;
const round6 = (n) => Math.round(n * 1e6) / 1e6;

export function quote(pricing, zone, kg, cod) {
  const base = zone ? Number(zone.baseFee || 0) : 20;
  const extra = Math.max(0, Number(kg || 0) - pricing.freeKg) * pricing.perKgFee;
  return round2(base + extra + (Number(cod || 0) * pricing.codFeePct) / 100);
}

export async function createStore() {
  if (firebaseConfig) {
    const s = new FirebaseStore();
    await s.init();
    return s;
  }
  const s = new DemoStore();
  s.init();
  return s;
}

// ===================================================================== DEMO
const DEMO_KEY = "msi-parcel-admin-demo-v2";

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function docPlaceholder(label, hue) {
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' width='320' height='200'><rect width='320' height='200' rx='14' fill='hsl(${hue},45%,92%)'/><rect x='20' y='24' width='90' height='110' rx='8' fill='hsl(${hue},35%,78%)'/><rect x='128' y='34' width='160' height='12' rx='6' fill='hsl(${hue},30%,70%)'/><rect x='128' y='60' width='120' height='10' rx='5' fill='hsl(${hue},30%,78%)'/><rect x='128' y='82' width='140' height='10' rx='5' fill='hsl(${hue},30%,78%)'/><text x='20' y='176' font-family='sans-serif' font-size='16' font-weight='700' fill='hsl(${hue},40%,35%)'>${label} (sample)</text></svg>`;
  return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}

function seedDemo() {
  const r = rng(2026);
  const pick = (a) => a[Math.floor(r() * a.length)];
  const now = Date.now();
  const DAY = 86400000;
  const areas = {
    Jeddah: ["Al Rawdah", "Al Safa", "Al Hamra", "Al Salamah", "Al Naeem", "Obhur", "Al Zahra", "Al Marwah", "Al Andalus", "Al Faisaliyah"],
    Makkah: ["Al Aziziyah", "Al Awali", "Al Shawqiyah", "Al Naseem", "Al Zahir"],
    Riyadh: ["Al Olaya", "Al Malqa", "Al Nakheel", "Al Yasmin", "Al Sahafa"],
  };
  const zones = [
    { name: "Jeddah", baseFee: 20, active: true },
    { name: "Makkah", baseFee: 22, active: true },
    { name: "Riyadh", baseFee: 25, active: false },
  ];
  const pricing = { freeKg: 5, perKgFee: 2, codFeePct: 1, driverSharePct: 80 };
  const first = ["Ahmed", "Mohammed", "Abdullah", "Faisal", "Omar", "Khalid", "Yusuf", "Rashid", "Saeed", "Tariq", "Hassan", "Ali"];
  const last = ["Al-Harbi", "Al-Qahtani", "Al-Ghamdi", "Al-Zahrani", "Hossain", "Rahman", "Khan", "Al-Otaibi", "Siddique", "Al-Shehri"];
  const vehicles = ["Motorbike", "Motorbike", "Car", "Van"];

  const drivers = [];
  for (let i = 0; i < 10; i++) {
    const status = i < 7 ? "approved" : i === 7 ? "suspended" : "pending";
    const city = i < 6 ? "Jeddah" : i < 8 ? "Makkah" : pick(["Jeddah", "Makkah"]);
    drivers.push({
      id: "drv" + (i + 1),
      name: `${first[i]} ${pick(last)}`,
      phone: "+9665" + String(40000000 + Math.floor(r() * 59999999)),
      city,
      vehicleType: pick(vehicles),
      plateNumber: `${pick(["ABC", "KRT", "JDH", "MKA", "SRH"])} ${1000 + Math.floor(r() * 8999)}`,
      idNumber: String(2400000000 + Math.floor(r() * 99999999)),
      status,
      online: status === "approved" && r() > 0.35,
      rating: round2(4.4 + r() * 0.6),
      location: { lat: 21.5 + r() * 0.15, lng: 39.12 + r() * 0.12 },
      submittedAt: now - (i < 8 ? 40 : 1) * DAY - Math.floor(r() * DAY),
      documents: { license: docPlaceholder("Driving license", 270), vehicle: docPlaceholder("Vehicle", 180), selfie: docPlaceholder("Driver photo", 30) },
    });
  }

  const shops = ["Noor Abayas", "Jeddah Sweets", "Al Safa Electronics", "Bloom Flowers", "Taiba Perfumes", "Hijazi Kitchen", "Smart Gadgets KSA", "Coral Cosmetics"];
  const customers = [];
  for (let i = 0; i < 34; i++) {
    const isShop = i < shops.length;
    customers.push({
      id: "cus" + (i + 1),
      name: isShop ? shops[i] : `${pick(first)} ${pick(last)}`,
      phone: "+9665" + String(50000000 + Math.floor(r() * 49999999)),
      createdAt: now - Math.floor(r() * 60) * DAY,
      business: isShop,
    });
  }

  const orders = [];
  const txs = [];
  let n = 100120;
  const approved = drivers.filter((d) => d.status === "approved");
  for (let d = 44; d >= 0; d--) {
    const weekday = new Date(now - d * DAY).getDay();
    const base = 9 + Math.round((44 - d) * 0.35) + (weekday === 4 || weekday === 5 ? 6 : 0);
    const count = Math.max(3, Math.round(base * (0.75 + r() * 0.5)));
    for (let k = 0; k < count; k++) {
      n++;
      const cust = r() < 0.65 ? customers[Math.floor(r() * shops.length)] : pick(customers);
      const city = r() < 0.8 ? "Jeddah" : "Makkah";
      const zone = zones.find((z) => z.name === city);
      const kg = round2(0.5 + r() * (r() < 0.85 ? 4 : 14));
      const cod = r() < 0.62 ? 40 + Math.floor(r() * 50) * 5 : 0;
      const fee = quote(pricing, zone, kg, cod);
      const created = now - d * DAY - Math.floor(r() * 10 * 3600000) - (d === 0 ? 0 : 2 * 3600000);
      let status = "delivered";
      if (d === 0) status = pick(["pending", "pending", "assigned", "accepted", "picked_up", "out_for_delivery", "delivered", "delivered"]);
      else if (d === 1 && r() < 0.1) status = "out_for_delivery";
      else if (r() < 0.05) status = "cancelled";
      const drv = status === "pending" || status === "cancelled" ? null : pick(approved.filter((x) => x.city === city).length ? approved.filter((x) => x.city === city) : approved);
      const delivered = status === "delivered";
      const deliveredAt = delivered ? Math.min(now - 60000, created + (50 + Math.floor(r() * 140)) * 60000) : null;
      const earning = delivered ? round2((fee * pricing.driverSharePct) / 100) : 0;
      const o = {
        id: "o" + n,
        code: "MSI-" + n,
        status,
        customerId: cust.id,
        senderName: cust.name,
        senderPhone: cust.phone,
        city,
        pickupAddress: `${pick(areas[city])}, ${city}`,
        dropoffAddress: `${pick(areas[city])}, ${city}`,
        receiverName: `${pick(first)} ${pick(last)}`,
        receiverPhone: "+9665" + String(50000000 + Math.floor(r() * 49999999)),
        parcelType: pick(["Documents", "Small box", "Small box", "Medium box", "Large box", "Food", "Electronics"]),
        weightKg: kg,
        codAmount: cod,
        deliveryFee: fee,
        driverEarning: earning,
        driverId: drv ? drv.id : "",
        driverName: drv ? drv.name : "",
        driverPhone: drv ? drv.phone : "",
        codCollected: delivered && cod > 0,
        codSettled: delivered && cod > 0 && d > 1,
        otp: String(1000 + Math.floor(r() * 9000)),
        createdAt: created,
        deliveredAt,
        notes: r() < 0.2 ? pick(["Call before arrival", "Fragile", "Leave with security", "Gate code 2244"]) : "",
        pickupLat: round6(21.49 + r() * 0.12), pickupLng: round6(39.13 + r() * 0.1),
        ...(r() < 0.7 ? { dropoffLat: round6(21.49 + r() * 0.12), dropoffLng: round6(39.13 + r() * 0.1) } : {}),
      };
      orders.push(o);
      if (delivered) {
        txs.push({ id: "t" + n + "e", uid: drv.id, type: "earning", amount: earning, orderCode: o.code, createdAt: deliveredAt });
        if (cod > 0) {
          txs.push({ id: "t" + n + "c", uid: drv.id, type: "cod_collected", amount: -cod, orderCode: o.code, createdAt: deliveredAt });
          txs.push({ id: "t" + n + "r", uid: cust.id, type: "cod_received", amount: cod, orderCode: o.code, createdAt: deliveredAt });
          if (o.codSettled) txs.push({ id: "t" + n + "s", uid: drv.id, type: "cod_settled", amount: cod, orderCode: o.code, createdAt: deliveredAt + DAY });
        }
        txs.push({ id: "t" + n + "f", uid: cust.id, type: "delivery_fee", amount: -fee, orderCode: o.code, createdAt: deliveredAt });
      }
    }
  }
  const withdrawals = [
    { id: "w1", uid: customers[0].id, amount: 1250, status: "pending", createdAt: now - 5 * 3600000 },
    { id: "w2", uid: customers[2].id, amount: 640, status: "pending", createdAt: now - 26 * 3600000 },
    { id: "w3", uid: customers[1].id, amount: 980, status: "paid", createdAt: now - 4 * DAY },
  ];
  return { orders, drivers, customers, zones, pricing, txs, withdrawals, seq: n };
}

class DemoStore {
  constructor() {
    this.mode = "demo";
    this.listeners = new Set();
    this.user = null;
  }
  init() {
    try {
      const raw = localStorage.getItem(DEMO_KEY);
      this.db = raw ? JSON.parse(raw) : seedDemo();
    } catch (e) {
      this.db = seedDemo();
    }
    try {
      this.user = JSON.parse(sessionStorage.getItem(DEMO_KEY + "-user") || "null");
    } catch (e) {
      this.user = null;
    }
    // A new customer order arrives now and then, so the board feels alive.
    this.timer = setInterval(() => this._incoming(), 45000);
  }
  _save() {
    try {
      localStorage.setItem(DEMO_KEY, JSON.stringify(this.db));
    } catch (e) {}
    this._emit();
  }
  _emit() {
    for (const f of this.listeners) f(this.state());
  }
  state() {
    return { ...this.db, mode: this.mode };
  }
  subscribe(f) {
    this.listeners.add(f);
    f(this.state());
    return () => this.listeners.delete(f);
  }
  async signIn(email, password) {
    if (!email || !password) throw new Error("Enter email and password.");
    this.user = { email, name: "Admin" };
    try {
      sessionStorage.setItem(DEMO_KEY + "-user", JSON.stringify(this.user));
    } catch (e) {}
    this._emit();
  }
  async signOut() {
    this.user = null;
    try {
      sessionStorage.removeItem(DEMO_KEY + "-user");
    } catch (e) {}
    this._emit();
  }
  currentUser() {
    return this.user;
  }
  reset() {
    this.db = seedDemo();
    this._save();
  }
  _incoming() {
    if (!this.user) return;
    const r = Math.random;
    const c = this.db.customers[Math.floor(r() * 8)];
    const zone = this.db.zones[0];
    const cod = r() < 0.6 ? 50 + Math.floor(r() * 30) * 5 : 0;
    const kg = round2(0.5 + r() * 4);
    this.db.seq++;
    const o = {
      id: "o" + this.db.seq, code: "MSI-" + this.db.seq, status: "pending", customerId: c.id,
      senderName: c.name, senderPhone: c.phone, city: zone.name,
      pickupAddress: "Al Rawdah, Jeddah", dropoffAddress: "Al Salamah, Jeddah",
      receiverName: "New receiver", receiverPhone: "+966500001234", parcelType: "Small box",
      weightKg: kg, codAmount: cod, deliveryFee: quote(this.db.pricing, zone, kg, cod), driverEarning: 0,
      driverId: "", driverName: "", driverPhone: "", codCollected: false, codSettled: false,
      otp: String(1000 + Math.floor(r() * 9000)), createdAt: Date.now(), deliveredAt: null, notes: "",
    };
    this.db.orders.push(o);
    this._save();
    if (this.onNewOrder) this.onNewOrder(o);
  }
  _order(id) {
    const o = this.db.orders.find((x) => x.id === id);
    if (!o) throw new Error("Order not found.");
    return o;
  }
  async assignDriver(orderId, driverId) {
    const o = this._order(orderId);
    const d = this.db.drivers.find((x) => x.id === driverId);
    if (!d) throw new Error("Driver not found.");
    Object.assign(o, { driverId: d.id, driverName: d.name, driverPhone: d.phone, status: "assigned" });
    this._save();
  }
  async cancelOrder(orderId) {
    const o = this._order(orderId);
    if (!ACTIVE.includes(o.status)) throw new Error("Only active orders can be cancelled.");
    o.status = "cancelled";
    this._save();
  }
  async markDelivered(orderId) {
    const o = this._order(orderId);
    const now = Date.now();
    const p = this.db.pricing;
    o.status = "delivered";
    o.deliveredAt = now;
    o.driverEarning = round2((o.deliveryFee * p.driverSharePct) / 100);
    o.codCollected = o.codAmount > 0;
    if (o.driverId) this.db.txs.push({ id: "t" + now, uid: o.driverId, type: "earning", amount: o.driverEarning, orderCode: o.code, createdAt: now });
    if (o.codAmount > 0 && o.driverId) this.db.txs.push({ id: "t" + now + "c", uid: o.driverId, type: "cod_collected", amount: -o.codAmount, orderCode: o.code, createdAt: now });
    this._save();
  }
  async getOtp(orderId) {
    return this._order(orderId).otp;
  }
  async createOrder(data) {
    const zone = this.db.zones.find((z) => z.name === data.city);
    this.db.seq++;
    const o = {
      id: "o" + this.db.seq, code: "MSI-" + this.db.seq, status: "pending", customerId: "",
      driverId: "", driverName: "", driverPhone: "", codCollected: false, codSettled: false, driverEarning: 0,
      otp: String(1000 + Math.floor(Math.random() * 9000)), createdAt: Date.now(), deliveredAt: null,
      ...data,
      deliveryFee: quote(this.db.pricing, zone, data.weightKg, data.codAmount),
    };
    this.db.orders.push(o);
    this._save();
    return o;
  }
  async setDriverStatus(id, status, reason) {
    const d = this.db.drivers.find((x) => x.id === id);
    if (!d) throw new Error("Driver not found.");
    d.status = status;
    d.rejectReason = reason || "";
    if (status !== "approved") d.online = false;
    this._save();
  }
  async settleCash(orderIds) {
    let total = 0;
    for (const id of orderIds) {
      const o = this._order(id);
      if (!o.codCollected || o.codSettled) continue;
      o.codSettled = true;
      total += o.codAmount;
      this.db.txs.push({ id: "t" + Date.now() + id, uid: o.driverId, type: "cod_settled", amount: o.codAmount, orderCode: o.code, createdAt: Date.now() });
    }
    this._save();
    return round2(total);
  }
  async decideWithdrawal(id, approve) {
    const w = this.db.withdrawals.find((x) => x.id === id);
    if (!w) throw new Error("Request not found.");
    w.status = approve ? "paid" : "rejected";
    if (approve) this.db.txs.push({ id: "t" + Date.now(), uid: w.uid, type: "withdrawal", amount: -w.amount, createdAt: Date.now() });
    this._save();
  }
  async saveZone(zone, originalName) {
    const i = this.db.zones.findIndex((z) => z.name === (originalName || zone.name));
    if (i >= 0) this.db.zones[i] = zone;
    else this.db.zones.push(zone);
    this._save();
  }
  async deleteZone(name) {
    this.db.zones = this.db.zones.filter((z) => z.name !== name);
    this._save();
  }
  async savePricing(p) {
    this.db.pricing = { ...this.db.pricing, ...p };
    this._save();
  }
}

// ===================================================================== FIREBASE
const SDK = "https://www.gstatic.com/firebasejs/10.12.2/";

function ms(v) {
  if (!v) return null;
  if (typeof v === "number") return v;
  if (v.toMillis) return v.toMillis();
  return null;
}

class FirebaseStore {
  constructor() {
    this.mode = "live";
    this.listeners = new Set();
    this.data = { orders: [], drivers: [], customers: [], zones: [], pricing: { freeKg: 5, perKgFee: 2, codFeePct: 1, driverSharePct: 80 }, txs: [], withdrawals: [] };
    this.user = null;
    this.unsubs = [];
  }
  async init() {
    const [{ initializeApp }, auth, fs, fn] = await Promise.all([
      import(SDK + "firebase-app.js"),
      import(SDK + "firebase-auth.js"),
      import(SDK + "firebase-firestore.js"),
      import(SDK + "firebase-functions.js"),
    ]);
    this.A = auth;
    this.F = fs;
    this.Fn = fn;
    this.app = initializeApp(firebaseConfig);
    this.auth = auth.getAuth(this.app);
    this.db = fs.getFirestore(this.app);
    this.functions = fn.getFunctions(this.app, "us-central1");
    await new Promise((resolve) => {
      let first = true;
      auth.onAuthStateChanged(this.auth, async (u) => {
        this.user = null;
        this._stop();
        if (u) {
          const me = await fs.getDoc(fs.doc(this.db, "users", u.uid));
          if (me.exists() && me.data().role === "admin") {
            this.user = { email: u.email, name: me.data().name || "Admin", uid: u.uid };
            this._start();
          } else {
            this.denied = true;
            await auth.signOut(this.auth);
          }
        }
        this._emit();
        if (first) {
          first = false;
          resolve();
        }
      });
    });
  }
  _stop() {
    this.unsubs.forEach((u) => u());
    this.unsubs = [];
  }
  _start() {
    const F = this.F;
    const db = this.db;
    const watch = (q, key, map) =>
      this.unsubs.push(
        F.onSnapshot(q, (s) => {
          this.data[key] = s.docs.map((d) => map(d.id, d.data()));
          this._emit();
        }, (e) => console.error(key, e))
      );
    watch(F.query(F.collection(db, "orders"), F.orderBy("createdAt", "desc"), F.limit(2000)), "orders", (id, m) => ({
      ...m, id, createdAt: ms(m.createdAt), deliveredAt: ms(m.deliveredAt),
    }));
    watch(F.collection(db, "drivers"), "drivers", (id, m) => ({
      ...m, id, submittedAt: ms(m.submittedAt),
      location: m.location ? { lat: m.location.latitude, lng: m.location.longitude } : null,
    }));
    watch(F.query(F.collection(db, "users"), F.where("role", "==", "customer")), "customers", (id, m) => ({ ...m, id, createdAt: ms(m.updatedAt) }));
    watch(F.collection(db, "service_zones"), "zones", (id, m) => ({ ...m, id, name: m.name || id }));
    watch(F.query(F.collection(db, "withdrawal_requests"), F.orderBy("createdAt", "desc"), F.limit(300)), "withdrawals", (id, m) => ({ ...m, id, createdAt: ms(m.createdAt) }));
    watch(F.query(F.collection(db, "wallet_transactions"), F.orderBy("createdAt", "desc"), F.limit(3000)), "txs", (id, m) => ({ ...m, id, createdAt: ms(m.createdAt) }));
    this.unsubs.push(F.onSnapshot(F.doc(db, "pricing_rules", "default"), (s) => {
      if (s.exists()) this.data.pricing = { ...this.data.pricing, ...s.data() };
      this._emit();
    }));
  }
  _emit() {
    for (const f of this.listeners) f(this.state());
  }
  state() {
    return { ...this.data, mode: this.mode };
  }
  subscribe(f) {
    this.listeners.add(f);
    f(this.state());
    return () => this.listeners.delete(f);
  }
  currentUser() {
    return this.user;
  }
  async signIn(email, password) {
    this.denied = false;
    await this.A.signInWithEmailAndPassword(this.auth, email, password);
    await new Promise((r) => setTimeout(r, 600));
    if (this.denied) throw new Error("This account is not an admin.");
  }
  async signOut() {
    await this.A.signOut(this.auth);
  }
  async assignDriver(orderId, driverId) {
    const d = this.data.drivers.find((x) => x.id === driverId);
    if (!d) throw new Error("Driver not found.");
    const F = this.F;
    await F.updateDoc(F.doc(this.db, "orders", orderId), {
      driverId: d.id, driverName: d.name || "", driverPhone: d.phone || "", status: "assigned", updatedAt: F.serverTimestamp(),
    });
    await F.addDoc(F.collection(this.db, "order_events"), {
      orderId, status: "assigned", actorId: this.user.uid, actorRole: "admin", createdAt: F.serverTimestamp(),
    });
  }
  async cancelOrder(orderId) {
    const F = this.F;
    await F.updateDoc(F.doc(this.db, "orders", orderId), { status: "cancelled", updatedAt: F.serverTimestamp() });
  }
  async markDelivered() {
    throw new Error("In live mode the driver completes delivery with the receiver's code.");
  }
  async getOtp(orderId) {
    const F = this.F;
    const s = await F.getDoc(F.doc(this.db, "orders", orderId, "private", "otp"));
    return s.exists() ? s.data().code : "—";
  }
  async createOrder(data) {
    const F = this.F;
    const ref = await F.addDoc(F.collection(this.db, "orders"), {
      ...data, code: "MSI-" + (100000 + Math.floor(Math.random() * 899999)), status: "pending", driverId: "",
      customerId: "", createdAt: F.serverTimestamp(),
    });
    return { id: ref.id };
  }
  async setDriverStatus(id, status, reason) {
    const F = this.F;
    const patch = { status, rejectReason: reason || "", reviewedAt: F.serverTimestamp() };
    if (status !== "approved") patch.online = false;
    await F.updateDoc(F.doc(this.db, "drivers", id), patch);
  }
  async settleCash(orderIds) {
    const call = this.Fn.httpsCallable(this.functions, "settleDriverCash");
    const r = await call({ orderIds });
    return r.data.total;
  }
  async decideWithdrawal(id, approve) {
    const F = this.F;
    const w = this.data.withdrawals.find((x) => x.id === id);
    await F.updateDoc(F.doc(this.db, "withdrawal_requests", id), { status: approve ? "paid" : "rejected", decidedAt: F.serverTimestamp() });
    if (approve && w) {
      await F.addDoc(F.collection(this.db, "wallet_transactions"), {
        uid: w.uid, type: "withdrawal", amount: -Number(w.amount), note: "Bank transfer", createdAt: F.serverTimestamp(),
      });
    }
  }
  async saveZone(zone, originalName) {
    const F = this.F;
    const id = (zone.name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-");
    if (originalName && originalName !== zone.name) {
      const old = this.data.zones.find((z) => z.name === originalName);
      if (old) await F.deleteDoc(F.doc(this.db, "service_zones", old.id));
    }
    await F.setDoc(F.doc(this.db, "service_zones", id), { name: zone.name, baseFee: Number(zone.baseFee), active: !!zone.active });
  }
  async deleteZone(name) {
    const F = this.F;
    const z = this.data.zones.find((x) => x.name === name);
    if (z) await F.deleteDoc(F.doc(this.db, "service_zones", z.id));
  }
  async savePricing(p) {
    const F = this.F;
    await F.setDoc(F.doc(this.db, "pricing_rules", "default"), p, { merge: true });
  }
}
