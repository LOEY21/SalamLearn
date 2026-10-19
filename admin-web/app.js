import {
  initializeApp,
  deleteApp,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  sendPasswordResetEmail,
  signOut,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  writeBatch,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { STAGES, GAMES, LESSONS } from "./curriculum-map.js";
import { renderHubView } from "./hub-view.js";

// Same public web config as prjct/lib/firebase_options.dart's `web` block —
// safe to expose client-side; access is enforced by firestore.rules, not by
// hiding this config.
const firebaseConfig = {
  apiKey: "AIzaSyBRyGa1YMut5KaO7fS-BUcglwWjOG12jMY",
  appId: "1:872626440680:web:ab9fc267ff83c1d220fc5d",
  messagingSenderId: "872626440680",
  projectId: "salamlearn-55712",
  authDomain: "salamlearn-55712.firebaseapp.com",
  storageBucket: "salamlearn-55712.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const loginView = document.getElementById("login-view");
const dashboardView = document.getElementById("dashboard-view");
const loginForm = document.getElementById("login-form");
const loginError = document.getElementById("login-error");
const whoami = document.getElementById("whoami");
const accessDenied = document.getElementById("access-denied");
const signoutBtn = document.getElementById("signout-btn");
const loadingOverlay = document.getElementById("loading-overlay");
const loadingMessage = document.getElementById("loading-message");
const toastContainer = document.getElementById("toast-container");
let currentLearners = [];
let hubData = null;
let lastParents = [];

function showLoading(message) {
  loadingMessage.textContent = message || "Please wait...";
  loadingOverlay.hidden = false;
}

function hideLoading() {
  loadingOverlay.hidden = true;
}

function showToast(message, type) {
  const el = document.createElement("div");
  el.className = `toast toast-${type === "error" ? "error" : "success"}`;
  el.textContent = message;
  toastContainer.appendChild(el);
  setTimeout(() => {
    el.classList.add("toast-out");
    el.addEventListener("animationend", () => el.remove());
  }, 2500);
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginError.hidden = true;
  const email = document.getElementById("login-email").value.trim();
  const password = document.getElementById("login-password").value;
  const submitBtn = loginForm.querySelector("button[type=submit]");
  submitBtn.disabled = true;
  showLoading("Signing in...");
  try {
    await signInWithEmailAndPassword(auth, email, password);
    hideLoading();
  } catch (err) {
    console.error("Sign-in failed:", err.code, err.message);
    loginError.textContent = describeAuthError(err);
    loginError.hidden = false;
    hideLoading();
    showToast("Sign in failed", "error");
  } finally {
    submitBtn.disabled = false;
  }
});

signoutBtn.addEventListener("click", () => signOut(auth));

function describeAuthError(err) {
  switch (err.code) {
    case "auth/invalid-email":
      return "That email address looks invalid.";
    case "auth/user-not-found":
    case "auth/wrong-password":
    case "auth/invalid-credential":
      return "Incorrect email or password.";
    case "auth/too-many-requests":
      return "Too many attempts — wait a moment and try again.";
    case "auth/email-already-in-use":
      return "An account with that email already exists.";
    case "auth/weak-password":
      return "Password must be at least 6 characters.";
    default:
      return "Sign-in failed. Please try again.";
  }
}

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    loginView.hidden = false;
    dashboardView.hidden = true;
    loginForm.reset();
    return;
  }

  // firestore.rules only blocks this account's *reads/writes* once it's
  // past this point — without checking admin status here too, any signed-in
  // non-admin (e.g. a stray parent/teacher account) would see the dashboard
  // shell itself (tabs, layout) before every table came back empty from
  // permission-denied. Bounce them back to login instead.
  let adminSnap;
  try {
    adminSnap = await getDoc(doc(db, "admins", user.uid));
  } catch (err) {
    console.error("Admin check failed:", err);
    await signOut(auth);
    loginError.textContent = `Couldn't verify admin access (${err.code ?? err.message}). Check your connection and try again.`;
    loginError.hidden = false;
    return;
  }
  if (!adminSnap.exists()) {
    await signOut(auth);
    loginError.textContent = "This account isn't authorized for admin access.";
    loginError.hidden = false;
    return;
  }

  loginView.hidden = true;
  dashboardView.hidden = false;
  whoami.textContent = user.email ?? "";
  whoami.title = user.email ?? "";
  document.getElementById("sidebar-avatar").textContent = (user.email ?? "A")[0].toUpperCase();

  showLoading("Loading dashboard...");
  await loadAllData();
  hideLoading();
});

// ---- Tabs ----
const pageMeta = {
  overview: { title: "Overview", subtitle: "Platform-wide statistics and recent activity" },
  parents: { title: "Parents / Guardians", subtitle: "Manage parent and guardian accounts" },
  teachers: { title: "Asatidz", subtitle: "Approve and manage teacher accounts" },
  learners: { title: "Learners", subtitle: "View and manage student profiles" },
  classes: { title: "Classes", subtitle: "Browse class sections and enroll students" },
  progress: { title: "Progress", subtitle: "Learning activity per learner, classroom and home" },
  trashbin: { title: "Trashbin", subtitle: "Restore or permanently delete removed records" },
  reports: { title: "Reports", subtitle: "Printable platform summary report" },
};
const tabButtons = document.querySelectorAll(".tab-btn");
tabButtons.forEach((btn) => {
  btn.addEventListener("click", () => {
    tabButtons.forEach((b) => {
      b.classList.toggle("active", b === btn);
      b.toggleAttribute("aria-current", b === btn);
    });
    document.querySelectorAll(".tab-panel").forEach((panel) => {
      panel.hidden = panel.id !== `tab-${btn.dataset.tab}`;
    });
    const meta = pageMeta[btn.dataset.tab];
    document.getElementById("page-title").textContent = meta.title;
    document.getElementById("page-subtitle").textContent = meta.subtitle;
    setDrawer(false);
  });
});

// ---- Mobile navigation drawer ----
const sidebar = document.getElementById("sidebar");
const sidebarScrim = document.getElementById("sidebar-scrim");
const menuBtn = document.getElementById("menu-btn");
function setDrawer(open) {
  sidebar.classList.toggle("open", open);
  sidebarScrim.hidden = !open;
  menuBtn.setAttribute("aria-expanded", String(open));
}
menuBtn.addEventListener("click", () => setDrawer(!sidebar.classList.contains("open")));
sidebarScrim.addEventListener("click", () => setDrawer(false));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") setDrawer(false);
});

// ---- Table search ----
document.addEventListener("input", (e) => {
  const input = e.target.closest(".table-search");
  if (!input) return;
  const tableId = input.dataset.table;
  const table = document.getElementById(tableId);
  if (!table) return;
  const term = input.value.toLowerCase().trim();
  const rows = table.querySelectorAll("tbody tr");
  rows.forEach((row) => {
    const text = row.textContent.toLowerCase();
    row.classList.toggle("table-row-hidden", term && !text.includes(term));
  });
});

// Reset search when switching tabs to avoid stale filters
tabButtons.forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".table-search").forEach((s) => {
      s.value = "";
      const table = document.getElementById(s.dataset.table);
      if (table) {
        table.querySelectorAll("tbody tr").forEach((r) => r.classList.remove("table-row-hidden"));
      }
    });
  });
});

document.getElementById("print-report-btn").addEventListener("click", () => window.print());

// ---- Data loading ----
// Collection names mirror `HiveBoxes` constants in the Flutter app
// (lib/data/local/hive_boxes.dart) — `firestore_mirror.dart` pushes to
// these exact collection names, one per Hive box. Streaks aren't stored —
// the Student Hub view derives them from progress records like the app does.
async function fetchAll(name) {
  const snap = await getDocs(collection(db, name));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// Port of the app's `studentIdFor` (prjct/lib/data/models/learner_profile.dart):
// FNV-1a over the learner doc id, 8 digits shown as "1234-5678". Must stay
// in sync with the Dart version, since teachers enroll learners by this ID.
function studentIdFor(learnerId) {
  let h = 0x811c9dc5;
  for (let i = 0; i < learnerId.length; i++) {
    h = (h ^ learnerId.charCodeAt(i)) >>> 0;
    h = (((h << 24) >>> 0) + h * 403) % 4294967296;
  }
  const digits = String(h % 100000000).padStart(8, "0");
  return `${digits.slice(0, 4)}-${digits.slice(4)}`;
}

function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function renderTable(tableEl, columns, rows, actions, bulk) {
  const actionsList = Array.isArray(actions) ? actions : (actions ? [actions] : []);
  const allColumns = actionsList.length > 0 ? [...columns, { label: "Actions" }] : columns;
  if (rows.length === 0) {
    tableEl.innerHTML = `
      <thead><tr>${allColumns.map((c) => `<th>${c.label}</th>`).join("")}</tr></thead>
      <tbody><tr class="empty-row"><td colspan="${allColumns.length}">No records yet.</td></tr></tbody>
    `;
    if (bulk) setupBulkSelect(tableEl, rows, bulk);
    return;
  }
  const head = `<tr>${allColumns.map((c) => `<th>${c.label}</th>`).join("")}</tr>`;
  tableEl.innerHTML = `<thead>${head}</thead><tbody></tbody>`;
  tableEl.classList.add("cards");
  tableEl.closest(".table-wrap")?.classList.add("cards-wrap");
  const tbody = tableEl.querySelector("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    columns.forEach((c) => {
      const td = document.createElement("td");
      td.dataset.label = c.label;
      const text = c.value(row) ?? "—";
      if (c.badge) {
        const badge = document.createElement("span");
        badge.className = `dash-badge dash-badge-${c.badge(row)}`;
        badge.textContent = text;
        td.appendChild(badge);
      } else {
        td.textContent = text;
      }
      tr.appendChild(td);
    });
    if (actionsList.length > 0) {
      const td = document.createElement("td");
      td.className = "actions-cell";
      actionsList.filter((act) => !act.show || act.show(row)).forEach((act) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = act.className ?? "btn-danger";
        btn.textContent = act.label;
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          act.onClick(row, btn);
        });
        td.appendChild(btn);
      });
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  });
  if (bulk) setupBulkSelect(tableEl, rows, bulk);
}

