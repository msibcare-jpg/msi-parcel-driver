// MSI Parcel Admin — operations console (vanilla JS, no build step).
import { BRAND } from "./config.js";
import { createStore, STATUS, ACTIVE, quote } from "./data.js";

const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const DAY = 86400000;
const fmt0 = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
const fmt2 = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const money = (v) => `${BRAND.currency} ${fmt2.format(Number(v) || 0)}`;
const moneyShort = (v) => {
  const n = Number(v) || 0;
  return n >= 10000 ? `${BRAND.currency} ${fmt0.format(n / 1000)}k` : `${BRAND.currency} ${fmt0.format(n)}`;
};
const startOfDay = (t) => { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); };
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const dateShort = (t) => { const d = new Date(t); return `${d.getDate()} ${MONTHS[d.getMonth()]}`; };
const timeShort = (t) => {
  if (!t) return "";
  const d = new Date(t);
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  return startOfDay(t) === startOfDay(Date.now()) ? `Today ${hm}` : `${dateShort(t)}, ${hm}`;
};
const ago = (t) => {
  const m = Math.round((Date.now() - t) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m} min ago`;
  const h = Math.round(m / 60);
  return h < 24 ? `${h} h ago` : `${Math.round(h / 24)} d ago`;
};
const pct = (a, b) => (b ? Math.round(((a - b) / b) * 100) : a ? 100 : 0);
const sum = (arr, f) => arr.reduce((s, x) => s + (Number(f(x)) || 0), 0);

const ICON = {
  overview: "M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z",
  orders: "M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm-7 14H7v-2h5v2zm5-4H7v-2h10v2zm0-4H7V7h10v2z",
  dispatch: "M20 8h-3V4H3a2 2 0 0 0-2 2v11h2a3 3 0 0 0 6 0h6a3 3 0 0 0 6 0h2v-5l-3-4zM6 18.5A1.5 1.5 0 1 1 6 15.5a1.5 1.5 0 0 1 0 3zm13.5-9l1.96 2.5H17V9.5h2.5zm-1.5 9a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z",
  drivers: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z",
  customers: "M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm-8 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5C15 14.17 10.33 13 8 13zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z",
  finance: "M21 18v1a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v1h-9a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h9zm-9-2h10V8H12v8zm4-2.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z",
  reports: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zm-1 7V3.5L18.5 9H13zM8 17v-4h2v4H8zm3 0v-6h2v6h-2zm3 0v-3h2v3h-2z",
  settings: "M19.14 12.94a7.07 7.07 0 0 0 0-1.88l2.03-1.58a.5.5 0 0 0 .12-.64l-1.92-3.32a.5.5 0 0 0-.61-.22l-2.39.96a7 7 0 0 0-1.63-.94l-.36-2.54a.5.5 0 0 0-.5-.42h-3.84a.5.5 0 0 0-.49.42l-.36 2.54c-.59.24-1.13.56-1.63.94l-2.39-.96a.5.5 0 0 0-.61.22L2.71 8.84a.5.5 0 0 0 .12.64l2.03 1.58a7.07 7.07 0 0 0 0 1.88l-2.03 1.58a.5.5 0 0 0-.12.64l1.92 3.32c.13.22.39.3.61.22l2.39-.96c.5.38 1.04.7 1.63.94l.36 2.54c.05.24.25.42.49.42h3.84c.25 0 .45-.18.49-.42l.36-2.54c.59-.24 1.13-.56 1.63-.94l2.39.96c.22.08.48 0 .61-.22l1.92-3.32a.5.5 0 0 0-.12-.64l-2.03-1.58zM12 15.6a3.6 3.6 0 1 1 0-7.2 3.6 3.6 0 0 1 0 7.2z",
  money: "M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16c-1.94.42-3.5 1.68-3.5 3.61 0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1h-2.2c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z",
  box: "M21 16.5V7.5a1 1 0 0 0-.5-.87l-8-4.5a1 1 0 0 0-1 0l-8 4.5a1 1 0 0 0-.5.87v9a1 1 0 0 0 .5.87l8 4.5a1 1 0 0 0 1 0l8-4.5a1 1 0 0 0 .5-.87zM12 4.15L18.04 7.5 12 10.85 5.96 7.5 12 4.15z",
  plus: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",
  menu: "M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z",
  download: "M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z",
  search: "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z",
  logout: "M10.09 15.59L11.5 17l5-5-5-5-1.41 1.41L12.67 11H3v2h9.67l-2.58 2.59zM19 3H5a2 2 0 0 0-2 2v4h2V5h14v14H5v-4H3v4a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z",
  pin: "M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z",
};
const icon = (k) => `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="${ICON[k]}"/></svg>`;

const PAGES = [
  ["overview", "Overview"],
  ["orders", "Orders"],
  ["dispatch", "Dispatch"],
  ["drivers", "Drivers"],
  ["customers", "Customers"],
  ["finance", "Finance"],
  ["reports", "Reports"],
  ["settings", "Settings"],
];

let store;
let S = null; // latest data state
const UI = {
  page: "overview",
  orderTab: "active",
  orderQuery: "",
  orderCity: "",
  orderPeriod: "30",
  driverTab: "applications",
  customerQuery: "",
  selOrder: null,
  dispatchOrder: null,
  drawer: null,
  modal: null,
  reportPeriod: "30",
};

// ===================================================================== boot
(async function boot() {
  try {
    store = await createStore();
  } catch (e) {
    document.getElementById("app").innerHTML = `<div class="empty">Could not start: ${esc(e.message)}</div>`;
    return;
  }
  store.onNewOrder = (o) => toast(`New order ${o.code} from ${o.senderName}`);
  readHash();
  window.addEventListener("hashchange", () => { readHash(); render(); });
  store.subscribe((state) => { S = state; render(); });
})();

function readHash() {
  const h = (location.hash || "#overview").slice(1);
  UI.page = PAGES.some(([k]) => k === h) ? h : "overview";
}

// ===================================================================== derived data
function derive() {
  const now = Date.now();
  const today = startOfDay(now);
  const orders = S.orders || [];
  const drivers = S.drivers || [];
  const delivered = orders.filter((o) => o.status === "delivered");
  const companyRev = (o) => (Number(o.deliveryFee) || 0) - (Number(o.driverEarning) || 0);
  const inDay = (t, d) => t >= today - d * DAY && t < today - (d - 1) * DAY;
  const todays = orders.filter((o) => o.createdAt >= today);
  const yesterdays = orders.filter((o) => inDay(o.createdAt, 1));
  const revToday = sum(delivered.filter((o) => o.deliveredAt >= today), companyRev);
  const revYesterday = sum(delivered.filter((o) => inDay(o.deliveredAt, 1)), companyRev);
  const codWithDrivers = sum(delivered.filter((o) => o.codCollected && !o.codSettled), (o) => o.codAmount);
  const active = orders.filter((o) => ACTIVE.includes(o.status));
  const unassigned = orders.filter((o) => o.status === "pending");
  const approved = drivers.filter((d) => d.status === "approved");
  const online = approved.filter((d) => d.online);
  const pendingDrivers = drivers.filter((d) => d.status === "pending");
  const pendingWithdrawals = (S.withdrawals || []).filter((w) => w.status === "pending");
  return { now, today, orders, drivers, delivered, companyRev, todays, yesterdays, revToday, revYesterday, codWithDrivers, active, unassigned, approved, online, pendingDrivers, pendingWithdrawals };
}

function series(items, timeOf, valueOf, days) {
  const today = startOfDay(Date.now());
  const out = new Array(days).fill(0);
  for (const it of items) {
    const t = timeOf(it);
    if (!t) continue;
    const diff = Math.floor((today - startOfDay(t)) / DAY);
    if (diff >= 0 && diff < days) out[days - 1 - diff] += Number(valueOf(it)) || 0;
  }
  return out;
}
const dayLabels = (days) => Array.from({ length: days }, (_, i) => dateShort(startOfDay(Date.now()) - (days - 1 - i) * DAY));

// ===================================================================== charts (SVG)
function barLineChart(bars, line, labels, { barName, lineName, fmtBar = fmt0.format, fmtLine = moneyShort } = {}) {
  const W = 760, H = 250, L = 38, R = 52, T = 14, B = 30;
  const iw = W - L - R, ih = H - T - B;
  const n = bars.length;
  const maxB = Math.max(1, ...bars) * 1.12;
  const maxL = Math.max(1, ...line) * 1.12;
  const bw = (iw / n) * 0.62;
  const x = (i) => L + (iw / n) * (i + 0.5);
  const yB = (v) => T + ih - (v / maxB) * ih;
  const yL = (v) => T + ih - (v / maxL) * ih;
  let g = "";
  for (let k = 0; k <= 4; k++) {
    const y = T + (ih / 4) * k;
    g += `<line x1="${L}" x2="${W - R}" y1="${y}" y2="${y}" stroke="#ece8f3"/>`;
    g += `<text x="${L - 8}" y="${y + 4}" text-anchor="end">${fmtBar((maxB / 4) * (4 - k))}</text>`;
    g += `<text x="${W - R + 8}" y="${y + 4}">${fmtLine((maxL / 4) * (4 - k))}</text>`;
  }
  let b = "";
  bars.forEach((v, i) => {
    const y = yB(v);
    const last = i === n - 1;
    b += `<rect x="${x(i) - bw / 2}" y="${y}" width="${bw}" height="${T + ih - y}" rx="4" fill="${last ? "url(#gP)" : "url(#gT)"}"><title>${labels[i]}: ${fmtBar(v)} ${barName || ""}</title></rect>`;
  });
  const pts = line.map((v, i) => `${x(i)},${yL(v)}`).join(" ");
  const area = `M${x(0)},${T + ih} L${pts.split(" ").join(" L")} L${x(n - 1)},${T + ih} Z`;
  let lbl = "";
  const step = Math.ceil(n / 8);
  labels.forEach((t, i) => {
    if ((n - 1 - i) % step === 0) lbl += `<text x="${x(i)}" y="${H - 8}" text-anchor="middle">${t}</text>`;
  });
  const lastPt = `<circle cx="${x(n - 1)}" cy="${yL(line[n - 1])}" r="5" fill="#4e1a86" stroke="#fff" stroke-width="2"/>`;
  return `<div class="chart"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(barName)} and ${esc(lineName)}">
    <defs>
      <linearGradient id="gT" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2fd3c8"/><stop offset="1" stop-color="#0e9c9c"/></linearGradient>
      <linearGradient id="gP" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a2ba8"/><stop offset="1" stop-color="#2e0b57"/></linearGradient>
      <linearGradient id="gA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4e1a86" stop-opacity=".18"/><stop offset="1" stop-color="#4e1a86" stop-opacity="0"/></linearGradient>
    </defs>
    ${g}${b}<path d="${area}" fill="url(#gA)"/><polyline points="${pts}" fill="none" stroke="#4e1a86" stroke-width="2.5" stroke-linejoin="round"/>${lastPt}${lbl}
  </svg></div>
  <div class="legend mt"><span><i style="background:#0e9c9c"></i>${esc(barName)}</span><span><i style="background:#4e1a86"></i>${esc(lineName)}</span></div>`;
}