// Multi-select for a rendered table: "Select" / "Select all" in a bar above
// it, or long-press (500 ms) a row. `bulk` is [{ label, className, run(rows) }].
function setupBulkSelect(tableEl, rows, bulk) {
  const wrap = tableEl.closest(".table-wrap") ?? tableEl;
  let bar = wrap.previousElementSibling;
  if (!bar?.classList.contains("bulk-bar")) {
    bar = document.createElement("div");
    bar.className = "bulk-bar";
    wrap.before(bar);
  }
  tableEl.classList.add("bulk");
  tableEl.classList.remove("selecting");
  bar.hidden = rows.length === 0;
  if (rows.length === 0) return;

  const selected = new Set();
  const trs = [...tableEl.tBodies[0].rows];
  const makeBox = (label) => {
    const box = document.createElement("input");
    box.type = "checkbox";
    box.setAttribute("aria-label", label);
    return box;
  };
  const allBox = makeBox("Select all");
  const th = document.createElement("th");
  th.className = "select-col";
  th.append(allBox);
  tableEl.tHead.rows[0].prepend(th);
  const boxes = trs.map((tr) => {
    const td = document.createElement("td");
    td.className = "select-col";
    const box = makeBox("Select row");
    td.append(box);
    tr.prepend(td);
    return box;
  });

  const isSelecting = () => tableEl.classList.contains("selecting");
  const visible = () => trs.map((_, i) => i).filter((i) => !trs[i].classList.contains("table-row-hidden"));
  const allVisibleSelected = () => visible().every((i) => selected.has(i));
  const button = (label, className, onClick) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = className;
    b.textContent = label;
    b.addEventListener("click", onClick);
    return b;
  };

  const update = () => {
    trs.forEach((tr, i) => {
      boxes[i].checked = selected.has(i);
      tr.classList.toggle("row-selected", selected.has(i));
    });
    allBox.checked = selected.size > 0 && allVisibleSelected();
    bar.replaceChildren();
    if (!isSelecting()) {
      const hint = document.createElement("span");
      hint.textContent = "or long-press a row";
      bar.append(
        button("Select", "btn-ghost btn-small", () => setSelecting(true)),
        button("Select all", "btn-ghost btn-small", toggleAll),
        hint
      );
      return;
    }
    const count = document.createElement("span");
    count.className = "bulk-count";
    count.textContent = `${selected.size} selected`;
    bar.append(count);
    bulk.forEach((act) => {
      const b = button(act.label, act.className ?? "btn-view", () =>
        act.run([...selected].map((i) => rows[i]))
      );
      b.disabled = selected.size === 0;
      bar.append(b);
    });
    bar.append(
      button(selected.size > 0 && allVisibleSelected() ? "Unselect all" : "Select all", "btn-ghost btn-small", toggleAll),
      button("Cancel", "btn-ghost btn-small", () => setSelecting(false))
    );
  };
  const setSelecting = (on) => {
    tableEl.classList.toggle("selecting", on);
    if (!on) selected.clear();
    update();
  };
  const select = (i) => {
    tableEl.classList.add("selecting");
    selected.add(i);
    update();
  };
  const toggle = (i) => {
    if (selected.has(i)) selected.delete(i);
    else selected.add(i);
    update();
  };
  function toggleAll() {
    const unselect = selected.size > 0 && allVisibleSelected();
    visible().forEach((i) => (unselect ? selected.delete(i) : selected.add(i)));
    tableEl.classList.add("selecting");
    update();
  }

  allBox.addEventListener("change", toggleAll);
  boxes.forEach((box, i) => box.addEventListener("click", (e) => {
    e.stopPropagation();
    toggle(i);
  }));
  trs.forEach((tr, i) => {
    let timer = null;
    let longPressed = false;
    let startX = 0;
    let startY = 0;
    const cancel = () => {
      clearTimeout(timer);
      timer = null;
    };
    tr.addEventListener("pointerdown", (e) => {
      if (e.button !== 0 || e.target.closest("button, input")) return;
      longPressed = false;
      startX = e.clientX;
      startY = e.clientY;
      timer = setTimeout(() => {
        timer = null;
        longPressed = true;
        select(i);
      }, 500);
    });
    tr.addEventListener("pointermove", (e) => {
      if (timer && Math.hypot(e.clientX - startX, e.clientY - startY) > 10) cancel();
    });
    tr.addEventListener("pointerup", cancel);
    tr.addEventListener("pointerleave", cancel);
    tr.addEventListener("pointercancel", cancel);
    // Touch browsers fire contextmenu on long-press, sometimes before the timer.
    tr.addEventListener("contextmenu", (e) => {
      if (timer) {
        cancel();
        longPressed = true;
        select(i);
      }
      if (longPressed || isSelecting()) e.preventDefault();
    });
    tr.addEventListener("click", (e) => {
      if (longPressed) {
        longPressed = false;
        return;
      }
      if (isSelecting() && !e.target.closest("button, input")) toggle(i);
    });
  });
  update();
}

function computeInsights(data) {
  const { parents, learners, classes, enrollments, progress } = data;
  const enrolledLearnerIds = new Set(enrollments.map((e) => e.learnerId));
  const learnersNoClass = learners.filter((l) => !enrolledLearnerIds.has(l.id));
  const classesNoStudents = classes.filter(
    (c) => !enrollments.some((e) => e.classId === c.id)
  );
  const parentChildCounts = learners.reduce((acc, l) => {
    acc[l.parentId] = (acc[l.parentId] ?? 0) + 1;
    return acc;
  }, {});
  const maxChildren = Math.max(...Object.values(parentChildCounts), 0);
  const topParentId = Object.entries(parentChildCounts).find(
    ([, c]) => c === maxChildren
  );
  const topParent = topParentId ? parents.find((p) => p.id === topParentId[0]) : null;
  return { enrolledLearnerIds, learnersNoClass, classesNoStudents, maxChildren, topParent };
}

function renderDashboard(data) {
  const { parents, teachers, learners, classes, enrollments, progress } = data;

  const { enrolledLearnerIds, learnersNoClass, classesNoStudents, maxChildren, topParent } =
    computeInsights(data);
  const pendingTeachers = teachers.filter((t) => teacherStatus(t) === "pending").length;
  const monthAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
  const newParents = parents.filter((p) => p.createdAt && new Date(p.createdAt).getTime() >= monthAgo).length;

  const metrics = [
    {
      title: "Learners",
      value: learners.length,
      sub: `${enrolledLearnerIds.size} enrolled in a class`,
      tab: "learners",
      icon: `<circle cx="9" cy="7" r="4"></circle><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path>`,
    },
    {
      title: "Asatidz",
      value: teachers.length,
      sub: pendingTeachers > 0 ? `${pendingTeachers} awaiting approval` : "None awaiting approval",
      alert: pendingTeachers > 0,
      tab: "teachers",
      icon: `<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"></path><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"></path>`,
    },
    {
      title: "Parents",
      value: parents.length,
      sub: `${newParents} joined in the last 30 days`,
      tab: "parents",
      icon: `<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="8.5" cy="7" r="4"></circle><polyline points="17 11 19 13 23 9"></polyline>`,
    },
    {
      title: "Classes",
      value: classes.length,
      sub: classesNoStudents.length > 0 ? `${classesNoStudents.length} with no students` : "All have students",
      tab: "classes",
      icon: `<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path>`,
    },
  ];

  document.getElementById("stat-grid").innerHTML = metrics.map((m) => `
    <button type="button" class="stat-card" data-goto="${m.tab}">
      <span class="stat-card-icon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${m.icon}</svg></span>
      <span class="stat-card-title">${m.title}</span>
      <span class="stat-card-value">${m.value}</span>
      <span class="stat-card-sub${m.alert ? " stat-card-sub-alert" : ""}">${m.sub}</span>
    </button>
  `).join("");

  const pendingBadge = document.getElementById("nav-pending");
  pendingBadge.hidden = pendingTeachers === 0;
  pendingBadge.textContent = pendingTeachers;
  pendingBadge.title = `${pendingTeachers} awaiting approval`;

  // Recent joins
  const recentParents = [...parents].sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? "")).slice(0, 2);
  const recentTeachers = [...teachers].sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? "")).slice(0, 2);
  const recentLearners = [...learners].sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? "")).slice(0, 3);
  const recentItems = [
    ...recentParents.map((p) => ({ type: "Parent", name: p.fullName, date: p.createdAt })),
    ...recentTeachers.map((t) => ({ type: "Asatidz", name: t.fullName, date: t.createdAt })),
    ...recentLearners.map((l) => ({ type: "Learner", name: l.name, date: l.createdAt })),
  ].sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""));
  const joinsBody = document.querySelector("#dash-recent-joins .dash-card-body");
  joinsBody.innerHTML = recentItems.length === 0
    ? `<p class="empty-text">No accounts created yet.</p>`
    : `<table class="dash-table"><tbody>${recentItems.map((i) => `
      <tr>
        <td><span class="dash-badge dash-badge-${i.type.toLowerCase()}">${i.type}</span></td>
        <td>${escapeAttr(i.name)}</td>
        <td class="dash-date">${formatDate(i.date)}</td>
      </tr>`).join("")}</tbody></table>`;

  // Recent progress
  const recentProgress = [...progress]
    .sort((a, b) => (b.completedAt ?? "").localeCompare(a.completedAt ?? ""))
    .slice(0, 8);
  const learnerNameById = new Map(learners.map((l) => [l.id, l.name]));
  const progBody = document.querySelector("#dash-recent-progress .dash-card-body");
  progBody.innerHTML = recentProgress.length === 0
    ? `<p class="empty-text">No progress records yet.</p>`
    : `<table class="dash-table"><tbody>${recentProgress.map((r) => `
      <tr>
        <td>${escapeAttr(learnerNameById.get(r.learnerId) ?? r.learnerId)}</td>
        <td>${escapeAttr(r.moduleId)}</td>
        <td>${r.assignedByTeacher ? '<span class="dash-badge dash-badge-classroom">Class</span>' : '<span class="dash-badge dash-badge-home">Home</span>'}</td>
        <td class="dash-date">${formatDate(r.completedAt)}</td>
      </tr>`).join("")}</tbody></table>`;

  // Insights (counts already on the stat cards above are not repeated here)
  const lastActivity = recentProgress[0]?.completedAt;
  const insightsBody = document.querySelector("#dash-insights .dash-card-body");
  insightsBody.innerHTML = `
    <div class="insight-item"><strong>${learnersNoClass.length}</strong> learners not yet in any class</div>
    <div class="insight-item">${topParent ? `<strong>${escapeAttr(topParent.fullName)}</strong> has the most children (${maxChildren})` : "No parents with children yet"}</div>
    <div class="insight-item"><strong>${progress.length}</strong> total progress records</div>
    <div class="insight-item">Last activity: <strong>${lastActivity ? formatDate(lastActivity) : "none yet"}</strong></div>
  `;
}

document.getElementById("stat-grid").addEventListener("click", (e) => {
  const card = e.target.closest("[data-goto]");
  if (card) document.querySelector(`.tab-btn[data-tab="${card.dataset.goto}"]`).click();
});

// Bucket the last 8 weeks (Mon-start) of combined parent/teacher/learner
// signups into one count per week, oldest first, for the growth chart.
function computeWeeklySignups(data) {
  const { parents, teachers, learners } = data;
  const allDates = [...parents, ...teachers, ...learners]
    .map((r) => r.createdAt)
    .filter(Boolean)
    .map((d) => new Date(d));

  const weekStart = (d) => {
    const monday = new Date(d);
    const day = (monday.getDay() + 6) % 7; // 0 = Monday
    monday.setDate(monday.getDate() - day);
    monday.setHours(0, 0, 0, 0);
    return monday;
  };

  const today = weekStart(new Date());
  const buckets = [];
  for (let i = 7; i >= 0; i--) {
    const start = new Date(today);
    start.setDate(start.getDate() - i * 7);
    buckets.push({ start, count: 0 });
  }

  allDates.forEach((d) => {
    const start = weekStart(d).getTime();
    const bucket = buckets.find((b) => b.start.getTime() === start);
    if (bucket) bucket.count += 1;
  });

  return buckets.map((b) => ({
    label: b.start.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
    count: b.count,
  }));
}

// Plain inline SVG column chart — no charting library. Single series (brand
// teal), so no legend; bar caps carry the value directly per dataviz spec.
function renderWeeklyChart(weeks) {
  const width = 640;
  const height = 160;
  const padTop = 24;
  const padBottom = 24;
  const plotH = height - padTop - padBottom;
  const bandW = width / weeks.length;
  const barW = Math.min(24, bandW * 0.5);
  const maxCount = Math.max(...weeks.map((w) => w.count), 1);

  const bars = weeks.map((w, i) => {
    const x = i * bandW + (bandW - barW) / 2;
    const barH = (w.count / maxCount) * plotH;
    const y = padTop + (plotH - barH);
    return `
      <rect x="${x}" y="${y}" width="${barW}" height="${Math.max(barH, 1)}" rx="4" ry="4" fill="var(--teal)" />
      <text x="${x + barW / 2}" y="${y - 6}" text-anchor="middle" class="report-chart-value">${w.count}</text>
      <text x="${x + barW / 2}" y="${height - 6}" text-anchor="middle" class="report-chart-label">${w.label}</text>
    `;
  }).join("");

  return `
    <svg viewBox="0 0 ${width} ${height}" class="report-chart" role="img" aria-label="New accounts per week, last 8 weeks">
      <line x1="0" y1="${padTop + plotH}" x2="${width}" y2="${padTop + plotH}" class="report-chart-baseline" />
      ${bars}
    </svg>
  `;
}

// Donut chart of user counts by role. Brand palette, value + legend labeled
// directly since it's a one-off report render (no hover/tooltip available on print).
function renderRoleDonut(segments) {
  const size = 160;
  const r = 56;
  const cx = size / 2;
  const cy = size / 2;
  const total = segments.reduce((sum, s) => sum + s.value, 0) || 1;

  let angle = -90;
  const arcs = segments.map((s) => {
    const slice = (s.value / total) * 360;
    const start = angle;
    const end = angle + slice;
    angle = end;
    const large = slice > 180 ? 1 : 0;
    const toXY = (deg) => {
      const rad = (deg * Math.PI) / 180;
      return [cx + r * Math.cos(rad), cy + r * Math.sin(rad)];
    };
    const [x1, y1] = toXY(start);
    const [x2, y2] = toXY(end);
    if (s.value === 0) return "";
    return `<path d="M${cx},${cy} L${x1.toFixed(2)},${y1.toFixed(2)} A${r},${r} 0 ${large} 1 ${x2.toFixed(2)},${y2.toFixed(2)} Z" fill="${s.color}" stroke="var(--surface)" stroke-width="2"/>`;
  }).join("");

  const legend = segments.map((s) => `
    <div class="report-legend-item">
      <span class="report-legend-swatch" style="background:${s.color}"></span>
      <span>${escapeAttr(s.label)}</span>
      <strong>${s.value}</strong>
    </div>`).join("");

  return `
    <div class="report-donut-row">
      <svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="Users by role">
        ${arcs}
        <circle cx="${cx}" cy="${cy}" r="${r * 0.55}" fill="var(--surface)" />
        <text x="${cx}" y="${cy - 4}" text-anchor="middle" class="report-donut-total">${total}</text>
        <text x="${cx}" y="${cy + 12}" text-anchor="middle" class="report-donut-caption">total users</text>
      </svg>
      <div class="report-legend">${legend}</div>
    </div>
  `;
}

// Horizontal bar chart of the 6 largest classes by enrollment count.
function renderClassEnrollmentChart(classes, enrollments) {
  const counts = classes.map((c) => ({
    label: c.name ?? c.id,
    count: enrollments.filter((e) => e.classId === c.id).length,
  })).sort((a, b) => b.count - a.count).slice(0, 6);

  if (counts.length === 0) return `<p class="empty-text">No classes yet.</p>`;

  const max = Math.max(...counts.map((c) => c.count), 1);
  const rows = counts.map((c) => `
    <div class="report-hbar-row">
      <span class="report-hbar-label" title="${escapeAttr(c.label)}">${escapeAttr(c.label)}</span>
      <div class="report-hbar-track">
        <div class="report-hbar-fill" style="width:${(c.count / max * 100).toFixed(1)}%"></div>
      </div>
      <span class="report-hbar-value">${c.count}</span>
    </div>`).join("");

  return `<div class="report-hbar-chart">${rows}</div>`;
}

function renderReport(data) {
  const { parents, teachers, principals, learners, classes, enrollments, progress } = data;
  const { enrolledLearnerIds, learnersNoClass, classesNoStudents, maxChildren, topParent } =
    computeInsights(data);

  const reportIcons = {
    parents: '<circle cx="7" cy="6" r="3" stroke="currentColor" stroke-width="1.5"/><circle cx="13" cy="6" r="3" stroke="currentColor" stroke-width="1.5"/><path d="M1 17c0-3 2.5-5 6-5M19 17c0-3-2.5-5-6-5M7 17c0-2.5 1.3-4 3-4s3 1.5 3 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    teachers: '<path d="M10 2L2 6l8 4 8-4-8-4z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M2 10l8 4 8-4M2 14l8 4 8-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    principals: '<path d="M10 3a3 3 0 100 6 3 3 0 000-6z" stroke="currentColor" stroke-width="1.5"/><path d="M4 17c0-3.3 2.7-6 6-6s6 2.7 6 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    learners: '<circle cx="10" cy="7" r="4" stroke="currentColor" stroke-width="1.5"/><path d="M3 18c0-3.3 3.1-6 7-6s7 2.7 7 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    classes: '<path d="M4 4h12a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V5a1 1 0 011-1z" stroke="currentColor" stroke-width="1.5"/><path d="M7 8h6M7 11h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    enrollments: '<path d="M10 2L3 6v8l7 4 7-4V6l-7-4z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M3 6l7 4 7-4" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>',
    progress: '<polyline points="2,14 7,9 11,12 18,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 5h3v3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
  };
  const totals = [
    ["parents", "Parents / Guardians", parents.length],
    ["teachers", "Asatidz / Teachers", teachers.length],
    ["principals", "Principals", principals.length],
    ["learners", "Learners", learners.length],
    ["classes", "Classes", classes.length],
    ["enrollments", "Enrollments", enrollments.length],
    ["progress", "Progress records", progress.length],
  ];

  const learnerNameById = new Map(learners.map((l) => [l.id, l.name]));
  const activityBadge = {
    "Parent joined": "parent",
    "Asatidz joined": "asatidz",
    "Learner added": "learner",
    "Progress recorded": "classroom",
  };
  const recentActivity = [
    ...parents.map((p) => ({ type: "Parent joined", name: p.fullName, date: p.createdAt })),
    ...teachers.map((t) => ({ type: "Asatidz joined", name: t.fullName, date: t.createdAt })),
    ...learners.map((l) => ({ type: "Learner added", name: l.name, date: l.createdAt })),
    ...progress.map((r) => ({
      type: "Progress recorded",
      name: learnerNameById.get(r.learnerId) ?? r.learnerId,
      date: r.completedAt,
    })),
  ]
    .sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""))
    .slice(0, 15);

  const generatedAt = new Date().toLocaleString(undefined, {
    year: "numeric", month: "long", day: "numeric", hour: "numeric", minute: "2-digit",
  });

  const insights = [
    { value: `${enrolledLearnerIds.size} / ${learners.length}`, label: "learners enrolled in a class" },
    { value: learnersNoClass.length, label: "learners not yet in any class" },
    { value: classesNoStudents.length, label: "classes with no students" },
    {
      value: topParent ? maxChildren : "—",
      label: topParent ? `children under ${escapeAttr(topParent.fullName)} (top parent)` : "no parents with children yet",
    },
  ];

  const weeklySignups = computeWeeklySignups(data);

  document.getElementById("report-doc").innerHTML = `
    <div class="report-header">
      <div class="report-header-badge">
        <svg width="22" height="22" viewBox="0 0 20 20" fill="none"><path d="M10 2L3 6v8l7 4 7-4V6L10 2z" stroke="white" stroke-width="1.5" stroke-linejoin="round"/><path d="M10 2v12M3 6l7 4 7-4" stroke="white" stroke-width="1.5" stroke-linejoin="round"/></svg>
      </div>
      <div class="report-header-text">
        <h1>SalamLearn</h1>
        <p class="report-subtitle">Platform Summary Report</p>
      </div>
      <p class="report-meta">Generated<br>${generatedAt}<br>by ${escapeAttr(auth.currentUser?.email ?? "admin")}</p>
    </div>

    <h2 class="report-section-title">Totals</h2>
    <div class="report-stat-grid">${totals.map(([key, label, count]) => `
      <div class="report-stat-card">
        <div class="report-stat-icon"><svg width="16" height="16" viewBox="0 0 20 20" fill="none">${reportIcons[key]}</svg></div>
        <div>
          <div class="report-stat-value">${count}</div>
          <div class="report-stat-label">${label}</div>
        </div>
      </div>`).join("")}</div>

    <h2 class="report-section-title">Insights</h2>
    <div class="report-insights">${insights.map((i) => `
      <div class="report-insight-card">
        <div class="report-insight-value">${i.value}</div>
        <div class="report-insight-label">${i.label}</div>
      </div>`).join("")}</div>

    <h2 class="report-section-title">Users by Role</h2>
    <div class="report-chart-wrap">${renderRoleDonut([
      { label: "Parents / Guardians", value: parents.length, color: "#0f6e56" },
      { label: "Asatidz / Teachers", value: teachers.length, color: "#ef9f27" },
      { label: "Principals", value: principals.length, color: "#2c2c2a" },
      { label: "Learners", value: learners.length, color: "#d85a30" },
    ])}</div>

    <h2 class="report-section-title">Weekly Growth</h2>
    <p class="report-chart-subtitle">New accounts per week, last 8 weeks</p>
    <div class="report-chart-wrap">${renderWeeklyChart(weeklySignups)}</div>

    <h2 class="report-section-title">Top Classes by Enrollment</h2>
    <div class="report-chart-wrap">${renderClassEnrollmentChart(classes, enrollments)}</div>

    <h2 class="report-section-title">Recent Activity</h2>
    <table class="report-table">
      <thead><tr><th>Type</th><th>Name</th><th>Date</th></tr></thead>
      <tbody>${
        recentActivity.length === 0
          ? `<tr><td colspan="3">No activity yet.</td></tr>`
          : recentActivity.map((i) => `<tr><td><span class="dash-badge dash-badge-${activityBadge[i.type]}">${i.type}</span></td><td>${escapeAttr(i.name)}</td><td class="dash-date">${formatDate(i.date)}</td></tr>`).join("")
      }</tbody>
    </table>

    <p class="report-footer">Generated by SalamLearn Admin Panel.</p>
  `;
}