function donut(parts, centerLabel, centerValue) {
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  const R = 70, C = 2 * Math.PI * R;
  let off = 0;
  let arcs = "";
  for (const p of parts) {
    const len = (p.value / total) * C;
    if (len > 0) arcs += `<circle r="${R}" cx="90" cy="90" fill="none" stroke="${p.color}" stroke-width="22" stroke-dasharray="${len} ${C - len}" stroke-dashoffset="${-off}" transform="rotate(-90 90 90)"><title>${esc(p.label)}: ${p.value}</title></circle>`;
    off += len;
  }
  return `<div class="row" style="gap:20px;align-items:center;flex-wrap:nowrap">
    <div class="chart" style="width:160px;flex:none"><svg viewBox="0 0 180 180"><circle r="${R}" cx="90" cy="90" fill="none" stroke="#f0edf5" stroke-width="22"/>${arcs}
      <text x="90" y="86" text-anchor="middle" style="font:700 26px Sora,sans-serif;fill:#1d1530">${esc(centerValue)}</text>
      <text x="90" y="106" text-anchor="middle">${esc(centerLabel)}</text></svg></div>
    <div style="display:grid;gap:8px;min-width:0">${parts.map((p) => `<div class="row" style="gap:8px;flex-wrap:nowrap"><i style="width:10px;height:10px;border-radius:3px;background:${p.color};flex:none"></i><span class="muted small" style="flex:1">${esc(p.label)}</span><b class="num">${p.value}</b></div>`).join("")}</div>
  </div>`;
}

// ===================================================================== render
function render() {
  if (!S) return;
  const app = document.getElementById("app");
  const keepScroll = window.scrollY;
  const focusId = document.activeElement && document.activeElement.id;
  const caret = document.activeElement && "selectionStart" in document.activeElement ? document.activeElement.selectionStart : null;
  if (!store.currentUser()) {
    app.innerHTML = loginView();
    bindLogin();
    return;
  }
  // Keep what the admin is typing when live data re-renders the screen.
  const keep = {};
  const ctx = UI.page + "|" + (UI.modal ? UI.modal.type : "") + "|" + (UI.drawer ? UI.drawer.id : "");
  if (render.ctx === ctx) app.querySelectorAll(".modal [id], .drawer [id], #priceForm [id]").forEach((el) => {
    if ("value" in el) keep[el.id] = el.type === "checkbox" ? el.checked : el.value;
  });
  render.ctx = ctx;
  const d = derive();
  const counts = { orders: d.unassigned.length, drivers: d.pendingDrivers.length, finance: d.pendingWithdrawals.length };
  const title = PAGES.find(([k]) => k === UI.page)[1];
  const user = store.currentUser();
  app.innerHTML = `
  <div class="shell">
    <aside class="side" id="side">
      <div class="brand"><img src="icon.png" alt=""><div><b>${esc(BRAND.name)}</b><small>Operations console</small></div></div>
      <nav class="nav">${PAGES.map(([k, l]) => `<a href="#${k}" class="${UI.page === k ? "on" : ""}">${icon(k)}${l}${counts[k] ? `<span class="count">${counts[k]}</span>` : ""}</a>`).join("")}</nav>
      <div class="foot"><span class="mode ${S.mode}"><i></i>${S.mode === "demo" ? "Demo data" : "Live"}</span><div style="margin-top:8px">${esc(BRAND.tagline)}</div></div>
    </aside>
    <main class="main">
      <div class="top">
        <button class="btn line sm menu-btn" data-act="menu" aria-label="Menu">${icon("menu")}</button>
        <div><h1>${title}</h1><div class="sub">${new Date().toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" })}</div></div>
        <div class="grow"></div>
        ${UI.page === "orders" || UI.page === "overview" || UI.page === "dispatch" ? `<button class="btn" data-act="new-order">${icon("plus")}New order</button>` : ""}
        <div class="who"><div class="avatar">${esc((user.name || "A")[0])}</div><button class="btn line sm" data-act="logout" title="Sign out">${icon("logout")}</button></div>
      </div>
      ${S.mode === "demo" ? `<div class="card" style="padding:10px 14px;margin-bottom:16px;background:var(--warn-soft);border-color:#f5dfb8;box-shadow:none;color:var(--warn);font-weight:600">Demo mode — sample data saved in this browser. Connect Firebase in <code>admin/config.js</code> to go live.</div>` : ""}
      <div id="page">${pageView(d)}</div>
    </main>
  </div>
  ${UI.drawer ? `<div class="scrim" data-act="close"></div><aside class="drawer" role="dialog" aria-modal="true">${drawerView(d)}</aside>` : ""}
  ${UI.modal ? `<div class="scrim" data-act="close"></div><div class="modal" role="dialog" aria-modal="true">${modalView(d)}</div>` : ""}`;
  for (const [id, v] of Object.entries(keep)) {
    const el = document.getElementById(id);
    if (!el) continue;
    if (el.type === "checkbox") el.checked = v; else el.value = v;
  }
  bind();
  if (focusId) {
    const el = document.getElementById(focusId);
    if (el) { el.focus(); if (caret != null && el.setSelectionRange) try { el.setSelectionRange(caret, caret); } catch (e) {} }
  }
  window.scrollTo(0, keepScroll);
}

function pageView(d) {
  switch (UI.page) {
    case "orders": return ordersView(d);
    case "dispatch": return dispatchView(d);
    case "drivers": return driversView(d);
    case "customers": return customersView(d);
    case "finance": return financeView(d);
    case "reports": return reportsView(d);
    case "settings": return settingsView(d);
    default: return overviewView(d);
  }
}

// ===================================================================== login
function loginView() {
  return `<div class="login">
    <div class="art">
      <div class="ring" style="width:520px;height:520px;right:-180px;top:-160px"></div>
      <div class="ring" style="width:340px;height:340px;right:-60px;bottom:-120px"></div>
      <div style="font-weight:700;letter-spacing:.08em;font-size:12px;opacity:.75">MSI BUSINESS CARE</div>
      <div><h2>Every parcel, every rider, one screen.</h2><p>Dispatch orders, approve drivers, settle cash on delivery and watch revenue grow — across every city you serve.</p></div>
      <div style="opacity:.7;font-size:13px">${esc(BRAND.tagline)}</div>
    </div>
    <div class="panel">
      <form id="loginForm">
        <img class="logo" src="logo.png" alt="MSI Parcel">
        <div><h1 style="font:700 24px Sora,sans-serif;margin:0">Admin sign in</h1>
        <p class="muted" style="margin:4px 0 0">${S.mode === "demo" ? "Demo mode: any email and password work." : "Use your admin account."}</p></div>
        <label class="f">Email<input class="input" id="lg-email" type="email" autocomplete="username" required value="${S.mode === "demo" ? "admin@msiparcel.com" : ""}"></label>
        <label class="f">Password<input class="input" id="lg-pass" type="password" autocomplete="current-password" required value="${S.mode === "demo" ? "demo1234" : ""}"></label>
        <button class="btn" type="submit" style="justify-content:center;padding:12px">Sign in</button>
        <div id="lg-err" class="small" style="color:var(--bad)"></div>
      </form>
    </div>
  </div>`;
}
function bindLogin() {
  $("#loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      await store.signIn($("#lg-email").value.trim(), $("#lg-pass").value);
    } catch (err) {
      $("#lg-err").textContent = friendly(err);
    }
  });
}
function friendly(e) {
  const m = String((e && (e.code || e.message)) || e);
  if (m.includes("invalid-credential") || m.includes("wrong-password") || m.includes("user-not-found")) return "Wrong email or password.";
  if (m.includes("too-many-requests")) return "Too many attempts. Try again later.";
  return (e && e.message) || m;
}