async function loadAllData() {
  accessDenied.hidden = true;
  try {
    const [parents, teachers, principals, learners, classes, enrollments, progress, trashbin, badges, assignments] =
      await Promise.all([
        fetchAll("parents"),
        fetchAll("teachers"),
        fetchAll("principals"),
        fetchAll("learners"),
        fetchAll("classes"),
        fetchAll("enrollments"),
        fetchAll("progress"),
        fetchAll("trashbin"),
        fetchAll("badges"),
        fetchAll("assigned_modules"),
      ]);

    currentLearners = learners;
    lastParents = parents;
    hubData = { learners, progress, badges, enrollments, assignments };
    fillHubLearnerSelect();
    await assignMissingParentCodes(parents);
    const activatedIds = await activatedTeacherIds(teachers);
    const isActivated = (r) => teacherStatus(r) === "approved" && activatedIds.has(r.id);

    renderDashboard({
      parents, teachers, learners, classes, enrollments, progress,
    });
    renderReport({
      parents, teachers, principals, learners, classes, enrollments, progress,
    });

    renderTable(
      document.getElementById("table-parents"),
      [
        { label: "Name", value: (r) => r.fullName },
        { label: "Parent ID", value: (r) => r.parentCode },
        { label: "Email", value: (r) => r.email },
        { label: "Status", value: (r) => parentActivated(r) ? "Activated" : "Not activated", badge: (r) => parentActivated(r) ? "status-approved" : "status-pending" },
        { label: "Registered", value: (r) => formatDate(r.createdAt) },
      ],
      parents,
      [
        { label: "Reset Password", className: "btn-view", onClick: (row) => resetAccountPassword(row.email) },
        { label: "Remove", onClick: (row, btn) => confirmDeleteParent(row, btn) },
      ],
      [bulkRemove("parents", removeParent, " This also deletes their learners and everything tied to them.")]
    );

    renderTable(
      document.getElementById("table-teachers"),
      [
        { label: "Name", value: (r) => r.fullName },
        { label: "Employee ID", value: (r) => r.employeeId },
        { label: "School", value: (r) => r.school },
        { label: "Email", value: (r) => r.email },
        { label: "Status", value: (r) => isActivated(r) ? "Activated" : "Not activated", badge: (r) => isActivated(r) ? "status-approved" : "status-pending" },
        { label: "Registered", value: (r) => formatDate(r.createdAt) },
      ],
      [...teachers].sort((a, b) => (teacherStatus(b) === "pending") - (teacherStatus(a) === "pending")),
      [
        { label: "Activate", className: "btn-primary btn-small", show: (r) => teacherStatus(r) !== "approved", onClick: (row, btn) => setTeacherStatus(row, "approved", btn) },
        { label: "Reset Password", className: "btn-view", onClick: (row) => resetAccountPassword(row.email, row.email && teacherAuthEmail(row.email)) },
        { label: "Remove", onClick: (row, btn) => confirmDeleteTeacher(row, btn) },
      ],
      [
        {
          label: "Activate selected",
          className: "btn-primary btn-small",
          run: (rows) => runForRows(
            rows.filter((r) => teacherStatus(r) !== "approved"),
            (r) => updateDoc(doc(db, "teachers", r.id), { verificationStatus: "approved" }),
            "Activating teachers...", "Selected teachers activated", "Failed to activate teacher"
          ),
        },
        bulkRemove("teachers", removeTeacher, " This also deletes their classes and related enrollments/assignments."),
      ]
    );

    renderTable(
      document.getElementById("table-principals"),
      [
        { label: "Name", value: (r) => r.fullName },
        { label: "Email", value: (r) => r.email },
        { label: "Registered", value: (r) => formatDate(r.createdAt) },
      ],
      principals,
      [
        { label: "Reset Password", className: "btn-view", onClick: (row) => resetAccountPassword(row.email) },
        { label: "Remove", onClick: (row, btn) => confirmDeletePrincipal(row, btn) },
      ]
    );

    const assignIdsBtn = document.getElementById("assign-employee-ids");
    assignIdsBtn.hidden = !teachers.some((t) => !t.employeeId && t.email);
    assignIdsBtn.onclick = () => assignMissingEmployeeIds(teachers);

    const parentNameById = new Map(parents.map((p) => [p.id, p.fullName]));
    renderTable(
      document.getElementById("table-learners"),
      [
        { label: "Name", value: (r) => r.name },
        { label: "Student ID", value: (r) => studentIdFor(r.id) },
        { label: "Age", value: (r) => r.age },
        { label: "Grade", value: (r) => r.gradeLevel },
        { label: "Parent", value: (r) => parentNameById.get(r.parentId) ?? r.parentId },
        { label: "Added", value: (r) => formatDate(r.createdAt) },
      ],
      learners,
      { label: "Remove", onClick: (row, btn) => confirmDeleteLearner(row, btn) },
      [bulkRemove("learners", removeLearner, " This also deletes their enrollments, progress, and assignments.")]
    );

    const teacherNameById = new Map(teachers.map((t) => [t.id, t.fullName]));
    const enrollCountByClass = new Map();
    enrollments.forEach((e) => {
      enrollCountByClass.set(e.classId, (enrollCountByClass.get(e.classId) ?? 0) + 1);
    });
    renderTable(
      document.getElementById("table-classes"),
      [
        { label: "Class", value: (r) => r.name },
        { label: "Teacher", value: (r) => teacherNameById.get(r.teacherId) ?? r.teacherId },
        { label: "Invitation code", value: (r) => r.invitationCode },
        { label: "Enrolled", value: (r) => enrollCountByClass.get(r.id) ?? 0 },
        { label: "Created", value: (r) => formatDate(r.createdAt) },
      ],
      classes,
      [
        {
          label: "View Students",
          className: "btn-view",
          onClick: (row) => showClassStudents(row, enrollments, learners)
        },
        {
          label: "Remove",
          className: "btn-danger",
          onClick: (row, btn) => confirmDeleteClass(row, btn)
        }
      ],
      [bulkRemove("classes", removeClass, " This also deletes their enrollments and assignments.")]
    );

    const learnerNameById = new Map(learners.map((l) => [l.id, l.name]));

    // Group progress by learner for the "Progress by Learner" view
    const progressByLearner = new Map();
    progress.forEach((r) => {
      const lid = r.learnerId;
      if (!progressByLearner.has(lid)) {
        progressByLearner.set(lid, { learnerId: lid, classroom: [], home: [] });
      }
      const entry = progressByLearner.get(lid);
      if (r.assignedByTeacher) {
        entry.classroom.push(r);
      } else {
        entry.home.push(r);
      }
    });
    const progressSummary = [...progressByLearner.values()]
      .map((p) => ({
        learnerId: p.learnerId,
        learnerName: learnerNameById.get(p.learnerId) ?? p.learnerId,
        classroomCount: p.classroom.length,
        homeCount: p.home.length,
        totalCount: p.classroom.length + p.home.length,
        lastActivity: [...p.classroom, ...p.home]
          .sort((a, b) => new Date(b.completedAt ?? 0) - new Date(a.completedAt ?? 0))
          .at(0)?.completedAt,
        classroom: p.classroom,
        home: p.home,
      }))
      .sort((a, b) => (b.lastActivity ?? "").localeCompare(a.lastActivity ?? ""));
    renderTable(
      document.getElementById("table-progress"),
      [
        { label: "Learner", value: (r) => r.learnerName },
        { label: "Classroom", value: (r) => r.classroomCount },
        { label: "Home", value: (r) => r.homeCount },
        { label: "Total", value: (r) => r.totalCount },
        { label: "Last Activity", value: (r) => formatDate(r.lastActivity) },
      ],
      progressSummary,
      [
        { label: "View Progress", className: "btn-view", onClick: (row) => showLearnerProgress(row) },
        { label: "View Hub", className: "btn-view", onClick: (row) => openLearnerHub(row.learnerId) },
      ]
    );

    const trashbinUsers = trashbin.filter((r) => r.deletedBy !== "admin");
    const trashbinAdmins = trashbin.filter((r) => r.deletedBy === "admin");

    renderTable(
      document.getElementById("table-trashbin-users"),
      [
        { label: "Type", value: (r) => trashTypeLabel(r.collection) },
        { label: "Original ID", value: (r) => r.originalId },
        { label: "Details", value: (r) => getTrashDetails(r) },
        { label: "Deleted At", value: (r) => formatDate(r.deletedAt) },
      ],
      trashbinUsers,
      [
        {
          label: "Restore",
          className: "btn-view",
          onClick: (row, btn) => restoreTrashItem(row, btn)
        },
        {
          label: "Delete Permanently",
          className: "btn-danger",
          onClick: (row, btn) => deleteTrashItemPermanently(row, btn)
        }
      ],
      [
        {
          label: "Restore selected",
          run: (rows) => runForRows(rows, restoreTrashEntry, "Restoring items...", `${rows.length} item(s) restored`, "Failed to restore item"),
        },
        {
          label: "Delete selected permanently",
          className: "btn-danger",
          run: async (rows) => {
            if (!window.confirm(`Permanently delete ${rows.length} item(s) from the trashbin? This cannot be undone.`)) return;
            await runForRows(rows, deleteTrashEntry, "Deleting items permanently...", `${rows.length} item(s) permanently deleted`, "Failed to delete item");
          },
        },
      ]
    );

    renderGroupedAdminTrash(
      document.getElementById("table-trashbin-admins"),
      trashbinAdmins
    );

    populateParentPicker(parents);
  } catch (err) {
    if (err.code === "permission-denied") {
      document.getElementById("my-uid").textContent = auth.currentUser?.uid ?? "(unknown)";
      accessDenied.hidden = false;
      document.getElementById("stat-grid").innerHTML = "";
      document.querySelectorAll(".tab-panel table").forEach((t) => (t.innerHTML = ""));
    } else {
      console.error(err);
      showToast("Couldn't load data. Check your connection and refresh.", "error");
    }
  }
}

function populateParentPicker(parents) {
  const select = document.querySelector('#form-learner select[name="parentId"]');
  if (!select) return;
  select.innerHTML = parents
    .map((p) => `<option value="${p.id}">${escapeAttr(p.fullName)} (${escapeAttr(p.email ?? "no email")})</option>`)
    .join("");
}

function escapeAttr(value) {
  return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[ch]);
}

const trashTypeLabels = {
  parents: "Parent",
  teachers: "Teacher",
  principals: "Principal",
  learners: "Learner",
  classes: "Class",
  enrollments: "Enrollment",
  progress: "Progress",
  assigned_modules: "Assignment",
  custom_lessons: "Lesson",
  consents: "Consent",
};
function trashTypeLabel(collectionName) {
  return trashTypeLabels[collectionName] ?? collectionName ?? "";
}

// ---- Add-user forms (show/hide) ----
document.querySelectorAll("[data-open-form]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const form = document.getElementById(`form-${btn.dataset.openForm}`);
    form.hidden = false;
    form.querySelector("input, select").focus();
  });
});
document.querySelectorAll("[data-cancel-form]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const form = document.getElementById(`form-${btn.dataset.cancelForm}`);
    form.hidden = true;
    form.reset();
    form.querySelector(".form-error").hidden = true;
  });
});

// Confirm-password check + show-password toggle on the add-account forms.
document.querySelectorAll(".add-form").forEach((form) => {
  const pw = form.querySelector('input[name="password"]');
  const confirm = form.querySelector('input[name="confirmPassword"]');
  if (!pw || !confirm) return;
  const check = () =>
    confirm.setCustomValidity(confirm.value === pw.value ? "" : "Passwords don't match.");
  pw.addEventListener("input", check);
  confirm.addEventListener("input", check);
  form.querySelector("[data-show-password]").addEventListener("change", (e) => {
    pw.type = confirm.type = e.target.checked ? "text" : "password";
  });
  form.addEventListener("reset", () => {
    pw.type = confirm.type = "password";
    confirm.setCustomValidity("");
  });
});

// Firestore keeps a single `fullName` (see isValidNewParent/isValidNewTeacher
// in firestore.rules), so the separate name inputs are joined here.
function fullNameFrom(data) {
  const first = data.get("firstName").trim();
  const last = data.get("lastName").trim();
  if (!first || !last) return null;
  return [first, data.get("middleName").trim(), last].filter(Boolean).join(" ");
}

function showFormError(form, message) {
  const errorEl = form.querySelector(".form-error");
  errorEl.textContent = message;
  errorEl.hidden = false;
}

async function hasInternetForAccountCreation() {
  if (!navigator.onLine) return false;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    // Check the service that stores these accounts. A local network or an
    // offline Firestore cache alone must not authorize a new account.
    await fetch(`https://firestore.googleapis.com/?t=${Date.now()}`, {
      mode: "no-cors",
      cache: "no-store",
      signal: controller.signal,
    });
    return true;
  } catch (_) {
    return false;
  } finally {
    clearTimeout(timeout);
  }
}

async function requireInternetForAccountCreation(form) {
  if (await hasInternetForAccountCreation()) return true;
  showFormError(form, "Connect to the internet before creating an account or learner profile.");
  return false;
}

// A normal `createUserWithEmailAndPassword(auth, ...)` call would sign the
// admin's own session out and into the new account — the client SDK has no
// "create another user without switching sessions" mode. Working around it
// with a second, throwaway Firebase App instance (same project) keeps the
// admin's own `auth` session on this page untouched; the throwaway app is
// torn down right after we have the new user's uid.
//
// `writeProfile(uid)` saves the Firestore doc while the new user is still
// signed in on the worker app. If it throws, the new Auth user is deleted
// again, so a failed save can't leave the email stuck as "already in use"
// with no profile behind it.
async function createAuthAccountWithoutSignOut(email, password, writeProfile, { sendActivationEmail = false } = {}) {
  const workerApp = initializeApp(firebaseConfig, `admin-worker-${Date.now()}`);
  try {
    const workerAuth = getAuth(workerApp);
    const credential = await createUserWithEmailAndPassword(workerAuth, email, password);
    try {
      await writeProfile(credential.user.uid);
    } catch (err) {
      await credential.user.delete().catch((e) => console.error("Rollback of new account failed:", e));
      throw err;
    }
    // Parents have no in-app activation, so they get Firebase's password-reset
    // email to set their own password. Teachers don't: they request that same
    // email themselves from the app's "Activate my account" screen.
    if (sendActivationEmail) {
      try {
        await sendPasswordResetEmail(workerAuth, email);
      } catch (err) {
        console.error("Activation email failed to send:", err);
      }
    }
    return credential.user.uid;
  } finally {
    await deleteApp(workerApp);
  }
}

// Teachers who finished activation in the app (`activatedTeachers/{email}`,
// keyed by the plain or `+teacher` login email — see the app's
// `_markTeacherActivated`). A Set, not a row field, so it never leaks into
// trashbin copies of the teacher doc.
async function activatedTeacherIds(teachers) {
  const ids = new Set();
  await Promise.all(teachers.filter((t) => t.email).map(async (t) => {
    for (const key of new Set([t.email.trim().toLowerCase(), teacherAuthEmail(t.email)])) {
      try {
        if ((await getDoc(doc(db, "activatedTeachers", key))).exists()) {
          ids.add(t.id);
          return;
        }
      } catch (err) {
        console.error(`Activation check for ${t.email} failed:`, err);
      }
    }
  }));
  return ids;
}

// Teacher logins on Gmail live under a "+teacher" alias so a parent and a
// teacher can share one Gmail with different passwords (Firebase Auth allows
// one login per email). Gmail delivers the alias to the same inbox. Must match
// FirebaseAuthGateway.teacherAuthEmail in the Flutter app.
function teacherAuthEmail(email) {
  const normalized = email.trim().toLowerCase();
  const at = normalized.lastIndexOf("@");
  if (at <= 0) return normalized;
  const local = normalized.slice(0, at);
  const domain = normalized.slice(at + 1);
  if (domain !== "gmail.com" && domain !== "googlemail.com") return normalized;
  if (local.endsWith("+teacher")) return normalized;
  return `${local}+teacher@${domain}`;
}

// Teacher Employee ID: "YYYY-NNNNNN" (year + 6 random digits). Random, not
// sequential, because `teacherIds/{id}` is readable before sign-in (the app
// resolves ID -> email for activation/login) — sequential IDs would let
// anyone walk the whole list of teacher emails.
function generateEmployeeId() {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1000000;
  return `${new Date().getFullYear()}-${String(n).padStart(6, "0")}`;
}

// Claims a fresh ID in `teacherIds` (retrying on the rare collision) and
// returns it. Must match the app's `FirestoreMirror.emailForEmployeeId`.
async function reserveEmployeeId(email, teacherId) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const id = generateEmployeeId();
    const ref = doc(db, "teacherIds", id);
    const claimed = await runTransaction(db, async (tx) => {
      if ((await tx.get(ref)).exists()) return false;
      tx.set(ref, { email, teacherId });
      return true;
    });
    if (claimed) return id;
  }
  throw new Error("Could not generate a unique Employee ID");
}

// Parent ID: admin-web only (never shown in the app), so no public lookup
// collection — uniqueness is checked against the loaded parents list.
function newParentCode(parents) {
  const taken = new Set(parents.map((p) => p.parentCode));
  let code;
  do code = generateEmployeeId(); while (taken.has(code));
  return code;
}

// Silently gives every parent without a Parent ID one (app-registered
// parents can't set their own — see firestore.rules).
async function assignMissingParentCodes(parents) {
  for (const p of parents.filter((p) => !p.parentCode)) {
    const code = newParentCode(parents);
    try {
      await updateDoc(doc(db, "parents", p.id), { parentCode: code });
      p.parentCode = code;
    } catch (err) {
      console.error(`Parent ID for ${p.email} failed:`, err);
    }
  }
}

async function assignMissingEmployeeIds(teachers) {
  const missing = teachers.filter((t) => !t.employeeId && t.email);
  if (missing.length === 0) return;
  if (!window.confirm(`Generate Employee IDs for ${missing.length} teacher(s) without one?`)) return;
  showLoading("Assigning Employee IDs...");
  let failed = 0;
  for (const t of missing) {
    let id = null;
    try {
      id = await reserveEmployeeId(t.email, t.id);
      await updateDoc(doc(db, "teachers", t.id), { employeeId: id });
    } catch (err) {
      console.error(`Employee ID for ${t.email} failed:`, err);
      if (id) await deleteDoc(doc(db, "teacherIds", id)).catch(() => {});
      failed++;
    }
  }
  await loadAllData();
  hideLoading();
  showToast(
    failed ? `${failed} of ${missing.length} Employee IDs failed — see console` : `Assigned ${missing.length} Employee ID(s)`,
    failed ? "error" : "success"
  );
}

function resetAccountPassword(email, authEmail = email) {
  if (!email) {
    showToast("No email on file — cannot send reset link.", "error");
    return;
  }
  if (!window.confirm(`Send a password-reset email to ${email}?`)) return;
  sendPasswordResetEmail(auth, authEmail)
    .then(() => showToast(`Password-reset email sent to ${email}`, "success"))
    .catch((err) => {
      console.error(err);
      showToast(`Failed to send reset email: ${err.message}`, "error");
    });
}

document.getElementById("form-parent").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  const fullName = fullNameFrom(data);
  if (!fullName) {
    showFormError(form, "First and last name are required.");
    return;
  }
  submitBtn.disabled = true;
  showLoading("Checking connection...");
  if (!await requireInternetForAccountCreation(form)) {
    hideLoading();
    submitBtn.disabled = false;
    return;
  }
  showLoading("Creating parent account...");
  try {
    const email = data.get("email").trim().toLowerCase();
    await createAuthAccountWithoutSignOut(email, data.get("password"), (firebaseUid) =>
      setDoc(doc(collection(db, "parents")), {
        fullName,
        email,
        parentCode: newParentCode(lastParents),
        createdAt: new Date().toISOString(),
        firebaseUid,
      }),
      { sendActivationEmail: true }
    );
    form.hidden = true;
    form.reset();
    await loadAllData();
    hideLoading();
    showToast("Parent created successfully", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showFormError(form, describeAuthError(err) !== "Sign-in failed. Please try again." ? describeAuthError(err) : "Could not create parent — see console for details.");
    showToast("Failed to create parent", "error");
  } finally {
    submitBtn.disabled = false;
  }
});

// A parent counts as activated once they've signed in to the app: the app's
// sync (FirestoreMirror.pushParent) always writes `mobileNumber`, even as
// null, while admin-created parent docs never have it.
// ponytail: inferred from that field; add an explicit flag if the admin form
// ever starts writing mobileNumber.
function parentActivated(row) {
  return "mobileNumber" in row;
}

function teacherStatus(row) {
  return row.verificationStatus ?? "approved";
}

// Teacher activation (SL-TEA/ADM-02): only admins may change this field —
// firestore.rules rejects it from the teacher's own app session.
async function setTeacherStatus(row, status, btn) {
  if (teacherStatus(row) === status) return;
  btn.disabled = true;
  showLoading("Updating teacher status...");
  try {
    await updateDoc(doc(db, "teachers", row.id), { verificationStatus: status });
    await loadAllData();
    hideLoading();
    showToast("Teacher activated", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to update teacher status", "error");
  } finally {
    btn.disabled = false;
  }
}

document.getElementById("form-teacher").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  const fullName = fullNameFrom(data);
  if (!fullName) {
    showFormError(form, "First and last name are required.");
    return;
  }
  submitBtn.disabled = true;
  showLoading("Checking connection...");
  if (!await requireInternetForAccountCreation(form)) {
    hideLoading();
    submitBtn.disabled = false;
    return;
  }
  showLoading("Creating teacher account...");
  try {
    const email = data.get("email").trim().toLowerCase();
    const school = data.get("school").trim() || null;
    let employeeId = null;
    // Random password nobody knows — the teacher can only get in by setting
    // their own via the app's activation email.
    const password = crypto.randomUUID();
    await createAuthAccountWithoutSignOut(teacherAuthEmail(email), password, async (firebaseUid) => {
      const teacherRef = doc(collection(db, "teachers"));
      employeeId = await reserveEmployeeId(email, teacherRef.id);
      try {
        await setDoc(teacherRef, {
          fullName,
          school,
          email,
          createdAt: new Date().toISOString(),
          firebaseUid,
          verificationStatus: "approved",
          employeeId,
        });
      } catch (err) {
        await deleteDoc(doc(db, "teacherIds", employeeId)).catch(() => {});
        throw err;
      }
    });
    form.hidden = true;
    form.reset();
    await loadAllData();
    hideLoading();
    window.alert(`Teacher created.

Employee ID: ${employeeId}

Give this ID to the teacher — they use it to activate their account and sign in.`);
  } catch (err) {
    console.error(err);
    hideLoading();
    showFormError(form, describeAuthError(err) !== "Sign-in failed. Please try again." ? describeAuthError(err) : "Could not create teacher — see console for details.");
    showToast("Failed to create teacher", "error");
  } finally {
    submitBtn.disabled = false;
  }
});

document.getElementById("form-principal").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  submitBtn.disabled = true;
  showLoading("Creating principal account...");
  try {
    const email = data.get("email").trim().toLowerCase();
    // Unlike parents/teachers (random doc id), a principal's doc id is set
    // equal to their own Firebase Auth uid — see firestore.rules' PRINCIPAL
    // MONITORING note for why: it's what lets a principal prove "this is my
    // own doc" with a plain get() instead of an unprovable query.
    await createAuthAccountWithoutSignOut(email, data.get("password"), (firebaseUid) =>
      setDoc(doc(db, "principals", firebaseUid), {
        fullName: data.get("fullName").trim(),
        email,
        firebaseUid,
        createdAt: new Date().toISOString(),
      })
    );
    form.hidden = true;
    form.reset();
    await loadAllData();
    hideLoading();
    showToast("Principal created successfully", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showFormError(form, describeAuthError(err) !== "Sign-in failed. Please try again." ? describeAuthError(err) : "Could not create principal — see console for details.");
    showToast("Failed to create principal", "error");
  } finally {
    submitBtn.disabled = false;
  }
});

const learnerAgeSelect = document.getElementById("learner-age-select");
const learnerAgeCustomWrap = document.getElementById("learner-age-custom-wrap");
const learnerAgeCustomInput = document.getElementById("learner-age-custom");
learnerAgeSelect.addEventListener("change", () => {
  learnerAgeCustomWrap.hidden = learnerAgeSelect.value !== "custom";
});

document.getElementById("form-learner").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  if (!data.get("parentId")) {
    showFormError(form, "Add a parent first — a learner must belong to one.");
    return;
  }
  const name = fullNameFrom(data);
  if (!name) {
    showFormError(form, "First and last name are required.");
    return;
  }
  const age = data.get("age") === "custom" ? Number(data.get("ageCustom")) : Number(data.get("age"));
  if (!age || age < 1) {
    showFormError(form, "Please enter a valid age.");
    return;
  }
  const username = (data.get("username") || "").trim();
  if (!username) {
    showFormError(form, "Username is required.");
    return;
  }
  const gradeLevel = (data.get("gradeLevel") || "").trim() || "Grade 1";

  // Check for duplicate username
  const usernameNorm = username.toLowerCase();
  if (currentLearners.some((l) => (l.username || "").toLowerCase() === usernameNorm)) {
    showFormError(form, `Username "${username}" is already taken.`);
    return;
  }

  // Check for duplicate student (same Name, Age, and Grade level)
  const nameNorm = name.toLowerCase().replace(/\s+/g, " ").trim();
  const gradeNorm = gradeLevel.toLowerCase().replace(/\s+/g, " ").trim();
  const duplicate = currentLearners.find((l) => {
    const lNameNorm = (l.name || "").toLowerCase().replace(/\s+/g, " ").trim();
    const lGradeNorm = (l.gradeLevel || "Grade 1").toLowerCase().replace(/\s+/g, " ").trim();
    return lNameNorm === nameNorm && Number(l.age) === age && lGradeNorm === gradeNorm;
  });
  if (duplicate) {
    showFormError(form, `A student named "${name}" with age ${age} and ${gradeLevel} already exists.`);
    return;
  }
  submitBtn.disabled = true;
  showLoading("Checking connection...");
  if (!await requireInternetForAccountCreation(form)) {
    hideLoading();
    submitBtn.disabled = false;
    return;
  }
  showLoading("Creating learner profile...");
  try {
    await writeBatch(db)
      .set(doc(collection(db, "learners")), {
        parentId: data.get("parentId"),
        name,
        username: data.get("username").trim(),
        age,
        avatar: data.get("avatar"),
        gradeLevel: data.get("gradeLevel").trim() || "Grade 1",
        createdAt: new Date().toISOString(),
      })
      .commit();
    form.hidden = true;
    form.reset();
    document.querySelector('#form-learner input[name="avatar"][value="boy_mascot"]').checked = true;
    learnerAgeCustomWrap.hidden = true;
    await loadAllData();
    hideLoading();
    showToast("Learner created successfully", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showFormError(form, "Could not create learner — see console for details.");
    showToast("Failed to create learner", "error");
  } finally {
    submitBtn.disabled = false;
  }
});