// ===================================================================== overview
function overviewView(d) {
  const days = 30;
  const ordersSeries = series(d.orders.filter((o) => o.status !== "cancelled"), (o) => o.createdAt, () => 1, days);
  const revSeries = series(d.delivered, (o) => o.deliveredAt, d.companyRev, days);
  const gross30 = sum(d.delivered.filter((o) => o.deliveredAt >= d.today - 29 * DAY), (o) => o.deliveryFee);
  const rev30 = sum(d.delivered.filter((o) => o.deliveredAt >= d.today - 29 * DAY), d.companyRev);
  const statusParts = [
    { label: "New (needs driver)", value: d.todays.filter((o) => o.status === "pending").length, color: "#b86a00" },
    { label: "Assigned / accepted", value: d.todays.filter((o) => ["assigned", "accepted"].includes(o.status)).length, color: "#6a2ba8" },
    { label: "On the road", value: d.todays.filter((o) => ["picked_up", "out_for_delivery"].includes(o.status)).length, color: "#0e9c9c" },
    { label: "Delivered", value: d.todays.filter((o) => o.status === "delivered").length, color: "#16794a" },
    { label: "Cancelled", value: d.todays.filter((o) => o.status === "cancelled").length, color: "#d0c9dc" },
  ];
  const since = d.today - 29 * DAY;
  const recent = d.delivered.filter((o) => o.deliveredAt >= since);
  const byCity = {};
  recent.forEach((o) => (byCity[o.city] = (byCity[o.city] || 0) + 1));
  const cities = Object.entries(byCity).sort((a, b) => b[1] - a[1]);
  const maxCity = Math.max(1, ...cities.map((c) => c[1]));
  const topDrivers = d.approved
    .map((dr) => { const mine = recent.filter((o) => o.driverId === dr.id); return { dr, n: mine.length, earn: sum(mine, (o) => o.driverEarning) }; })
    .sort((a, b) => b.n - a.n).slice(0, 5);
  const custMap = {};
  recent.forEach((o) => { const k = o.senderName || "—"; custMap[k] = custMap[k] || { n: 0, cod: 0 }; custMap[k].n++; custMap[k].cod += Number(o.codAmount) || 0; });
  const topCust = Object.entries(custMap).sort((a, b) => b[1].n - a[1].n).slice(0, 5);
  const waiting = d.unassigned.slice().sort((a, b) => a.createdAt - b.createdAt);
  const avgMin = (() => {
    const t = recent.filter((o) => o.deliveredAt && o.createdAt).map((o) => (o.deliveredAt - o.createdAt) / 60000);
    return t.length ? Math.round(t.reduce((s, x) => s + x, 0) / t.length) : 0;
  })();
  const ordDelta = pct(d.todays.length, d.yesterdays.length);
  const revDelta = pct(d.revToday, d.revYesterday);
  return `
  <div class="grid g4">
    ${kpi("Orders today", fmt0.format(d.todays.length), `${ordDelta >= 0 ? "▲" : "▼"} ${Math.abs(ordDelta)}% vs yesterday`, ordDelta >= 0, "orders", true)}
    ${kpi("Revenue today", money(d.revToday), `${revDelta >= 0 ? "▲" : "▼"} ${Math.abs(revDelta)}% · company share`, revDelta >= 0, "money")}
    ${kpi("Drivers online", `${d.online.length} / ${d.approved.length}`, `${d.active.length} deliveries in progress`, true, "drivers", false, "var(--teal-soft)", "var(--teal)")}
    ${kpi("COD with drivers", money(d.codWithDrivers), "Cash to collect from riders", null, "finance", false, "var(--warn-soft)", "var(--warn)")}
  </div>
  <div class="grid g21 mt">
    <div class="card">
      <div class="row between"><div><h3>Orders &amp; revenue</h3><p class="hint">Last 30 days · revenue is the company share after driver earnings</p></div>
      <div class="row" style="gap:18px"><div><div class="muted small">Gross fees</div><b class="num">${money(gross30)}</b></div><div><div class="muted small">Company revenue</div><b class="num" style="color:var(--purple)">${money(rev30)}</b></div></div></div>
      ${barLineChart(ordersSeries, revSeries, dayLabels(days), { barName: "Orders", lineName: "Revenue (SAR)" })}
    </div>
    <div class="card">
      <h3>Today's pipeline</h3><p class="hint">Every order created today, by stage</p>
      ${donut(statusParts, "orders today", String(d.todays.length))}
      <div class="row between mt" style="border-top:1px solid var(--line);padding-top:12px">
        <span class="muted small">Avg. delivery time (30d)</span><b class="num">${avgMin} min</b>
      </div>
    </div>
  </div>
  <div class="grid g3 mt">
    <div class="card">
      <div class="row between"><h3>Needs attention</h3><a href="#dispatch" class="small">Open dispatch →</a></div>
      <p class="hint">Orders waiting for a driver, oldest first</p>
      ${waiting.length ? waiting.slice(0, 6).map((o) => `<div class="list-item click" data-order="${o.id}" style="cursor:pointer">
        <span class="pill pending">${esc(ago(o.createdAt))}</span>
        <div style="min-width:0;flex:1"><div class="code">${esc(o.code)}</div><div class="small muted route">${esc(o.pickupAddress)} → ${esc(o.dropoffAddress)}</div></div>
        <b class="num small">${money(o.deliveryFee)}</b></div>`).join("") : `<div class="empty">All orders have a driver. 🎉</div>`}
      ${d.pendingDrivers.length ? `<a href="#drivers" class="btn ghost sm mt">${d.pendingDrivers.length} driver application${d.pendingDrivers.length > 1 ? "s" : ""} to review</a>` : ""}
      ${d.pendingWithdrawals.length ? `<a href="#finance" class="btn ghost sm mt">${d.pendingWithdrawals.length} withdrawal request${d.pendingWithdrawals.length > 1 ? "s" : ""}</a>` : ""}
    </div>
    <div class="card">
      <h3>Top drivers</h3><p class="hint">Deliveries in the last 30 days</p>
      ${topDrivers.map((t, i) => `<div class="list-item"><span class="rank">${i + 1}</span><div style="flex:1;min-width:0"><b>${esc(t.dr.name)}</b><div class="small muted">${esc(t.dr.city)} · ${esc(t.dr.vehicleType || "")}</div></div><div style="text-align:right"><b class="num">${t.n}</b><div class="small muted num">${money(t.earn)}</div></div></div>`).join("") || `<div class="empty">No deliveries yet.</div>`}
    </div>
    <div class="card">
      <h3>Top senders</h3><p class="hint">Customers by delivered parcels, 30 days</p>
      ${topCust.map(([name, v], i) => `<div class="list-item"><span class="rank">${i + 1}</span><div style="flex:1;min-width:0"><b>${esc(name)}</b><div class="small muted num">COD ${money(v.cod)}</div></div><b class="num">${v.n}</b></div>`).join("") || `<div class="empty">No customers yet.</div>`}
      <h3 class="mt">By city</h3>
      ${cities.map(([c, n]) => `<div style="margin:10px 0"><div class="row between small"><span>${esc(c)}</span><b class="num">${n}</b></div><div class="bar-track"><div class="bar-fill" style="width:${(n / maxCity) * 100}%"></div></div></div>`).join("") || `<div class="muted small">No data.</div>`}
    </div>
  </div>`;
}

function kpi(label, value, delta, up, ic, hero = false, bg = "var(--purple-soft)", fg = "var(--purple)") {
  return `<div class="card kpi ${hero ? "hero" : ""}">
    <div class="ico" style="${hero ? "" : `background:${bg};color:${fg}`}">${icon(ic)}</div>
    <div class="label">${esc(label)}</div>
    <div class="value">${value}</div>
    <div class="delta ${hero || up === null ? "" : up ? "up" : "down"}">${esc(delta)}</div>
  </div>`;
}

// ===================================================================== orders
const ORDER_TABS = [
  ["active", "In progress", (o) => ACTIVE.includes(o.status) && o.status !== "pending"],
  ["pending", "New", (o) => o.status === "pending"],
  ["delivered", "Delivered", (o) => o.status === "delivered"],
  ["cancelled", "Cancelled", (o) => o.status === "cancelled"],
  ["all", "All", () => true],
];
function filteredOrders(d) {
  const tab = ORDER_TABS.find((t) => t[0] === UI.orderTab) || ORDER_TABS[0];
  const q = UI.orderQuery.trim().toLowerCase();
  const since = UI.orderPeriod === "all" ? 0 : d.today - (Number(UI.orderPeriod) - 1) * DAY;
  return d.orders
    .filter((o) => (o.createdAt || 0) >= since || ACTIVE.includes(o.status))
    .filter((o) => !UI.orderCity || o.city === UI.orderCity)
    .filter((o) => !q || [o.code, o.senderName, o.senderPhone, o.receiverName, o.receiverPhone, o.driverName, o.pickupAddress, o.dropoffAddress].join(" ").toLowerCase().includes(q))
    .sort((a, b) => b.createdAt - a.createdAt)
    .map((o) => ({ o, inTab: tab[2](o) }));
}
function ordersView(d) {
  const rows = filteredOrders(d);
  const counts = Object.fromEntries(ORDER_TABS.map(([k, , f]) => [k, rows.filter((r) => f(r.o)).length]));
  const list = rows.filter((r) => r.inTab).map((r) => r.o);
  const cities = (S.zones || []).map((z) => z.name);
  return `
  <div class="row between" style="margin-bottom:14px">
    <div class="tabs">${ORDER_TABS.map(([k, l]) => `<button data-otab="${k}" class="${UI.orderTab === k ? "on" : ""}">${l}<span class="c">${counts[k]}</span></button>`).join("")}</div>
    <div class="row">
      <input class="input" id="o-q" placeholder="Search code, name, phone…" value="${esc(UI.orderQuery)}" style="width:240px">
      <select class="input" id="o-city"><option value="">All cities</option>${cities.map((c) => `<option ${UI.orderCity === c ? "selected" : ""}>${esc(c)}</option>`).join("")}</select>
      <select class="input" id="o-period">${[["1", "Today"], ["7", "7 days"], ["30", "30 days"], ["all", "All time"]].map(([v, l]) => `<option value="${v}" ${UI.orderPeriod === v ? "selected" : ""}>${l}</option>`).join("")}</select>
    </div>
  </div>
  <div class="card">
    <div class="row between"><h3>${list.length} order${list.length === 1 ? "" : "s"}</h3><span class="muted small">Fees ${money(sum(list, (o) => o.deliveryFee))} · COD ${money(sum(list, (o) => o.codAmount))}</span></div>
    <div class="tbl-wrap mt"><table>
      <thead><tr><th>Order</th><th>Created</th><th>Sender</th><th>Route</th><th>Driver</th><th class="r">Fee</th><th class="r">COD</th><th>Status</th></tr></thead>
      <tbody>${list.slice(0, 300).map((o) => `<tr class="click" data-order="${o.id}">
        <td><span class="code">${esc(o.code)}</span></td>
        <td class="muted">${esc(timeShort(o.createdAt))}</td>
        <td>${esc(o.senderName || "—")}</td>
        <td class="route">${esc(o.pickupAddress)} → ${esc(o.dropoffAddress)}</td>
        <td>${o.driverName ? esc(o.driverName) : `<span class="muted">—</span>`}</td>
        <td class="r">${money(o.deliveryFee)}</td>
        <td class="r">${o.codAmount ? money(o.codAmount) : `<span class="muted">—</span>`}</td>
        <td><span class="pill ${o.status}">${STATUS[o.status] || o.status}</span></td>
      </tr>`).join("") || `<tr><td colspan="8" class="empty">No orders match these filters.</td></tr>`}</tbody>
    </table></div>
    ${list.length > 300 ? `<p class="muted small" style="padding:12px 0 0">Showing the newest 300. Use search or Reports to export all.</p>` : ""}
  </div>`;
}

// ===================================================================== order drawer
const mapLink = (lat, lng) =>
  lat != null && lng != null ? ` <a target="_blank" rel="noopener" href="https://www.google.com/maps/search/?api=1&query=${lat},${lng}">📍 pin</a>` : "";
const STEP = { pending: 0, assigned: 1, accepted: 2, picked_up: 3, out_for_delivery: 4, delivered: 5, cancelled: 0 };
function drawerView(d) {
  if (UI.drawer.type === "driver") return driverDrawer(d);
  const o = d.orders.find((x) => x.id === UI.drawer.id);
  if (!o) return `<div class="row"><b>Order not found</b><button class="x" data-act="close">×</button></div>`;
  const avail = d.approved.slice().sort((a, b) => (b.online - a.online) || (a.city === o.city ? -1 : 1));
  const load = (id) => d.active.filter((x) => x.driverId === id).length;
  const canAssign = ["pending", "assigned", "accepted"].includes(o.status);
  return `
  <div class="row"><div><div class="code" style="font-size:18px">${esc(o.code)}</div><div class="muted small">${esc(timeShort(o.createdAt))} · ${esc(o.city)}</div></div><button class="x" data-act="close" aria-label="Close">×</button></div>
  <div class="card">
    <div class="row between"><span class="pill ${o.status}">${STATUS[o.status]}</span>${o.deliveredAt ? `<span class="muted small">Delivered ${esc(timeShort(o.deliveredAt))}</span>` : ""}</div>
    <div class="steps mt">${[1, 2, 3, 4, 5].map((i) => `<i class="${o.status !== "cancelled" && i <= STEP[o.status] ? "on" : ""}"></i>`).join("")}</div>
    <dl class="kv mt">
      <dt>Pickup</dt><dd>${esc(o.pickupAddress)}${mapLink(o.pickupLat, o.pickupLng)}</dd>
      <dt>Sender</dt><dd>${esc(o.senderName)} · ${esc(o.senderPhone)}</dd>
      <dt>Drop-off</dt><dd>${esc(o.dropoffAddress)}${mapLink(o.dropoffLat, o.dropoffLng)}</dd>
      <dt>Receiver</dt><dd>${esc(o.receiverName)} · ${esc(o.receiverPhone)}</dd>
      <dt>Parcel</dt><dd>${esc(o.parcelType)} · ${Number(o.weightKg || 0).toFixed(1)} kg</dd>
      ${o.notes ? `<dt>Note</dt><dd>${esc(o.notes)}</dd>` : ""}
    </dl>
  </div>
  <div class="card">
    <dl class="kv">
      <dt>Delivery fee</dt><dd class="num">${money(o.deliveryFee)}</dd>
      <dt>Driver share</dt><dd class="num">${o.driverEarning ? money(o.driverEarning) : "—"}</dd>
      <dt>Company</dt><dd class="num" style="color:var(--purple)">${o.status === "delivered" ? money(d.companyRev(o)) : "—"}</dd>
      <dt>COD</dt><dd class="num">${o.codAmount ? money(o.codAmount) + (o.codSettled ? " · settled" : o.codCollected ? " · with driver" : "") : "None"}</dd>
    </dl>
  </div>
  <div class="card">
    <div class="row between"><div><b>Delivery code</b><div class="muted small">Receiver gives this to the driver</div></div>
    <div id="otp-box">${UI.drawer.otp ? `<span class="otp">${esc(UI.drawer.otp)}</span>` : `<button class="btn ghost sm" data-act="show-otp" data-id="${o.id}">Show code</button>`}</div></div>
  </div>
  ${canAssign ? `<div class="card">
    <b>${o.driverId ? "Reassign driver" : "Assign a driver"}</b>
    <div class="row mt" style="flex-wrap:nowrap">
      <select class="input" id="assign-sel" style="flex:1">${avail.map((dr) => `<option value="${dr.id}" ${dr.id === o.driverId ? "selected" : ""}>${dr.online ? "● " : "○ "}${esc(dr.name)} · ${esc(dr.city)} · ${load(dr.id)} active</option>`).join("")}</select>
      <button class="btn" data-act="assign" data-id="${o.id}">Assign</button>
    </div>
  </div>` : o.driverName ? `<div class="card"><dl class="kv"><dt>Driver</dt><dd>${esc(o.driverName)} · ${esc(o.driverPhone || "")}</dd></dl></div>` : ""}
  <div class="row">
    ${ACTIVE.includes(o.status) ? `<button class="btn danger" data-act="cancel" data-id="${o.id}">Cancel order</button>` : ""}
    ${S.mode === "demo" && ["picked_up", "out_for_delivery", "accepted", "assigned"].includes(o.status) ? `<button class="btn teal" data-act="deliver" data-id="${o.id}">Mark delivered (demo)</button>` : ""}
  </div>`;
}