// ---- Cascade delete with Trashbin Archiving ----
function archiveDocToTrashbinBatch(batch, collectionName, docId, data, batchId) {
  const trashId = `${collectionName}_${docId}`;
  const trashRef = doc(db, "trashbin", trashId);
  const entry = {
    collection: collectionName,
    originalId: docId,
    data: data,
    deletedAt: new Date().toISOString(),
    deletedBy: "admin",
  };
  if (batchId) entry.batchId = batchId;
  batch.set(trashRef, entry);
}

async function archiveAndDeleteDocsWhere(batch, collectionName, field, value, batchId) {
  const snap = await getDocs(query(collection(db, collectionName), where(field, "==", value)));
  snap.docs.forEach((d) => {
    archiveDocToTrashbinBatch(batch, collectionName, d.id, d.data(), batchId);
    batch.delete(d.ref);
  });
}

// Runs `fn` on each row (one batch per row), then reloads once. Shared by
// the single-row buttons and the bulk-selection bar.
async function runForRows(rows, fn, loadingMsg, okMsg, failMsg) {
  showLoading(loadingMsg);
  let failed = 0;
  for (const row of rows) {
    try {
      await fn(row);
    } catch (err) {
      console.error(err);
      failed++;
    }
  }
  await loadAllData();
  hideLoading();
  if (!failed) showToast(okMsg, "success");
  else showToast(rows.length === 1 ? failMsg : `${failed} of ${rows.length} failed — see console`, "error");
}

async function removeLearner(row) {
  const batchId = `cascade_${Date.now()}_${row.id}`;
  const batch = writeBatch(db);
  const learnerId = row.id;
  await archiveAndDeleteDocsWhere(batch, "enrollments", "learnerId", learnerId, batchId);
  await archiveAndDeleteDocsWhere(batch, "progress", "learnerId", learnerId, batchId);
  await archiveAndDeleteDocsWhere(batch, "assigned_modules", "learnerId", learnerId, batchId);
  const { id, ...learnerData } = row;
  archiveDocToTrashbinBatch(batch, "learners", learnerId, learnerData, batchId);
  batch.delete(doc(db, "learners", learnerId));
  await batch.commit();
}

async function removeParent(row) {
  const batchId = `cascade_${Date.now()}_${row.id}`;
  const learners = await getDocs(query(collection(db, "learners"), where("parentId", "==", row.id)));
  const batch = writeBatch(db);
  for (const learnerDoc of learners.docs) {
    const learnerId = learnerDoc.id;
    await archiveAndDeleteDocsWhere(batch, "enrollments", "learnerId", learnerId, batchId);
    await archiveAndDeleteDocsWhere(batch, "progress", "learnerId", learnerId, batchId);
    await archiveAndDeleteDocsWhere(batch, "assigned_modules", "learnerId", learnerId, batchId);
    archiveDocToTrashbinBatch(batch, "learners", learnerId, learnerDoc.data(), batchId);
    batch.delete(doc(db, "learners", learnerId));
  }
  const { id, ...parentData } = row;
  archiveDocToTrashbinBatch(batch, "parents", row.id, parentData, batchId);
  batch.delete(doc(db, "parents", row.id));
  await batch.commit();
}

async function removeClass(row) {
  const batchId = `cascade_${Date.now()}_${row.id}`;
  const batch = writeBatch(db);
  const classId = row.id;
  await archiveAndDeleteDocsWhere(batch, "enrollments", "classId", classId, batchId);
  await archiveAndDeleteDocsWhere(batch, "assigned_modules", "classId", classId, batchId);
  await archiveAndDeleteDocsWhere(batch, "custom_lessons", "classId", classId, batchId);
  const { id, ...classData } = row;
  archiveDocToTrashbinBatch(batch, "classes", classId, classData, batchId);
  batch.delete(doc(db, "classes", classId));
  await batch.commit();
}

async function removeTeacher(row) {
  const batchId = `cascade_${Date.now()}_${row.id}`;
  const classes = await getDocs(query(collection(db, "classes"), where("teacherId", "==", row.id)));
  const batch = writeBatch(db);
  for (const classDoc of classes.docs) {
    const classId = classDoc.id;
    await archiveAndDeleteDocsWhere(batch, "enrollments", "classId", classId, batchId);
    await archiveAndDeleteDocsWhere(batch, "assigned_modules", "classId", classId, batchId);
    await archiveAndDeleteDocsWhere(batch, "custom_lessons", "classId", classId, batchId);
    archiveDocToTrashbinBatch(batch, "classes", classId, classDoc.data(), batchId);
    batch.delete(doc(db, "classes", classId));
  }
  const { id, ...teacherData } = row;
  archiveDocToTrashbinBatch(batch, "teachers", row.id, teacherData, batchId);
  batch.delete(doc(db, "teachers", row.id));
  if (row.email) {
    batch.delete(doc(db, "activatedTeachers", row.email.toLowerCase()));
    batch.delete(doc(db, "activatedTeachers", teacherAuthEmail(row.email)));
  }
  if (row.employeeId) batch.delete(doc(db, "teacherIds", row.employeeId));
  await batch.commit();
}

async function removePrincipal(row) {
  const batch = writeBatch(db);
  const { id, ...principalData } = row;
  archiveDocToTrashbinBatch(batch, "principals", row.id, principalData, null);
  batch.delete(doc(db, "principals", row.id));
  await batch.commit();
}

async function confirmDeleteLearner(row) {
  if (!window.confirm(`Remove learner "${row.name}"? This deletes their cloud record, enrollments, progress, and assignments. This will be moved to the trashbin.`)) return;
  await runForRows([row], removeLearner, "Removing learner and related data...", "Learner removed and moved to trashbin", "Failed to remove learner");
}

async function confirmDeleteParent(row) {
  if (!window.confirm(`Remove parent "${row.fullName}"? This also deletes their learners and everything tied to those learners. This will be moved to the trashbin.`)) return;
  await runForRows([row], removeParent, "Removing parent and all related data...", "Parent and all related data moved to trashbin", "Failed to remove parent");
}

async function confirmDeleteClass(row) {
  if (!window.confirm(`Remove class "${row.name}"? This also deletes its enrollments and assignments. This will be moved to the trashbin.`)) return;
  await runForRows([row], removeClass, "Removing class and related data...", "Class removed and moved to trashbin", "Failed to remove class");
}

async function confirmDeleteTeacher(row) {
  if (!window.confirm(`Remove teacher "${row.fullName}"? This also deletes their classes and related enrollments/assignments. This will be moved to the trashbin.`)) return;
  await runForRows([row], removeTeacher, "Removing teacher and all related data...", "Teacher and all related data moved to trashbin", "Failed to remove teacher");
}

async function confirmDeletePrincipal(row) {
  if (!window.confirm(`Remove principal "${row.fullName}"? This will be moved to the trashbin.`)) return;
  await runForRows([row], removePrincipal, "Removing principal...", "Principal removed and moved to trashbin", "Failed to remove principal");
}

// "Remove selected" for the bulk-selection bar — `what` is the plural noun
// for the confirm ("parents"), `extra` the cascade warning.
function bulkRemove(what, remover, extra = "") {
  return {
    label: "Remove selected",
    className: "btn-danger",
    run: async (rows) => {
      if (!window.confirm(`Remove ${rows.length} ${what}?${extra} They will be moved to the trashbin.`)) return;
      await runForRows(rows, remover, `Removing ${rows.length} ${what}...`, `${rows.length} ${what} moved to trashbin`, `Failed to remove ${what}`);
    },
  };
}


// ---- Trashbin Recovery Operations ----
function getTrashDetails(row) {
  const d = row.data || {};
  switch (row.collection) {
    case "parents":
    case "teachers":
    case "principals":
      return `${d.fullName || ""} (${d.email || ""})`;
    case "learners":
      return `${d.name || ""} (Age ${d.age || ""})`;
    case "classes":
      return `${d.name || ""} (Code: ${d.invitationCode || ""})`;
    case "enrollments":
      return `Class ID: ${d.classId || ""}`;
    case "progress":
      return `Module: ${d.moduleId || ""} (${d.score ?? "no score"})`;
    case "assigned_modules":
      return `Module: ${d.moduleId || ""}`;
    case "custom_lessons":
      return `Lesson: ${d.title || ""}`;
    default:
      return JSON.stringify(d);
  }
}

function buildTrashTree(group) {
  const rootIdx = ["parents", "teachers", "classes", "learners"]
    .map((c) => group.findIndex((e) => e.collection === c))
    .find((i) => i !== -1);
  if (rootIdx === undefined) return { entry: group[0], children: [] };

  const root = group[rootIdx];
  const rest = group.filter((_, i) => i !== rootIdx);
  const children = [];

  // Level-1 children: learners or classes directly under the root
  if (root.collection === "parents") {
    rest.forEach((e) => {
      if (e.collection === "learners" && e.data && e.data.parentId === root.originalId) {
        children.push(buildLearnerNode(e, rest));
      }
    });
  } else if (root.collection === "teachers") {
    rest.forEach((e) => {
      if (e.collection === "classes" && e.data && e.data.teacherId === root.originalId) {
        children.push(buildClassNode(e, rest));
      }
    });
  } else if (root.collection === "classes") {
    rest.forEach((e) => {
      if (e.collection !== "parents" && e.collection !== "teachers" && e.collection !== "learners" &&
          e.data && e.data.classId === root.originalId) {
        children.push({ entry: e, children: [] });
      }
    });
  } else if (root.collection === "learners") {
    rest.forEach((e) => {
      if (e.collection !== "parents" && e.collection !== "teachers" && e.collection !== "classes" &&
          e.collection !== "learners" && e.data && e.data.learnerId === root.originalId) {
        children.push({ entry: e, children: [] });
      }
    });
  }

  return { entry: root, children };
}

function buildLearnerNode(learner, all) {
  const kids = [];
  all.forEach((e) => {
    if (e.collection !== "parents" && e.collection !== "teachers" &&
        e.collection !== "learners" && e.collection !== "classes" &&
        e.data && e.data.learnerId === learner.originalId) {
      kids.push({ entry: e, children: [] });
    }
  });
  return { entry: learner, children: kids };
}

function buildClassNode(cls, all) {
  const kids = [];
  all.forEach((e) => {
    if (e.collection !== "parents" && e.collection !== "teachers" &&
        e.collection !== "learners" && e.collection !== "classes" &&
        e.data && e.data.classId === cls.originalId) {
      kids.push({ entry: e, children: [] });
    }
  });
  return { entry: cls, children: kids };
}

async function restoreTrashEntry(row) {
  const batch = writeBatch(db);
  batch.set(doc(db, row.collection, row.originalId), row.data);
  restoreEmployeeIdLookup(batch, row);
  batch.delete(doc(db, "trashbin", row.id));
  await batch.commit();
}