// ===================================================================== dispatch
function dispatchView(d) {
  const queue = d.unassigned.slice().sort((a, b) => a.createdAt - b.createdAt);
  const sel = queue.find((o) => o.id === UI.dispatchOrder) || queue[0];
  const load = (id) => d.active.filter((x) => x.driverId === id).length;
  const drivers = d.approved.slice().sort((a, b) => (b.online - a.online) || (sel && a.city === sel.city ? -1 : 0) || load(a.id) - load(b.id));
  const onRoad = d.active.filter((o) => o.status !== "pending");
  return `
  <div class="grid g3">
    <div class="card" style="grid-column: span 1">
      <h3>Waiting for a driver <span class="muted">(${queue.length})</span></h3><p class="hint">Pick an order, then a driver</p>
      ${queue.map((o) => `<div class="list-item" style="cursor:pointer;${sel && sel.id === o.id ? "background:var(--purple-soft);border-radius:12px;padding:10px;margin:2px -10px" : ""}" data-pick="${o.id}">
        <div style="flex:1;min-width:0"><div class="row between"><span class="code">${esc(o.code)}</span><span class="small muted">${esc(ago(o.createdAt))}</span></div>
        <div class="small route">${esc(o.pickupAddress)} → ${esc(o.dropoffAddress)}</div>
        <div class="small muted">${money(o.deliveryFee)}${o.codAmount ? ` · COD ${money(o.codAmount)}` : ""}</div></div></div>`).join("") || `<div class="empty">Queue is empty. New orders appear here instantly.</div>`}
    </div>
    <div class="card" style="grid-column: span 2">
      <div class="row between"><div><h3>${sel ? `Assign ${esc(sel.code)}` : "Drivers"}</h3><p class="hint">${sel ? `${esc(sel.city)} · ${esc(sel.pickupAddress)}` : "Online drivers first"}</p></div>
      <span class="muted small">${d.online.length} online · ${onRoad.length} deliveries on the road</span></div>
      <div class="tbl-wrap"><table><thead><tr><th>Driver</th><th>City</th><th>Vehicle</th><th>Status</th><th class="r">Active jobs</th><th>Location</th><th></th></tr></thead><tbody>
      ${drivers.map((dr) => `<tr>
        <td><b>${esc(dr.name)}</b><div class="small muted">${esc(dr.phone)}</div></td>
        <td>${esc(dr.city)}</td><td>${esc(dr.vehicleType || "")}</td>
        <td><span class="pill ${dr.online ? "online" : "offline"}"><i class="dot"></i>${dr.online ? "Online" : "Offline"}</span></td>
        <td class="r">${load(dr.id)}</td>
        <td>${dr.location ? `<a target="_blank" rel="noopener" href="https://www.google.com/maps/search/?api=1&query=${dr.location.lat},${dr.location.lng}">${icon("pin").replace("<svg", '<svg style="width:15px;height:15px;vertical-align:-3px"')} Map</a>` : `<span class="muted">—</span>`}</td>
        <td>${sel ? `<button class="btn sm" data-act="dispatch" data-order="${sel.id}" data-driver="${dr.id}">Assign</button>` : ""}</td>
      </tr>`).join("") || `<tr><td colspan="7" class="empty">No approved drivers yet.</td></tr>`}
      </tbody></table></div>
    </div>
  </div>`;
}

// ===================================================================== drivers
function driverStats(d, dr) {
  const since = d.today - 29 * DAY;
  const mine = d.delivered.filter((o) => o.driverId === dr.id);
  const m30 = mine.filter((o) => o.deliveredAt >= since);
  return {
    total: mine.length,
    n30: m30.length,
    earn30: sum(m30, (o) => o.driverEarning),
    cash: sum(mine.filter((o) => o.codCollected && !o.codSettled), (o) => o.codAmount),
    active: d.active.filter((o) => o.driverId === dr.id).length,
  };
}
function driversView(d) {
  const tabs = [
    ["applications", "Applications", d.drivers.filter((x) => x.status === "pending")],
    ["active", "Active", d.approved],
    ["inactive", "Suspended & rejected", d.drivers.filter((x) => ["suspended", "rejected"].includes(x.status))],
  ];
  const cur = tabs.find((t) => t[0] === UI.driverTab) || tabs[0];
  let body;
  if (cur[0] === "applications") {
    body = cur[2].length ? `<div class="grid g2">${cur[2].map((dr) => `<div class="card">
      <div class="row between"><div><h3>${esc(dr.name)}</h3><div class="muted small">${esc(dr.phone)} · applied ${esc(ago(dr.submittedAt || Date.now()))}</div></div><span class="pill pending">Pending review</span></div>
      <dl class="kv mt"><dt>City</dt><dd>${esc(dr.city)}</dd><dt>Vehicle</dt><dd>${esc(dr.vehicleType)} · ${esc(dr.plateNumber)}</dd><dt>ID / Iqama</dt><dd>${esc(dr.idNumber)}</dd></dl>
      <div class="docs mt">${["license", "vehicle", "selfie"].map((k) => dr.documents && dr.documents[k] ? `<figure><a href="${esc(dr.documents[k])}" target="_blank" rel="noopener"><img src="${esc(dr.documents[k])}" alt="${k}"></a><figcaption>${{ license: "Driving license", vehicle: "Vehicle", selfie: "Photo" }[k]}</figcaption></figure>` : "").join("")}</div>
      <div class="row mt"><button class="btn teal" data-act="approve" data-id="${dr.id}">Approve driver</button><button class="btn danger" data-act="reject" data-id="${dr.id}">Reject…</button></div>
    </div>`).join("")}</div>` : `<div class="card empty">No applications waiting. New sign-ups from the driver app appear here.</div>`;
  } else {
    const list = cur[2].map((dr) => ({ dr, st: driverStats(d, dr) })).sort((a, b) => b.st.n30 - a.st.n30);
    body = `<div class="card"><div class="tbl-wrap" style="margin-top:-18px"><table><thead><tr><th>Driver</th><th>City</th><th>Vehicle</th><th>Status</th><th class="r">Deliveries 30d</th><th class="r">Earned 30d</th><th class="r">Cash held</th><th class="r">Total</th></tr></thead><tbody>
      ${list.map(({ dr, st }) => `<tr class="click" data-driver="${dr.id}">
        <td><b>${esc(dr.name)}</b><div class="small muted">${esc(dr.phone)}</div></td><td>${esc(dr.city)}</td><td>${esc(dr.vehicleType)} · ${esc(dr.plateNumber)}</td>
        <td>${dr.status === "approved" ? `<span class="pill ${dr.online ? "online" : "offline"}"><i class="dot"></i>${dr.online ? "Online" : "Offline"}</span>` : `<span class="pill ${dr.status}">${esc(dr.status)}</span>`}</td>
        <td class="r">${st.n30}</td><td class="r">${money(st.earn30)}</td><td class="r" style="${st.cash ? "color:var(--warn);font-weight:700" : ""}">${money(st.cash)}</td><td class="r">${st.total}</td></tr>`).join("") || `<tr><td colspan="8" class="empty">Nobody here.</td></tr>`}
    </tbody></table></div></div>`;
  }
  return `<div class="tabs" style="margin-bottom:14px;width:max-content;max-width:100%">${tabs.map(([k, l, arr]) => `<button data-dtab="${k}" class="${cur[0] === k ? "on" : ""}">${l}<span class="c">${arr.length}</span></button>`).join("")}</div>${body}`;
}
function driverDrawer(d) {
  const dr = d.drivers.find((x) => x.id === UI.drawer.id);
  if (!dr) return `<button class="x" data-act="close">×</button>`;
  const st = driverStats(d, dr);
  const recent = d.delivered.filter((o) => o.driverId === dr.id).sort((a, b) => b.deliveredAt - a.deliveredAt).slice(0, 8);
  const unsettled = d.delivered.filter((o) => o.driverId === dr.id && o.codCollected && !o.codSettled);
  return `<div class="row"><div><h2 style="margin:0;font:700 20px Sora,sans-serif">${esc(dr.name)}</h2><div class="muted small">${esc(dr.phone)} · ${esc(dr.city)}</div></div><button class="x" data-act="close">×</button></div>
  <div class="grid g2">${kpi("Deliveries (30d)", String(st.n30), `${st.total} all time`, null, "box")}${kpi("Earned (30d)", money(st.earn30), "80% of fees", null, "money", false, "var(--ok-soft)", "var(--ok)")}</div>
  <div class="card"><div class="row between"><div><b>Cash with driver</b><div class="muted small">${unsettled.length} COD order(s) not handed over</div></div><b class="num" style="color:var(--warn);font-size:18px">${money(st.cash)}</b></div>
  ${unsettled.length ? `<button class="btn teal mt" data-act="settle-driver" data-id="${dr.id}">Mark ${money(st.cash)} received</button>` : ""}</div>
  <div class="card"><dl class="kv"><dt>Vehicle</dt><dd>${esc(dr.vehicleType)} · ${esc(dr.plateNumber)}</dd><dt>ID / Iqama</dt><dd>${esc(dr.idNumber || "—")}</dd><dt>Status</dt><dd><span class="pill ${dr.status}">${esc(dr.status)}</span></dd></dl>
  ${dr.documents ? `<div class="docs mt">${["license", "vehicle", "selfie"].map((k) => dr.documents[k] ? `<figure><a href="${esc(dr.documents[k])}" target="_blank" rel="noopener"><img src="${esc(dr.documents[k])}" alt="${k}"></a></figure>` : "").join("")}</div>` : ""}</div>
  <div class="card"><b>Recent deliveries</b>${recent.map((o) => `<div class="list-item"><span class="code small">${esc(o.code)}</span><span class="small muted" style="flex:1">${esc(timeShort(o.deliveredAt))}</span><b class="num small">${money(o.driverEarning)}</b></div>`).join("") || `<div class="muted small mt">None yet.</div>`}</div>
  <div class="row">${dr.status === "approved" ? `<button class="btn danger" data-act="suspend" data-id="${dr.id}">Suspend driver</button>` : `<button class="btn teal" data-act="approve" data-id="${dr.id}">Re-activate</button>`}</div>`;
}