const deleteTrashEntry = (row) => deleteDoc(doc(db, "trashbin", row.id));

async function restoreTrashItem(row) {
  await runForRows([row], restoreTrashEntry, "Restoring item...", "Item restored successfully", "Failed to restore item");
}

async function deleteTrashItemPermanently(row) {
  if (!window.confirm("Permanently delete this item from the trashbin? This cannot be undone.")) return;
  await runForRows([row], deleteTrashEntry, "Deleting item permanently...", "Item permanently deleted", "Failed to delete item");
}


// ---- Hierarchical Admin Trashbin (cascade-delete tree) ----

function findParentForLearnerRef(parentMap, learnerId) {
  for (const [, info] of parentMap) {
    if (info.group.some((e) => e.collection === "learners" && e.originalId === learnerId)) {
      return info;
    }
  }
  return null;
}

function renderGroupedAdminTrash(tableEl, entries) {
  const batchGroups = new Map();
  const singles = [];

  entries.forEach((entry) => {
    if (entry.batchId) {
      if (!batchGroups.has(entry.batchId)) {
        batchGroups.set(entry.batchId, []);
      }
      batchGroups.get(entry.batchId).push(entry);
    } else {
      singles.push(entry);
    }
  });

  const hasGroups = batchGroups.size > 0;

  if (entries.length === 0) {
    tableEl.innerHTML = `
      <thead><tr><th></th><th>Type</th><th>Details</th><th>Deleted At</th><th>Actions</th></tr></thead>
      <tbody><tr class="empty-row"><td colspan="5">No records yet.</td></tr></tbody>
    `;
    return;
  }

  const head = `<tr><th></th><th>Type</th><th>Details</th><th>Deleted At</th><th>Actions</th></tr>`;
  tableEl.innerHTML = `<thead>${head}</thead><tbody></tbody>`;
  const tbody = tableEl.querySelector("tbody");

  // First pass: render batch groups that have a root entry (parent/teacher/class)
  const renderedBatchIds = new Set();
  const parentMap = new Map(); // parentOriginalId -> { batchId, group }

  for (const [batchId, group] of batchGroups) {
    const hasRoot = group.some((e) => e.collection === "parents" || e.collection === "teachers" || e.collection === "classes");
    if (hasRoot) {
      const tree = buildTrashTree(group);
      renderTreeRow(tbody, tree, batchId, 0, true);
      renderedBatchIds.add(batchId);
    }
    group.forEach((e) => {
      if (e.collection === "parents") parentMap.set(e.originalId, { batchId, group });
    });
  }

  // Second pass: attach orphaned learners (from unrendered batches or singles)
  // whose parent is already in a rendered tree.
  const orphanedEntries = [];
  const orphanedBatchIds = new Set();
  for (const [batchId, group] of batchGroups) {
    if (renderedBatchIds.has(batchId)) continue;
    const orphansHere = group.some(
      (e) => e.collection === "learners" && e.data && parentMap.has(e.data.parentId)
    );
    if (orphansHere) {
      orphanedBatchIds.add(batchId);
      group.forEach((e) => orphanedEntries.push(e));
    }
  }
  singles.forEach((e) => {
    if (e.collection === "learners" && e.data && parentMap.has(e.data.parentId)) {
      orphanedEntries.push(e);
    }
  });

  if (orphanedEntries.length > 0) {
    const orphanLearnerIds = new Set(orphanedEntries.map((e) => e.originalId));
    for (const [batchId, group] of batchGroups) {
      if (orphanedBatchIds.has(batchId) || renderedBatchIds.has(batchId)) continue;
      group.forEach((e) => {
        if (e.data && e.data.learnerId && orphanLearnerIds.has(e.data.learnerId)) {
          orphanedEntries.push(e);
          orphanedBatchIds.add(batchId);
        }
      });
    }
    singles.forEach((e) => {
      if (e.data && e.data.learnerId && orphanLearnerIds.has(e.data.learnerId)) {
        orphanedEntries.push(e);
      }
    });

    const affectedBatches = new Set();
    orphanedEntries.forEach((e) => {
      const parentInfo = e.collection === "learners"
        ? parentMap.get(e.data?.parentId)
        : (e.data?.learnerId ? findParentForLearnerRef(parentMap, e.data.learnerId) : null);
      if (parentInfo) {
        parentInfo.group.push(e);
        affectedBatches.add(parentInfo.batchId);
      }
    });

    affectedBatches.forEach((bid) => {
      tbody.querySelectorAll(`tr[data-batch-id="${bid}"]`).forEach((r) => r.remove());
    });
    affectedBatches.forEach((bid) => {
      const g = batchGroups.get(bid);
      renderTreeRow(tbody, buildTrashTree(g), bid, 0, true);
    });
  }

  // Mark orphaned batches as rendered so third pass doesn't duplicate them
  orphanedBatchIds.forEach((bid) => renderedBatchIds.add(bid));

  // Third pass: render remaining unrendered batch groups (rootless/standalone batches)
  for (const [batchId, group] of batchGroups) {
    if (renderedBatchIds.has(batchId)) continue;
    const tree = buildTrashTree(group);
    renderTreeRow(tbody, tree, batchId, 0, true);
    renderedBatchIds.add(batchId);
  }

  // Build set of all entry IDs that were absorbed into a tree
  const absorbedIds = new Set();
  batchGroups.forEach((group) => {
    group.forEach((e) => absorbedIds.add(e.id));
  });

  // Remaining singles (not absorbed into any batch tree)
  const remainingSingles = singles.filter((s) => !absorbedIds.has(s.id));
  remainingSingles.forEach((entry) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td></td>
      <td>${escapeAttr(trashTypeLabel(entry.collection))}</td>
      <td>${escapeAttr(getTrashDetails(entry))}</td>
      <td>${formatDate(entry.deletedAt)}</td>
      <td class="actions-cell">
        <button type="button" class="btn-view btn-small" data-action="restore-single" data-id="${entry.id}">Restore</button>
        <button type="button" class="btn-danger btn-small" data-action="delete-single" data-id="${entry.id}">Delete</button>
      </td>`;
    tbody.appendChild(tr);
  });

  // Assigned (not added) so a reload replaces the handler instead of stacking another one.
  tableEl.onclick = (e) => {
    const toggle = e.target.closest(".trash-toggle");
    if (!toggle) return handleTrashAction(e);
    const tr = toggle.closest("tr");
    const batchId = tr.dataset.batchId;
    const depth = parseInt(tr.dataset.depth || "0", 10);
    const order = tr.dataset.order || "0";
    const isExpanded = toggle.textContent === "\u25BC";
    toggle.textContent = isExpanded ? "\u25B6" : "\u25BC";
    toggle.setAttribute("aria-expanded", String(!isExpanded));

    const childRows = tbody.querySelectorAll(
      `tr[data-batch-id="${batchId}"][data-depth="${depth + 1}"][data-parent-order="${order}"]`
    );
    childRows.forEach((row) => {
      row.style.display = isExpanded ? "none" : "";
    });
  };
}

async function handleTrashAction(e) {
  const btn = e.target.closest("button[data-action]");
  if (!btn) return;
  e.stopPropagation();

  const action = btn.dataset.action;
  // Confirm before the overlay goes up, not underneath it.
  if (action === "delete-batch" && !window.confirm("Permanently delete all items in this group? This cannot be undone.")) return;
  if (action === "delete-single" && !window.confirm("Permanently delete this item from the trashbin? This cannot be undone.")) return;
  showLoading(action.startsWith("restore") ? "Restoring..." : "Deleting...");

  try {
    if (action === "restore-batch") {
      await restoreBatch(btn.dataset.batch);
      await loadAllData();
      hideLoading();
      showToast("All items restored successfully", "success");
    } else if (action === "delete-batch") {
      await deleteBatchPermanently(btn.dataset.batch);
      await loadAllData();
      hideLoading();
      showToast("All items permanently deleted", "success");
    } else if (action === "restore-single") {
      await restoreTrashItemById(btn.dataset.id);
      await loadAllData();
      hideLoading();
      showToast("Item restored successfully", "success");
    } else if (action === "delete-single") {
      await deleteTrashItemByIdPermanently(btn.dataset.id);
      await loadAllData();
      hideLoading();
      showToast("Item permanently deleted", "success");
    }
  } catch (err) {
    console.error("Operation failed:", err.message, err.code, err);
    hideLoading();
    showToast("Operation failed: " + (err.message || "unknown"), "error");
  }
}

function renderTreeRow(tbody, node, batchId, depth, isRoot, parentCol) {
  const e = node.entry;
  const hasChildren = node.children.length > 0;
  const isExpandedDefault = depth < 2; // auto-expand first 2 levels

  // Compute tree connector prefix
  let prefix = "";
  if (depth === 0) {
    prefix = "";
  } else if (depth === 1) {
    prefix = "\u2514\u2500 "; // └─
  } else {
    prefix = "\u2502  \u2514\u2500 "; // │  └─
  }

  const tr = document.createElement("tr");
  tr.className = depth === 0 ? "trash-batch-root" : "trash-batch-child";
  tr.dataset.batchId = batchId;
  tr.dataset.depth = depth;
  tr.dataset.order = e.id || "0";
  tr.dataset.parentOrder = depth > 0 ? (node.parentOrder || "0") : "0";
  if (!isRoot) tr.style.display = isExpandedDefault ? "" : "none";

  const toggleHtml = hasChildren
    ? `<button type="button" class="trash-toggle" aria-label="Show or hide related items" aria-expanded="${isExpandedDefault}">${isExpandedDefault ? "\u25BC" : "\u25B6"}</button>`
    : "";

  // Action buttons
  let actionsHtml = "";
  if (depth === 0) {
    actionsHtml = `
      <button type="button" class="btn-view btn-small" data-action="restore-batch" data-batch="${batchId}">Restore All</button>
      <button type="button" class="btn-danger btn-small" data-action="delete-batch" data-batch="${batchId}">Delete All</button>
    `;
  } else if (depth === 1 || parentCol === "learners" || parentCol === "parents") {
    actionsHtml = `<span class="text-muted">Restored with its group</span>`;
  } else {
    actionsHtml = `
      <button type="button" class="btn-view btn-small" data-action="restore-single" data-id="${e.id}">Restore</button>
      <button type="button" class="btn-danger btn-small" data-action="delete-single" data-id="${e.id}">Delete</button>
    `;
  }

  tr.innerHTML = `
    <td class="trash-toggle-cell">${toggleHtml}</td>
    <td style="padding-left: ${16 + depth * 20}px;">${prefix}<strong>${escapeAttr(trashTypeLabel(e.collection))}</strong></td>
    <td>${escapeAttr(getTrashDetails(e))}</td>
    <td>${formatDate(e.deletedAt)}</td>
    <td class="actions-cell">${actionsHtml}</td>
  `;
  tbody.appendChild(tr);

  // Recursively render children
  if (node.children.length > 0) {
    node.children.forEach((child, i) => {
      child.parentOrder = e.id || "0";
      renderTreeRow(tbody, child, batchId, depth + 1, false, e.collection);
    });
  }
}

// Removing a teacher deletes their `teacherIds` entry; restoring puts it back.
function restoreEmployeeIdLookup(batch, entry) {
  const d = entry.data || {};
  if (entry.collection === "teachers" && d.employeeId && d.email) {
    batch.set(doc(db, "teacherIds", d.employeeId), { email: d.email, teacherId: entry.originalId });
  }
}

async function restoreBatch(batchId) {
  const snap = await getDocs(query(collection(db, "trashbin"), where("batchId", "==", batchId)));
  const entries = snap.docs.map((d) => ({ id: d.id, ...d.data(), ref: d.ref }));

  // Must restore in dependency order so security-rule `exists()` checks
  // (e.g. learner requires parent, enrollment requires class+learner) pass.
  const rootCols = new Set(["parents", "teachers", "classes"]);
  const midCols = new Set(["learners"]);
  const leafCols = new Set(["enrollments", "progress", "assigned_modules", "custom_lessons", "consents"]);

  const runGroup = async (group) => {
    if (group.length === 0) return;
    const b = writeBatch(db);
    group.forEach((e) => {
      b.set(doc(db, e.collection, e.originalId), e.data);
      restoreEmployeeIdLookup(b, e);
      b.delete(e.ref);
    });
    await b.commit();
  };

  await runGroup(entries.filter((e) => rootCols.has(e.collection)));
  await runGroup(entries.filter((e) => midCols.has(e.collection)));
  await runGroup(entries.filter((e) => leafCols.has(e.collection)));
}

async function deleteBatchPermanently(batchId) {
  const snap = await getDocs(query(collection(db, "trashbin"), where("batchId", "==", batchId)));
  const batch = writeBatch(db);
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function restoreTrashItemById(id) {
  const ref = doc(db, "trashbin", id);
  const d = await getDoc(ref);
  if (!d.exists()) return;
  const data = d.data();
  const batch = writeBatch(db);
  batch.set(doc(db, data.collection, data.originalId), data.data);
  batch.delete(ref);
  await batch.commit();
}

async function deleteTrashItemByIdPermanently(id) {
  const ref = doc(db, "trashbin", id);
  const d = await getDoc(ref);
  if (!d.exists()) return;
  await writeBatch(db).delete(ref).commit();
}

function showClassStudents(classRow, enrollments, learners) {
  const enrolledIds = new Set(
    enrollments.filter((e) => e.classId === classRow.id).map((e) => e.learnerId)
  );
  const availableLearners = learners.filter((l) => !enrolledIds.has(l.id));

  let studentsListHtml = "";
  if (enrolledIds.size === 0) {
    studentsListHtml = `<p class="empty-text">No students enrolled in this class yet.</p>`;
  } else {
    const classEnrollments = enrollments.filter((e) => e.classId === classRow.id);
    const seenLearnerIds = new Set();
    const enrolledLearners = [];
    for (const e of classEnrollments) {
      if (!e.learnerId || seenLearnerIds.has(e.learnerId)) continue;
      seenLearnerIds.add(e.learnerId);
      const learner = learners.find((l) => l.id === e.learnerId);
      if (learner) {
        enrolledLearners.push({ ...learner, enrolledAt: e.enrolledAt });
      }
    }
    studentsListHtml = `
      <div class="table-wrap cards-wrap">
        <table class="cards">
          <thead>
            <tr>
              <th>Name</th>
              <th>Age</th>
              <th>Grade</th>
              <th>Enrolled Date</th>
            </tr>
          </thead>
          <tbody>
            ${enrolledLearners
              .map(
                (l) => `
              <tr>
                <td data-label="Name">${escapeAttr(l.name)}</td>
                <td data-label="Age">${l.age}</td>
                <td data-label="Grade">${escapeAttr(l.gradeLevel)}</td>
                <td data-label="Enrolled Date">${formatDate(l.enrolledAt)}</td>
              </tr>
            `
              )
              .join("")}
          </tbody>
        </table>
      </div>
    `;
  }

  const learnerOptions = availableLearners
    .map(
      (l) => `<option value="${l.id}">${escapeAttr(l.name)} (${escapeAttr(l.gradeLevel)})</option>`
    )
    .join("");

  const enrollFormHtml = availableLearners.length > 0
    ? `
      <div class="enroll-form">
        <label>
          Enroll a student
          <select id="enroll-learner-select">
            <option value="">— Select —</option>
            ${learnerOptions}
          </select>
        </label>
        <button type="button" class="btn-primary btn-small" id="enroll-btn" disabled>Enroll</button>
      </div>
    `
    : `<p class="modal-note">All learners are already enrolled in this class.</p>`;

  const modalOverlay = document.createElement("div");
  modalOverlay.className = "modal-overlay";

  modalOverlay.innerHTML = `
    <div class="modal-card">
      <div class="modal-header">
        <h3>Students in ${escapeAttr(classRow.name)}</h3>
        <button type="button" class="modal-close" id="close-modal-btn" aria-label="Close">&times;</button>
      </div>
      <div class="modal-body">
        ${enrollFormHtml}
        ${studentsListHtml}
      </div>
      <div class="modal-footer">
        <button class="btn-ghost" id="close-modal-footer-btn">Close</button>
      </div>
    </div>
  `;

  const closeModal = openModal(modalOverlay);

  const select = modalOverlay.querySelector("#enroll-learner-select");
  const enrollBtn = modalOverlay.querySelector("#enroll-btn");
  if (select && enrollBtn) {
    select.addEventListener("change", () => {
      enrollBtn.disabled = !select.value;
    });
    enrollBtn.addEventListener("click", async () => {
      const learnerId = select.value;
      if (!learnerId) return;
      if (enrolledIds.has(learnerId)) {
        showToast("Student is already enrolled in this class", "error");
        return;
      }
      enrollBtn.disabled = true;
      try {
        const docId = `${classRow.id}_${learnerId}`;
        await setDoc(doc(db, "enrollments", docId), {
          classId: classRow.id,
          learnerId,
          enrolledAt: new Date().toISOString(),
        });
        closeModal();
        showToast("Student enrolled successfully", "success");
        await loadAllData();
      } catch (err) {
        console.error(err);
        showToast("Failed to enroll student", "error");
        enrollBtn.disabled = false;
      }
    });
  }
}

// ---- Progress: Student Hub view ----
const hubSelect = document.getElementById("hub-learner-select");
const progressSearch = document.querySelector('.table-search[data-table="table-progress"]');

function setProgressView(view) {
  document.querySelectorAll("[data-progress-view]").forEach((b) => {
    const on = b.dataset.progressView === view;
    b.classList.toggle("active", on);
    b.setAttribute("aria-pressed", String(on));
  });
  document.getElementById("progress-table-view").hidden = view !== "table";
  document.getElementById("progress-hub-view").hidden = view !== "hub";
  progressSearch.hidden = view !== "table";
  hubSelect.hidden = view !== "hub";
  if (view === "hub") renderSelectedHub();
}

function fillHubLearnerSelect() {
  const keep = hubSelect.value;
  const sorted = [...hubData.learners].sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
  hubSelect.innerHTML = sorted.length === 0
    ? `<option value="">No learners yet</option>`
    : sorted.map((l) => `<option value="${escapeAttr(l.id)}">${escapeAttr(l.name ?? l.id)} (${studentIdFor(l.id)})</option>`).join("");
  if (sorted.some((l) => l.id === keep)) hubSelect.value = keep;
  if (!document.getElementById("progress-hub-view").hidden) renderSelectedHub();
}

function renderSelectedHub() {
  const phone = document.getElementById("hub-phone");
  const learner = hubData?.learners.find((l) => l.id === hubSelect.value);
  if (!learner) {
    phone.innerHTML = `<p class="empty-text hub-empty">Select a learner to view their Student Hub.</p>`;
    return;
  }
  renderHubView(phone, { ...hubData, learner }, studentIdFor(learner.id));
}

function openLearnerHub(learnerId) {
  if (hubData?.learners.some((l) => l.id === learnerId)) hubSelect.value = learnerId;
  setProgressView("hub");
}

document.querySelectorAll("[data-progress-view]").forEach((b) =>
  b.addEventListener("click", () => setProgressView(b.dataset.progressView))
);
hubSelect.addEventListener("change", renderSelectedHub);

// Stage / game / session for a progress record. Lesson ids resolve through
// curriculum-map.js; older classroom records only carry `cast_<game>` (or
// `hot_seat_<letter>`), so their stage and session are unknown.
function progressPlace(r) {
  const lesson = r.lessonId ? LESSONS[r.lessonId] : null;
  if (lesson) {
    return {
      stage: `Stage ${lesson.stage}: ${STAGES[lesson.stage]}`,
      game: GAMES[lesson.game] ?? lesson.game,
      session: `Session ${lesson.session}`,
      title: lesson.title,
    };
  }
  const id = String(r.moduleId ?? "");
  if (id.startsWith("hot_seat_")) {
    return { stage: "—", game: `${GAMES.trace} (Hot Seat)`, session: `Letter ${id.slice(9)}`, title: "" };
  }
  if (id.startsWith("cast_")) {
    return { stage: "—", game: GAMES[id.slice(5)] ?? id.slice(5), session: "—", title: "" };
  }
  return {
    stage: STAGES[id] ? `Stage ${id}: ${STAGES[id]}` : "—",
    game: r.lessonId ? "Custom lesson" : "—",
    session: "—",
    title: "",
  };
}

function showLearnerProgress(row) {
  const modalOverlay = document.createElement("div");
  modalOverlay.className = "modal-overlay";

  const total = row.classroomCount + row.homeCount;

  const rowsFor = (records, emptyText) => records.length === 0
    ? `<tr class="empty-row"><td colspan="7">${emptyText}</td></tr>`
    : records
        .sort((a, b) => new Date(b.completedAt ?? 0) - new Date(a.completedAt ?? 0))
        .map((r) => {
          const place = progressPlace(r);
          return `<tr>
          <td data-label="Stage">${escapeAttr(place.stage)}</td>
          <td data-label="Game">${escapeAttr(place.game)}</td>
          <td data-label="Session" title="${escapeAttr(place.title)}">${escapeAttr(place.session)}</td>
          <td data-label="Accuracy">${r.strokeAccuracyPct != null ? `${Math.round(r.strokeAccuracyPct)}%` : "—"}</td>
          <td data-label="Errors">${r.sequencingErrors ?? "—"}</td>
          <td data-label="Time on Task">${r.timeOnTaskSeconds != null ? `${r.timeOnTaskSeconds}s` : "—"}</td>
          <td data-label="Completed">${formatDate(r.completedAt)}</td>
        </tr>`;
        })
        .join("");
  const classroomRows = rowsFor(row.classroom, "No classroom-mode records.");
  const homeRows = rowsFor(row.home, "No home-mode records.");

  modalOverlay.innerHTML = `
    <div class="modal-card modal-wide">
      <div class="modal-header">
        <h3>${escapeAttr(row.learnerName)} — Progress (${total} records)</h3>
        <button type="button" class="modal-close" id="close-modal-btn" aria-label="Close">&times;</button>
      </div>
      <div class="modal-body">
        <h4 class="mode-section-title">Classroom Mode (${row.classroomCount})</h4>
        <div class="table-wrap cards-wrap modal-table">
          <table class="cards">
            <thead><tr>
              <th>Stage</th><th>Game</th><th>Session</th><th>Accuracy</th><th>Errors</th><th>Time on Task</th><th>Completed</th>
            </tr></thead>
            <tbody>${classroomRows}</tbody>
          </table>
        </div>
        <h4 class="mode-section-title">Home Mode (${row.homeCount})</h4>
        <div class="table-wrap cards-wrap">
          <table class="cards">
            <thead><tr>
              <th>Stage</th><th>Game</th><th>Session</th><th>Accuracy</th><th>Errors</th><th>Time on Task</th><th>Completed</th>
            </tr></thead>
            <tbody>${homeRows}</tbody>
          </table>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn-ghost" id="close-modal-footer-btn">Close</button>
      </div>
    </div>
  `;

  openModal(modalOverlay);
}

function openModal(overlay) {
  const opener = document.activeElement;
  const onKey = (e) => {
    if (e.key === "Escape") close();
  };
  const close = () => {
    overlay.remove();
    document.removeEventListener("keydown", onKey);
    opener?.focus?.();
  };
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  document.body.appendChild(overlay);
  overlay.querySelector("#close-modal-btn").addEventListener("click", close);
  overlay.querySelector("#close-modal-footer-btn").addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });
  document.addEventListener("keydown", onKey);
  overlay.querySelector("#close-modal-btn").focus();
  return close;
}