// ===================================================================== customers
function customersView(d) {
  const q = UI.customerQuery.trim().toLowerCase();
  const since = d.today - 29 * DAY;
  const bal = {};
  (S.txs || []).forEach((t) => (bal[t.uid] = (bal[t.uid] || 0) + Number(t.amount || 0)));
  const rows = (S.customers || []).map((c) => {
    const mine = d.orders.filter((o) => o.customerId === c.id);
    const del = mine.filter((o) => o.status === "delivered");
    return { c, total: mine.length, n30: mine.filter((o) => o.createdAt >= since).length, fees: sum(del, (o) => o.deliveryFee), cod: sum(del, (o) => o.codAmount), bal: bal[c.id] || 0, last: Math.max(0, ...mine.map((o) => o.createdAt || 0)) };
  }).filter((r) => !q || `${r.c.name} ${r.c.phone}`.toLowerCase().includes(q)).sort((a, b) => b.n30 - a.n30 || b.total - a.total);
  const activeCust = rows.filter((r) => r.n30 > 0).length;
  return `<div class="grid g4" style="margin-bottom:16px">
    ${kpi("Customers", fmt0.format((S.customers || []).length), `${activeCust} ordered in 30 days`, null, "customers")}
    ${kpi("Business senders", fmt0.format((S.customers || []).filter((c) => c.business).length), "Shops & online sellers", null, "box", false, "var(--teal-soft)", "var(--teal)")}
    ${kpi("COD volume (all time)", moneyShort(sum(rows, (r) => r.cod)), "Collected for customers", null, "finance", false, "var(--ok-soft)", "var(--ok)")}
    ${kpi("Wallet balances", moneyShort(sum(rows, (r) => Math.max(0, r.bal))), "Owed to customers", null, "money", false, "var(--warn-soft)", "var(--warn)")}
  </div>
  <div class="card"><div class="row between"><h3>${rows.length} customers</h3><input class="input" id="c-q" placeholder="Search name or phone…" value="${esc(UI.customerQuery)}" style="width:240px"></div>
  <div class="tbl-wrap mt"><table><thead><tr><th>Customer</th><th>Phone</th><th class="r">Orders 30d</th><th class="r">All orders</th><th class="r">Fees paid</th><th class="r">COD volume</th><th class="r">Wallet</th><th>Last order</th></tr></thead><tbody>
  ${rows.map((r) => `<tr><td><b>${esc(r.c.name)}</b> ${r.c.business ? `<span class="pill biz">Business</span>` : ""}</td><td class="muted">${esc(r.c.phone)}</td><td class="r">${r.n30}</td><td class="r">${r.total}</td><td class="r">${money(r.fees)}</td><td class="r">${money(r.cod)}</td><td class="r" style="font-weight:700;color:${r.bal >= 0 ? "var(--ok)" : "var(--bad)"}">${money(r.bal)}</td><td class="muted">${r.last ? esc(timeShort(r.last)) : "—"}</td></tr>`).join("") || `<tr><td colspan="8" class="empty">No customers found.</td></tr>`}
  </tbody></table></div></div>`;
}

// ===================================================================== finance
function financeView(d) {
  const since = d.today - 29 * DAY;
  const m30 = d.delivered.filter((o) => o.deliveredAt >= since);
  const gross = sum(m30, (o) => o.deliveryFee);
  const payouts = sum(m30, (o) => o.driverEarning);
  const rev = gross - payouts;
  const cod30 = sum(m30, (o) => o.codAmount);
  const byDriver = d.drivers.map((dr) => {
    const un = d.delivered.filter((o) => o.driverId === dr.id && o.codCollected && !o.codSettled);
    return { dr, n: un.length, amt: sum(un, (o) => o.codAmount), oldest: un.length ? Math.min(...un.map((o) => o.deliveredAt)) : 0 };
  }).filter((x) => x.n > 0).sort((a, b) => b.amt - a.amt);
  const custName = (uid) => ((S.customers || []).find((c) => c.id === uid) || {}).name || uid;
  const wds = (S.withdrawals || []).slice().sort((a, b) => b.createdAt - a.createdAt);
  const revSeries = series(d.delivered, (o) => o.deliveredAt, d.companyRev, 30);
  const grossSeries = series(d.delivered, (o) => o.deliveredAt, (o) => o.deliveryFee, 30);
  return `<div class="grid g4">
    ${kpi("Gross delivery fees", money(gross), "Last 30 days", null, "money", true)}
    ${kpi("Driver earnings", money(payouts), `${S.pricing.driverSharePct}% of fees`, null, "drivers", false, "var(--teal-soft)", "var(--teal)")}
    ${kpi("Company revenue", money(rev), `${gross ? Math.round((rev / gross) * 100) : 0}% margin`, null, "finance", false, "var(--ok-soft)", "var(--ok)")}
    ${kpi("COD handled", money(cod30), `${money(d.codWithDrivers)} still with drivers`, null, "box", false, "var(--warn-soft)", "var(--warn)")}
  </div>
  <div class="card mt"><h3>Fees vs revenue</h3><p class="hint">Daily, last 30 days</p>${barLineChart(grossSeries, revSeries, dayLabels(30), { barName: "Gross fees", lineName: "Company revenue", fmtBar: (v) => fmt0.format(v) })}</div>
  <div class="grid g2 mt">
    <div class="card"><h3>Cash on delivery with drivers</h3><p class="hint">Collect the cash, then mark it received</p>
      <div class="tbl-wrap"><table><thead><tr><th>Driver</th><th class="r">Orders</th><th>Oldest</th><th class="r">Amount</th><th></th></tr></thead><tbody>
      ${byDriver.map((x) => `<tr><td><b>${esc(x.dr.name)}</b><div class="small muted">${esc(x.dr.phone)}</div></td><td class="r">${x.n}</td><td class="muted">${esc(ago(x.oldest))}</td><td class="r" style="font-weight:800;color:var(--warn)">${money(x.amt)}</td><td><button class="btn teal sm" data-act="settle-driver" data-id="${x.dr.id}">Received</button></td></tr>`).join("") || `<tr><td colspan="5" class="empty">All cash has been handed over.</td></tr>`}
      </tbody></table></div></div>
    <div class="card"><h3>Customer withdrawals</h3><p class="hint">Requests to transfer wallet balance to the bank</p>
      <div class="tbl-wrap"><table><thead><tr><th>Customer</th><th>Requested</th><th class="r">Amount</th><th>Status</th><th></th></tr></thead><tbody>
      ${wds.map((w) => `<tr><td><b>${esc(custName(w.uid))}</b></td><td class="muted">${esc(timeShort(w.createdAt))}</td><td class="r"><b>${money(w.amount)}</b></td><td><span class="pill ${w.status}">${esc(w.status)}</span></td><td>${w.status === "pending" ? `<div class="row" style="flex-wrap:nowrap"><button class="btn teal sm" data-act="wd-ok" data-id="${w.id}">Paid</button><button class="btn danger sm" data-act="wd-no" data-id="${w.id}">Reject</button></div>` : ""}</td></tr>`).join("") || `<tr><td colspan="5" class="empty">No withdrawal requests.</td></tr>`}
      </tbody></table></div></div>
  </div>`;
}

// ===================================================================== reports
function reportsView(d) {
  const p = UI.reportPeriod;
  const since = p === "all" ? 0 : d.today - (Number(p) - 1) * DAY;
  const inP = d.orders.filter((o) => (o.createdAt || 0) >= since);
  const del = inP.filter((o) => o.status === "delivered");
  const canc = inP.filter((o) => o.status === "cancelled");
  const rate = inP.length ? Math.round((del.length / inP.length) * 100) : 0;
  return `<div class="row between" style="margin-bottom:14px"><div class="tabs">${[["7", "7 days"], ["30", "30 days"], ["90", "90 days"], ["all", "All time"]].map(([v, l]) => `<button data-rper="${v}" class="${p === v ? "on" : ""}">${l}</button>`).join("")}</div></div>
  <div class="grid g4">
    ${kpi("Orders", fmt0.format(inP.length), `${canc.length} cancelled`, null, "orders")}
    ${kpi("Delivered", fmt0.format(del.length), `${rate}% success rate`, null, "box", false, "var(--ok-soft)", "var(--ok)")}
    ${kpi("Gross fees", money(sum(del, (o) => o.deliveryFee)), "Delivered orders", null, "money", false, "var(--teal-soft)", "var(--teal)")}
    ${kpi("Company revenue", money(sum(del, d.companyRev)), "After driver earnings", null, "finance", false, "var(--purple-soft)", "var(--purple)")}
  </div>
  <div class="grid g3 mt">
    ${reportCard("Orders report", "Every order with route, customer, driver, fee, COD and status.", "orders")}
    ${reportCard("Driver earnings", "Deliveries, earnings and cash held per driver.", "drivers")}
    ${reportCard("Customer statement", "Orders, fees and cash collected per customer.", "customers")}
  </div>
  <p class="muted small mt">Files open in Excel or Google Sheets (CSV).</p>`;
}
function reportCard(title, body, kind) {
  return `<div class="card"><h3>${title}</h3><p class="hint">${body}</p><button class="btn" data-act="export" data-kind="${kind}">${icon("download")}Download CSV</button></div>`;
}
function exportCsv(kind) {
  const d = derive();
  const p = UI.reportPeriod;
  const since = p === "all" ? 0 : d.today - (Number(p) - 1) * DAY;
  const inP = d.orders.filter((o) => (o.createdAt || 0) >= since);
  let rows;
  if (kind === "orders") {
    rows = [["Code", "Created", "Status", "City", "Sender", "Sender phone", "Pickup", "Receiver", "Receiver phone", "Drop-off", "Driver", "Fee", "Driver earning", "COD", "COD settled", "Delivered"]];
    inP.forEach((o) => rows.push([o.code, iso(o.createdAt), STATUS[o.status], o.city, o.senderName, o.senderPhone, o.pickupAddress, o.receiverName, o.receiverPhone, o.dropoffAddress, o.driverName, o.deliveryFee, o.driverEarning || 0, o.codAmount || 0, o.codSettled ? "yes" : "no", iso(o.deliveredAt)]));
  } else if (kind === "drivers") {
    rows = [["Driver", "Phone", "City", "Status", "Deliveries", "Earnings", "COD collected", "Cash held"]];
    d.drivers.forEach((dr) => {
      const mine = inP.filter((o) => o.driverId === dr.id && o.status === "delivered");
      const held = d.delivered.filter((o) => o.driverId === dr.id && o.codCollected && !o.codSettled);
      rows.push([dr.name, dr.phone, dr.city, dr.status, mine.length, sum(mine, (o) => o.driverEarning).toFixed(2), sum(mine, (o) => o.codAmount).toFixed(2), sum(held, (o) => o.codAmount).toFixed(2)]);
    });
  } else {
    rows = [["Customer", "Phone", "Orders", "Delivered", "Fees", "COD collected"]];
    (S.customers || []).forEach((c) => {
      const mine = inP.filter((o) => o.customerId === c.id);
      const del = mine.filter((o) => o.status === "delivered");
      rows.push([c.name, c.phone, mine.length, del.length, sum(del, (o) => o.deliveryFee).toFixed(2), sum(del, (o) => o.codAmount).toFixed(2)]);
    });
  }
  const csv = "﻿" + rows.map((r) => r.map((v) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\r\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  a.download = `msi-parcel-${kind}-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  toast("Report downloaded");
}
const iso = (t) => (t ? new Date(t).toISOString().replace("T", " ").slice(0, 16) : "");

// ===================================================================== settings
function settingsView(d) {
  const p = S.pricing;
  const z0 = (S.zones || [])[0];
  return `<div class="grid g2">
    <div class="card"><h3>Service cities</h3><p class="hint">Customers can only book in active cities. Each city has its own base fee.</p>
      <div class="tbl-wrap"><table><thead><tr><th>City</th><th class="r">Base fee</th><th>Status</th><th class="r">Orders 30d</th><th></th></tr></thead><tbody>
      ${(S.zones || []).map((z) => `<tr><td><b>${esc(z.name)}</b></td><td class="r">${money(z.baseFee)}</td><td><span class="pill ${z.active ? "approved" : "offline"}">${z.active ? "Active" : "Paused"}</span></td><td class="r">${d.orders.filter((o) => o.city === z.name && o.createdAt >= d.today - 29 * DAY).length}</td><td><button class="btn line sm" data-act="edit-zone" data-name="${esc(z.name)}">Edit</button></td></tr>`).join("")}
      </tbody></table></div>
      <button class="btn ghost mt" data-act="add-zone">${icon("plus")}Add city</button>
    </div>
    <div class="card"><h3>Pricing rules</h3><p class="hint">Applied to every new order. The server recalculates the fee, so customers cannot change it.</p>
      <form id="priceForm" class="form two">
        <label class="f">Free weight (kg)<input class="input" id="p-free" type="number" min="0" step="0.5" value="${p.freeKg}"></label>
        <label class="f">Extra per kg (SAR)<input class="input" id="p-kg" type="number" min="0" step="0.5" value="${p.perKgFee}"></label>
        <label class="f">COD handling (%)<input class="input" id="p-cod" type="number" min="0" step="0.1" value="${p.codFeePct}"></label>
        <label class="f">Driver share of fee (%)<input class="input" id="p-share" type="number" min="0" max="100" step="1" value="${p.driverSharePct}"></label>
        <div style="grid-column:1/-1" class="row between"><span class="muted small">Example ${z0 ? esc(z0.name) : ""}: 7 kg with SAR 200 COD = <b id="p-ex">${money(quote(p, z0, 7, 200))}</b></span><button class="btn" type="submit">Save pricing</button></div>
      </form>
    </div>
    <div class="card"><h3>Connection</h3><p class="hint">Where this console reads and saves data</p>
      <dl class="kv"><dt>Mode</dt><dd><span class="mode ${S.mode}"><i></i>${S.mode === "demo" ? "Demo (this browser)" : "Live (Firebase)"}</span></dd><dt>Signed in</dt><dd>${esc(store.currentUser().email || "")}</dd></dl>
      ${S.mode === "demo" ? `<p class="muted small mt">To go live: create the Firebase project, paste its web config into <code>admin/config.js</code>, and give your account <code>role: "admin"</code> in <code>users</code>.</p><button class="btn line mt" data-act="reset-demo">Reset demo data</button>` : ""}
    </div>
  </div>`;
}

// ===================================================================== modals
function modalView(d) {
  if (UI.modal.type === "zone") {
    const z = UI.modal.zone || { name: "", baseFee: 20, active: true };
    return `<div class="row"><h3 style="margin:0">${UI.modal.zone ? "Edit city" : "Add city"}</h3><button class="x" data-act="close">×</button></div>
    <form id="zoneForm" class="form mt">
      <label class="f">City name<input class="input" id="z-name" required value="${esc(z.name)}" placeholder="e.g. Riyadh"></label>
      <label class="f">Base delivery fee (SAR)<input class="input" id="z-fee" type="number" min="0" step="1" required value="${z.baseFee}"></label>
      <label class="row" style="gap:8px"><input type="checkbox" id="z-act" ${z.active ? "checked" : ""}> City is active (customers can book)</label>
      <div class="row between">${UI.modal.zone ? `<button type="button" class="btn danger" data-act="del-zone" data-name="${esc(z.name)}">Delete</button>` : "<span></span>"}<button class="btn" type="submit">Save city</button></div>
    </form>`;
  }
  if (UI.modal.type === "reject") {
    return `<div class="row"><h3 style="margin:0">Reject application</h3><button class="x" data-act="close">×</button></div>
    <form id="rejectForm" class="form mt"><label class="f">Reason shown to the driver<textarea class="input" id="rj-reason" rows="3" required placeholder="e.g. License photo is not readable. Please take a clearer photo."></textarea></label>
    <div class="row" style="justify-content:flex-end"><button class="btn danger" type="submit">Reject</button></div></form>`;
  }
  const zones = (S.zones || []).filter((z) => z.active);
  return `<div class="row"><h3 style="margin:0">New order</h3><button class="x" data-act="close">×</button></div>
  <p class="muted small">For phone or walk-in customers. The delivery code is created automatically.</p>
  <form id="orderForm" class="form two mt">
    <label class="f">City<select class="input" id="n-city">${zones.map((z) => `<option>${esc(z.name)}</option>`).join("")}</select></label>
    <label class="f">Parcel type<select class="input" id="n-type">${["Documents", "Small box", "Medium box", "Large box", "Food", "Electronics"].map((t) => `<option>${t}</option>`).join("")}</select></label>
    <label class="f">Sender name<input class="input" id="n-sname" required></label>
    <label class="f">Sender mobile<input class="input" id="n-sphone" required inputmode="tel"></label>
    <label class="f" style="grid-column:1/-1">Pickup address<input class="input" id="n-pick" required></label>
    <label class="f">Receiver name<input class="input" id="n-rname" required></label>
    <label class="f">Receiver mobile<input class="input" id="n-rphone" required inputmode="tel"></label>
    <label class="f" style="grid-column:1/-1">Drop-off address<input class="input" id="n-drop" required></label>
    <label class="f">Weight (kg)<input class="input" id="n-kg" type="number" min="0.1" step="0.1" value="1"></label>
    <label class="f">COD amount (SAR)<input class="input" id="n-cod" type="number" min="0" step="0.5" value="0"></label>
    <label class="f" style="grid-column:1/-1">Note for driver<input class="input" id="n-notes"></label>
    <div style="grid-column:1/-1" class="row between"><span>Fee: <b id="n-fee">${money(quote(S.pricing, zones[0], 1, 0))}</b></span><button class="btn" type="submit">Create order</button></div>
  </form>`;
}

// ===================================================================== events
function open(kind, id) { UI.drawer = { type: kind, id }; UI.modal = null; render(); }
function closeAll() { UI.drawer = null; UI.modal = null; render(); }
async function run(fn, ok) {
  try {
    const r = await fn();
    if (ok) toast(typeof ok === "function" ? ok(r) : ok);
  } catch (e) {
    console.error(e);
    toast(friendly(e), true);
  }
}
function bind() {
  const app = document.getElementById("app");
  app.onclick = (e) => {
    const t = e.target.closest("[data-act],[data-order],[data-driver],[data-otab],[data-dtab],[data-pick],[data-rper]");
    if (!t) return;
    if (t.dataset.otab) { UI.orderTab = t.dataset.otab; return render(); }
    if (t.dataset.dtab) { UI.driverTab = t.dataset.dtab; return render(); }
    if (t.dataset.rper) { UI.reportPeriod = t.dataset.rper; return render(); }
    if (t.dataset.pick) { UI.dispatchOrder = t.dataset.pick; return render(); }
    const a = t.dataset.act;
    if (!a && t.dataset.order) return open("order", t.dataset.order);
    if (!a && t.dataset.driver) return open("driver", t.dataset.driver);
    const id = t.dataset.id;
    switch (a) {
      case "menu": $("#side").classList.toggle("open"); break;
      case "close": closeAll(); break;
      case "logout": run(() => store.signOut()); break;
      case "new-order": UI.modal = { type: "order" }; UI.drawer = null; render(); bindOrderForm(); break;
      case "show-otp": run(async () => { UI.drawer.otp = await store.getOtp(id); render(); }); break;
      case "assign": run(() => store.assignDriver(id, $("#assign-sel").value), "Driver assigned"); break;
      case "dispatch": run(() => store.assignDriver(t.dataset.order, t.dataset.driver), () => { UI.dispatchOrder = null; return "Driver assigned"; }); break;
      case "cancel": if (t.dataset.armed) { run(() => store.cancelOrder(id), "Order cancelled"); } else { t.dataset.armed = "1"; t.textContent = "Tap again to cancel"; } break;
      case "deliver": run(() => store.markDelivered(id), "Marked delivered"); break;
      case "approve": run(() => store.setDriverStatus(id, "approved"), "Driver approved. They can now receive jobs."); break;
      case "reject": UI.modal = { type: "reject", id }; UI.drawer = null; render(); bindRejectForm(); break;
      case "suspend": if (t.dataset.armed) { run(() => store.setDriverStatus(id, "suspended"), "Driver suspended"); } else { t.dataset.armed = "1"; t.textContent = "Tap again to suspend"; } break;
      case "settle-driver": {
        const ids = derive().delivered.filter((o) => o.driverId === id && o.codCollected && !o.codSettled).map((o) => o.id);
        run(() => store.settleCash(ids), (total) => `Cash received: ${money(total)}`);
        break;
      }
      case "wd-ok": run(() => store.decideWithdrawal(id, true), "Marked as paid"); break;
      case "wd-no": run(() => store.decideWithdrawal(id, false), "Request rejected"); break;
      case "add-zone": UI.modal = { type: "zone" }; render(); bindZoneForm(); break;
      case "edit-zone": UI.modal = { type: "zone", zone: (S.zones || []).find((z) => z.name === t.dataset.name) }; render(); bindZoneForm(); break;
      case "del-zone": if (t.dataset.armed) { run(() => store.deleteZone(t.dataset.name), () => { UI.modal = null; return "City deleted"; }); } else { t.dataset.armed = "1"; t.textContent = "Tap again to delete"; } break;
      case "export": exportCsv(t.dataset.kind); break;
      case "reset-demo": if (t.dataset.armed) { store.reset(); toast("Demo data reset"); } else { t.dataset.armed = "1"; t.textContent = "Tap again to reset"; } break;
    }
  };
  const oq = $("#o-q");
  if (oq) oq.oninput = () => { UI.orderQuery = oq.value; render(); };
  const oc = $("#o-city");
  if (oc) oc.onchange = () => { UI.orderCity = oc.value; render(); };
  const op = $("#o-period");
  if (op) op.onchange = () => { UI.orderPeriod = op.value; render(); };
  const cq = $("#c-q");
  if (cq) cq.oninput = () => { UI.customerQuery = cq.value; render(); };
  const pf = $("#priceForm");
  if (pf) {
    const upd = () => { const z0 = (S.zones || [])[0]; $("#p-ex").textContent = money(quote(readPricing(), z0, 7, 200)); };
    ["p-free", "p-kg", "p-cod", "p-share"].forEach((i) => ($("#" + i).oninput = upd));
    pf.onsubmit = (e) => { e.preventDefault(); run(() => store.savePricing(readPricing()), "Pricing saved"); };
  }
  if (UI.modal && UI.modal.type === "order") bindOrderForm();
  if (UI.modal && UI.modal.type === "zone") bindZoneForm();
  if (UI.modal && UI.modal.type === "reject") bindRejectForm();
  document.onkeydown = (e) => { if (e.key === "Escape" && (UI.drawer || UI.modal)) closeAll(); };
}
function readPricing() {
  return { freeKg: Number($("#p-free").value) || 0, perKgFee: Number($("#p-kg").value) || 0, codFeePct: Number($("#p-cod").value) || 0, driverSharePct: Math.min(100, Number($("#p-share").value) || 0) };
}
function bindOrderForm() {
  const f = $("#orderForm");
  if (!f || f.dataset.bound) return;
  f.dataset.bound = "1";
  const upd = () => {
    const z = (S.zones || []).find((x) => x.name === $("#n-city").value);
    $("#n-fee").textContent = money(quote(S.pricing, z, $("#n-kg").value, $("#n-cod").value));
  };
  ["n-city", "n-kg", "n-cod"].forEach((i) => ($("#" + i).oninput = upd));
  f.onsubmit = (e) => {
    e.preventDefault();
    const v = (i) => $("#" + i).value.trim();
    const data = { city: v("n-city"), parcelType: v("n-type"), senderName: v("n-sname"), senderPhone: v("n-sphone"), pickupAddress: v("n-pick"), receiverName: v("n-rname"), receiverPhone: v("n-rphone"), dropoffAddress: v("n-drop"), weightKg: Number(v("n-kg")) || 0, codAmount: Number(v("n-cod")) || 0, notes: v("n-notes") };
    run(() => store.createOrder(data), () => { UI.modal = null; UI.page = "dispatch"; location.hash = "#dispatch"; return "Order created"; });
  };
}
function bindZoneForm() {
  const f = $("#zoneForm");
  if (!f || f.dataset.bound) return;
  f.dataset.bound = "1";
  f.onsubmit = (e) => {
    e.preventDefault();
    const original = UI.modal.zone ? UI.modal.zone.name : null;
    const zone = { name: $("#z-name").value.trim(), baseFee: Number($("#z-fee").value) || 0, active: $("#z-act").checked };
    run(() => store.saveZone(zone, original), () => { UI.modal = null; return "City saved"; });
  };
}
function bindRejectForm() {
  const f = $("#rejectForm");
  if (!f || f.dataset.bound) return;
  f.dataset.bound = "1";
  f.onsubmit = (e) => {
    e.preventDefault();
    const id = UI.modal.id;
    run(() => store.setDriverStatus(id, "rejected", $("#rj-reason").value.trim()), () => { UI.modal = null; return "Application rejected"; });
  };
}

let toastTimer;
function toast(msg, err = false) {
  let t = document.getElementById("toast");
  if (!t) { t = document.createElement("div"); t.id = "toast"; document.body.appendChild(t); }
  t.className = "toast" + (err ? " err" : "");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 3200);
}
