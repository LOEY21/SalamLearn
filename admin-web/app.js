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
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

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
    showToast("Signed in successfully", "success");
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
  loginView.hidden = true;
  dashboardView.hidden = false;
  whoami.textContent = user.email ?? "";
  await loadAllData();
});

// ---- Tabs ----
const tabButtons = document.querySelectorAll(".tab-btn");
tabButtons.forEach((btn) => {
  btn.addEventListener("click", () => {
    tabButtons.forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    document.querySelectorAll(".tab-panel").forEach((panel) => {
      panel.hidden = panel.id !== `tab-${btn.dataset.tab}`;
    });
  });
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

// ---- Data loading ----
// Collection names mirror `HiveBoxes` constants in the Flutter app
// (lib/data/local/hive_boxes.dart) — `firestore_mirror.dart` pushes to
// these exact collection names, one per Hive box. `streaks`/`badges`
// aren't mirrored yet, so they aren't read here either.
async function fetchAll(name) {
  const snap = await getDocs(collection(db, name));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
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

function renderTable(tableEl, columns, rows, actions) {
  const actionsList = Array.isArray(actions) ? actions : (actions ? [actions] : []);
  const allColumns = actionsList.length > 0 ? [...columns, { label: "Actions" }] : columns;
  if (rows.length === 0) {
    tableEl.innerHTML = `
      <thead><tr>${allColumns.map((c) => `<th>${c.label}</th>`).join("")}</tr></thead>
      <tbody><tr class="empty-row"><td colspan="${allColumns.length}">No records yet.</td></tr></tbody>
    `;
    return;
  }
  const head = `<tr>${allColumns.map((c) => `<th>${c.label}</th>`).join("")}</tr>`;
  tableEl.innerHTML = `<thead>${head}</thead><tbody></tbody>`;
  const tbody = tableEl.querySelector("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    columns.forEach((c) => {
      const td = document.createElement("td");
      td.textContent = c.value(row) ?? "—";
      tr.appendChild(td);
    });
    if (actionsList.length > 0) {
      const td = document.createElement("td");
      td.className = "actions-cell";
      actionsList.forEach((act) => {
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
}

function renderDashboard(data) {
  const { parents, teachers, learners, classes, enrollments, progress } = data;

  // Stats
  const labels = {
    parents: "Parents",
    teachers: "Asatidz",
    learners: "Learners",
    classes: "Classes",
    enrollments: "Enrollments",
    progress: "Progress records",
  };
  document.getElementById("stat-grid").innerHTML = Object.entries(labels)
    .map(
      ([key, label]) => `
        <div class="stat-card">
          <div class="stat-value">${data[key].length}</div>
          <div class="stat-label">${label}</div>
        </div>`
    )
    .join("");

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

  // Insights
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

  const insightsBody = document.querySelector("#dash-insights .dash-card-body");
  insightsBody.innerHTML = `
    <div class="insight-item"><strong>${enrolledLearnerIds.size}</strong> / ${learners.length} learners enrolled in a class</div>
    <div class="insight-item"><strong>${learnersNoClass.length}</strong> learners not yet in any class</div>
    <div class="insight-item"><strong>${classesNoStudents.length}</strong> classes with no students</div>
    <div class="insight-item">${topParent ? `<strong>${escapeAttr(topParent.fullName)}</strong> has the most children (${maxChildren})` : "No parents with children yet"}</div>
    <div class="insight-item"><strong>${progress.length}</strong> total progress records</div>
    ${progress.length > 0 ? `<div class="insight-item">Last activity: ${formatDate([...progress].sort((a, b) => (b.completedAt ?? "").localeCompare(a.completedAt ?? ""))[0].completedAt)}</div>` : ""}
  `;
}

async function loadAllData() {
  accessDenied.hidden = true;
  try {
    const [parents, teachers, principals, learners, classes, enrollments, progress, trashbin] =
      await Promise.all([
        fetchAll("parents"),
        fetchAll("teachers"),
        fetchAll("principals"),
        fetchAll("learners"),
        fetchAll("classes"),
        fetchAll("enrollments"),
        fetchAll("progress"),
        fetchAll("trashbin"),
      ]);

    renderDashboard({
      parents, teachers, learners, classes, enrollments, progress,
    });

    renderTable(
      document.getElementById("table-parents"),
      [
        { label: "Name", value: (r) => r.fullName },
        { label: "Email", value: (r) => r.email },
        { label: "Mobile", value: (r) => r.mobileNumber },
        { label: "Registered", value: (r) => formatDate(r.createdAt) },
      ],
      parents,
      [
        { label: "Reset Password", className: "btn-view", onClick: (row) => resetAccountPassword(row.email) },
        { label: "Remove", onClick: (row, btn) => confirmDeleteParent(row, btn) },
      ]
    );

    renderTable(
      document.getElementById("table-teachers"),
      [
        { label: "Name", value: (r) => r.fullName },
        { label: "School", value: (r) => r.school },
        { label: "Email", value: (r) => r.email },
        { label: "Registered", value: (r) => formatDate(r.createdAt) },
      ],
      teachers,
      [
        { label: "Reset Password", className: "btn-view", onClick: (row) => resetAccountPassword(row.email) },
        { label: "Remove", onClick: (row, btn) => confirmDeleteTeacher(row, btn) },
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

    const parentNameById = new Map(parents.map((p) => [p.id, p.fullName]));
    renderTable(
      document.getElementById("table-learners"),
      [
        { label: "Name", value: (r) => r.name },
        { label: "Age", value: (r) => r.age },
        { label: "Grade", value: (r) => r.gradeLevel },
        { label: "Parent", value: (r) => parentNameById.get(r.parentId) ?? r.parentId },
        { label: "Added", value: (r) => formatDate(r.createdAt) },
      ],
      learners,
      { label: "Remove", onClick: (row, btn) => confirmDeleteLearner(row, btn) }
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
      ]
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
      { label: "View Progress", className: "btn-view", onClick: (row) => showLearnerProgress(row) }
    );

    const trashbinUsers = trashbin.filter((r) => r.deletedBy !== "admin");
    const trashbinAdmins = trashbin.filter((r) => r.deletedBy === "admin");

    renderTable(
      document.getElementById("table-trashbin-users"),
      [
        { label: "Type", value: (r) => r.collection ? r.collection.toUpperCase() : "" },
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
      renderStats({});
      document.querySelectorAll(".tab-panel table").forEach((t) => (t.innerHTML = ""));
    } else {
      console.error(err);
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
  return String(value ?? "").replace(/"/g, "&quot;");
}

// ---- Add-user forms (show/hide) ----
document.querySelectorAll("[data-open-form]").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.getElementById(`form-${btn.dataset.openForm}`).hidden = false;
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

function showFormError(form, message) {
  const errorEl = form.querySelector(".form-error");
  errorEl.textContent = message;
  errorEl.hidden = false;
}

// A normal `createUserWithEmailAndPassword(auth, ...)` call would sign the
// admin's own session out and into the new account — the client SDK has no
// "create another user without switching sessions" mode. Working around it
// with a second, throwaway Firebase App instance (same project) keeps the
// admin's own `auth` session on this page untouched; the throwaway app is
// torn down right after we have the new user's uid.
async function createAuthAccountWithoutSignOut(email, password) {
  const workerApp = initializeApp(firebaseConfig, `admin-worker-${Date.now()}`);
  try {
    const workerAuth = getAuth(workerApp);
    const credential = await createUserWithEmailAndPassword(workerAuth, email, password);
    // Activation step for the account holder (Teacher/Parent app's
    // "New Account" / "Activate my account" flow): sends Firebase's own
    // built-in password-reset email. They set their own real password on
    // Firebase's hosted reset page, then sign in with it in the app — the
    // password typed into this admin form is never emailed to them, and
    // never needs to be (it's just what creates the account here).
    try {
      await sendPasswordResetEmail(workerAuth, email);
    } catch (err) {
      console.error("Activation email failed to send:", err);
    }
    return credential.user.uid;
  } finally {
    await deleteApp(workerApp);
  }
}

function resetAccountPassword(email) {
  if (!email) {
    showToast("No email on file — cannot send reset link.", "error");
    return;
  }
  if (!window.confirm(`Send a password-reset email to ${email}?`)) return;
  sendPasswordResetEmail(auth, email)
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
  submitBtn.disabled = true;
  showLoading("Creating parent account...");
  try {
    const firebaseUid = await createAuthAccountWithoutSignOut(
      data.get("email").trim().toLowerCase(),
      data.get("password")
    );
    const batch = writeBatch(db);
    batch.set(doc(collection(db, "parents")), {
      fullName: data.get("fullName").trim(),
      email: data.get("email").trim().toLowerCase(),
      mobileNumber: data.get("mobileNumber").trim() || null,
      createdAt: new Date().toISOString(),
      firebaseUid,
    });
    await batch.commit();
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

document.getElementById("form-teacher").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  submitBtn.disabled = true;
  showLoading("Creating teacher account...");
  try {
    const firebaseUid = await createAuthAccountWithoutSignOut(
      data.get("email").trim().toLowerCase(),
      data.get("password")
    );
    const batch = writeBatch(db);
    batch.set(doc(collection(db, "teachers")), {
      fullName: data.get("fullName").trim(),
      school: data.get("school").trim() || null,
      email: data.get("email").trim().toLowerCase(),
      mobileNumber: data.get("mobileNumber").trim() || null,
      createdAt: new Date().toISOString(),
      firebaseUid,
    });
    await batch.commit();
    form.hidden = true;
    form.reset();
    await loadAllData();
    hideLoading();
    showToast("Teacher created successfully", "success");
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
    const firebaseUid = await createAuthAccountWithoutSignOut(email, data.get("password"));
    // Unlike parents/teachers (random doc id), a principal's doc id is set
    // equal to their own Firebase Auth uid — see firestore.rules' PRINCIPAL
    // MONITORING note for why: it's what lets a principal prove "this is my
    // own doc" with a plain get() instead of an unprovable query.
    await setDoc(doc(db, "principals", firebaseUid), {
      fullName: data.get("fullName").trim(),
      email,
      firebaseUid,
      createdAt: new Date().toISOString(),
    });
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
  const firstName = data.get("firstName").trim();
  const lastName = data.get("lastName").trim();
  if (!firstName || !lastName) {
    showFormError(form, "First and last name are required.");
    return;
  }
  const middleName = data.get("middleName").trim();
  const name = middleName ? `${firstName} ${middleName} ${lastName}` : `${firstName} ${lastName}`;
  const age = data.get("age") === "custom" ? Number(data.get("ageCustom")) : Number(data.get("age"));
  if (!age || age < 1) {
    showFormError(form, "Please enter a valid age.");
    return;
  }
  submitBtn.disabled = true;
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

async function confirmDeleteLearner(row, btn) {
  if (!window.confirm(`Remove learner "${row.name}"? This deletes their cloud record, enrollments, progress, and assignments. This will be moved to the trashbin.`)) {
    return;
  }
  showLoading("Removing learner and related data...");
  try {
    const batchId = `cascade_${Date.now()}`;
    const batch = writeBatch(db);
    const learnerId = row.id;
    
    // Archive and delete dependent docs
    await archiveAndDeleteDocsWhere(batch, "enrollments", "learnerId", learnerId, batchId);
    await archiveAndDeleteDocsWhere(batch, "progress", "learnerId", learnerId, batchId);
    await archiveAndDeleteDocsWhere(batch, "assigned_modules", "learnerId", learnerId, batchId);
    
    // Archive and delete the learner itself
    const { id, ...learnerData } = row;
    archiveDocToTrashbinBatch(batch, "learners", learnerId, learnerData, batchId);
    batch.delete(doc(db, "learners", learnerId));
    
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Learner removed and moved to trashbin", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to remove learner", "error");
  }
}

async function confirmDeleteParent(row, btn) {
  if (!window.confirm(`Remove parent "${row.fullName}"? This also deletes their learners and everything tied to those learners. This will be moved to the trashbin.`)) {
    return;
  }
  showLoading("Removing parent and all related data...");
  try {
    const batchId = `cascade_${Date.now()}`;
    const learners = await getDocs(query(collection(db, "learners"), where("parentId", "==", row.id)));
    const batch = writeBatch(db);
    
    for (const learnerDoc of learners.docs) {
      const learnerId = learnerDoc.id;
      const learnerData = learnerDoc.data();
      
      await archiveAndDeleteDocsWhere(batch, "enrollments", "learnerId", learnerId, batchId);
      await archiveAndDeleteDocsWhere(batch, "progress", "learnerId", learnerId, batchId);
      await archiveAndDeleteDocsWhere(batch, "assigned_modules", "learnerId", learnerId, batchId);
      
      archiveDocToTrashbinBatch(batch, "learners", learnerId, learnerData, batchId);
      batch.delete(doc(db, "learners", learnerId));
    }
    
    const { id, ...parentData } = row;
    archiveDocToTrashbinBatch(batch, "parents", row.id, parentData, batchId);
    batch.delete(doc(db, "parents", row.id));
    
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Parent and all related data moved to trashbin", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to remove parent", "error");
  }
}

async function confirmDeleteClass(row, btn) {
  if (!window.confirm(`Remove class "${row.name}"? This also deletes its enrollments and assignments. This will be moved to the trashbin.`)) {
    return;
  }
  showLoading("Removing class and related data...");
  try {
    const batchId = `cascade_${Date.now()}`;
    const batch = writeBatch(db);
    const classId = row.id;
    
    await archiveAndDeleteDocsWhere(batch, "enrollments", "classId", classId, batchId);
    await archiveAndDeleteDocsWhere(batch, "assigned_modules", "classId", classId, batchId);
    await archiveAndDeleteDocsWhere(batch, "custom_lessons", "classId", classId, batchId);
    
    const { id, ...classData } = row;
    archiveDocToTrashbinBatch(batch, "classes", classId, classData, batchId);
    batch.delete(doc(db, "classes", classId));
    
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Class removed and moved to trashbin", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to remove class", "error");
  }
}

async function confirmDeleteTeacher(row, btn) {
  if (!window.confirm(`Remove teacher "${row.fullName}"? This also deletes their classes and related enrollments/assignments. This will be moved to the trashbin.`)) {
    return;
  }
  showLoading("Removing teacher and all related data...");
  try {
    const batchId = `cascade_${Date.now()}`;
    const classes = await getDocs(query(collection(db, "classes"), where("teacherId", "==", row.id)));
    const batch = writeBatch(db);
    
    for (const classDoc of classes.docs) {
      const classId = classDoc.id;
      const classData = classDoc.data();
      
      await archiveAndDeleteDocsWhere(batch, "enrollments", "classId", classId, batchId);
      await archiveAndDeleteDocsWhere(batch, "assigned_modules", "classId", classId, batchId);
      await archiveAndDeleteDocsWhere(batch, "custom_lessons", "classId", classId, batchId);
      
      archiveDocToTrashbinBatch(batch, "classes", classId, classData, batchId);
      batch.delete(doc(db, "classes", classId));
    }
    
    const { id, ...teacherData } = row;
    archiveDocToTrashbinBatch(batch, "teachers", row.id, teacherData, batchId);
    batch.delete(doc(db, "teachers", row.id));
    
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Teacher and all related data moved to trashbin", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to remove teacher", "error");
  }
}

async function confirmDeletePrincipal(row, btn) {
  if (!window.confirm(`Remove principal "${row.fullName}"? This will be moved to the trashbin.`)) {
    return;
  }
  showLoading("Removing principal...");
  try {
    const batch = writeBatch(db);
    const { id, ...principalData } = row;
    archiveDocToTrashbinBatch(batch, "principals", row.id, principalData, null);
    batch.delete(doc(db, "principals", row.id));
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Principal removed and moved to trashbin", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to remove principal", "error");
  }
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

async function restoreTrashItem(row, btn) {
  showLoading("Restoring item...");
  try {
    const batch = writeBatch(db);
    const targetRef = doc(db, row.collection, row.originalId);
    batch.set(targetRef, row.data);
    batch.delete(doc(db, "trashbin", row.id));
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Item restored successfully", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to restore item", "error");
  }
}

async function deleteTrashItemPermanently(row, btn) {
  if (!window.confirm("Permanently delete this item from the trashbin? This cannot be undone.")) {
    return;
  }
  showLoading("Deleting item permanently...");
  try {
    const batch = writeBatch(db);
    batch.delete(doc(db, "trashbin", row.id));
    await batch.commit();
    await loadAllData();
    hideLoading();
    showToast("Item permanently deleted", "success");
  } catch (err) {
    console.error(err);
    hideLoading();
    showToast("Failed to delete item", "error");
  }
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
      <td>${entry.collection ? entry.collection.toUpperCase() : ""}</td>
      <td>${getTrashDetails(entry)}</td>
      <td>${formatDate(entry.deletedAt)}</td>
      <td class="actions-cell">
        <button type="button" class="btn-view btn-small" data-action="restore-single" data-id="${entry.id}">Restore</button>
        <button type="button" class="btn-danger btn-small" data-action="delete-single" data-id="${entry.id}">Delete</button>
      </td>`;
    tbody.appendChild(tr);
  });

  // Event delegation — toggle expand
  tableEl.addEventListener("click", (e) => {
    const toggle = e.target.closest(".trash-toggle");
    if (!toggle) return;
    const tr = toggle.closest("tr");
    const batchId = tr.dataset.batchId;
    const depth = parseInt(tr.dataset.depth || "0", 10);
    const order = tr.dataset.order || "0";
    const isExpanded = toggle.textContent === "\u25BC";
    toggle.textContent = isExpanded ? "\u25B6" : "\u25BC";

    const childRows = tbody.querySelectorAll(
      `tr[data-batch-id="${batchId}"][data-depth="${depth + 1}"][data-parent-order="${order}"]`
    );
    childRows.forEach((row) => {
      row.style.display = isExpanded ? "none" : "";
    });
  });

  // Event delegation — action buttons
  tableEl.addEventListener("click", async (e) => {
    const btn = e.target.closest("button[data-action]");
    if (!btn) return;
    e.stopPropagation();

    const action = btn.dataset.action;
    let label = "batch";
    if (action === "restore-batch") label = "restore all";
    else if (action === "delete-batch") label = "delete all";
    else if (action === "restore-single") label = "restore";
    else if (action === "delete-single") label = "delete";

    showLoading(`${label.charAt(0).toUpperCase() + label.slice(1)}ing...`);

    try {
      if (action === "restore-batch") {
        await restoreBatch(btn.dataset.batch);
        await loadAllData();
        hideLoading();
        showToast("All items restored successfully", "success");
      } else if (action === "delete-batch") {
        if (!window.confirm("Permanently delete all items in this group? This cannot be undone.")) {
          hideLoading();
          return;
        }
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
  });
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
    ? `<span class="trash-toggle">${isExpandedDefault ? "\u25BC" : "\u25B6"}</span>`
    : "";

  // Action buttons
  let actionsHtml = "";
  if (depth === 0) {
    actionsHtml = `
      <button type="button" class="btn-view btn-small" data-action="restore-batch" data-batch="${batchId}">Restore All</button>
      <button type="button" class="btn-danger btn-small" data-action="delete-batch" data-batch="${batchId}">Delete All</button>
    `;
  } else if (depth === 1 || parentCol === "learners" || parentCol === "parents") {
    actionsHtml = `<span class="text-muted" style="font-size:0.78rem;">(restore with parent batch)</span>`;
  } else {
    actionsHtml = `
      <button type="button" class="btn-view btn-small" data-action="restore-single" data-id="${e.id}">Restore</button>
      <button type="button" class="btn-danger btn-small" data-action="delete-single" data-id="${e.id}">Delete</button>
    `;
  }

  tr.innerHTML = `
    <td class="trash-toggle-cell">${toggleHtml}</td>
    <td style="padding-left: ${depth * 24}px;">${prefix}<strong>${e.collection ? e.collection.toUpperCase() : ""}</strong></td>
    <td>${getTrashDetails(e)}</td>
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

async function restoreBatch(batchId) {
  const snap = await getDocs(query(collection(db, "trashbin"), where("batchId", "==", batchId)));
  const entries = snap.docs.map((d) => ({ id: d.id, ...d.data(), ref: d.ref }));

  // Must restore in dependency order so security-rule `exists()` checks
  // (e.g. learner requires parent, enrollment requires class+learner) pass.
  const rootCols = new Set(["parents", "teachers", "classes"]);
  const midCols = new Set(["learners"]);
  const leafCols = new Set(["enrollments", "progress", "assigned_modules", "custom_lessons", "consents"]);

  const runGroup = async (group, label) => {
    if (group.length === 0) return;
    const b = writeBatch(db);
    group.forEach((e) => {
      console.log(`[restore] batch.set ${e.collection}/${e.originalId}`, JSON.stringify(e.data));
      console.log(`[restore]   keys:`, Object.keys(e.data));
      b.set(doc(db, e.collection, e.originalId), e.data);
      console.log(`[restore] batch.delete trashbin/${e.id}`);
      b.delete(e.ref);
    });
    await b.commit();
    console.log(`[restore] group "${label}" committed successfully (${group.length} items)`);
  };

  await runGroup(entries.filter((e) => rootCols.has(e.collection)), "root");
  await runGroup(entries.filter((e) => midCols.has(e.collection)), "mid");
  await runGroup(entries.filter((e) => leafCols.has(e.collection)), "leaf");
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
  console.log(`[restore-single] ${data.collection}/${data.originalId}`, data.data);
  const batch = writeBatch(db);
  batch.set(doc(db, data.collection, data.originalId), data.data);
  batch.delete(ref);
  await batch.commit();
}

async function deleteTrashItemByIdPermanently(id) {
  const ref = doc(db, "trashbin", id);
  const d = await getDoc(ref);
  if (!d.exists()) return;
  if (!window.confirm("Permanently delete this item from the trashbin? This cannot be undone.")) return;
  await writeBatch(db).delete(ref).commit();
}

function showClassStudents(classRow, enrollments, learners) {
  const enrolledIds = new Set(
    enrollments.filter((e) => e.classId === classRow.id).map((e) => e.learnerId)
  );
  const availableLearners = learners.filter((l) => !enrolledIds.has(l.id));

  let studentsListHtml = "";
  if (enrolledIds.size === 0) {
    studentsListHtml = `<p class="empty-row" style="text-align: center; color: var(--text-muted); padding: 20px 0;">No students enrolled in this class yet.</p>`;
  } else {
    const classEnrollments = enrollments.filter((e) => e.classId === classRow.id);
    const enrolledLearners = classEnrollments
      .map((e) => {
        const learner = learners.find((l) => l.id === e.learnerId);
        return learner ? { ...learner, enrolledAt: e.enrolledAt } : null;
      })
      .filter(Boolean);
    studentsListHtml = `
      <div class="table-wrap">
        <table>
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
                <td>${escapeAttr(l.name)}</td>
                <td>${l.age}</td>
                <td>${escapeAttr(l.gradeLevel)}</td>
                <td>${formatDate(l.enrolledAt)}</td>
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
      <div class="enroll-form" style="display:flex;gap:8px;align-items:flex-end;margin-bottom:14px;">
        <label style="flex:1;font-size:0.8rem;color:var(--text-muted);display:flex;flex-direction:column;gap:4px;">
          Enroll a student
          <select id="enroll-learner-select" style="font:inherit;padding:8px 10px;border:1px solid var(--cream-border);border-radius:var(--radius-sm);background:var(--cream);color:var(--ink);">
            <option value="">— Select —</option>
            ${learnerOptions}
          </select>
        </label>
        <button type="button" class="btn-primary btn-small" id="enroll-btn" disabled>Enroll</button>
      </div>
    `
    : `<p style="font-size:0.82rem;color:var(--text-muted);margin-bottom:14px;">All learners are already enrolled in this class.</p>`;

  const modalOverlay = document.createElement("div");
  modalOverlay.className = "modal-overlay";

  modalOverlay.innerHTML = `
    <div class="modal-card">
      <div class="modal-header">
        <h3>Students in ${escapeAttr(classRow.name)}</h3>
        <button class="modal-close" id="close-modal-btn">&times;</button>
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

  document.body.appendChild(modalOverlay);

  const closeModal = () => {
    modalOverlay.remove();
  };

  modalOverlay.querySelector("#close-modal-btn").addEventListener("click", closeModal);
  modalOverlay.querySelector("#close-modal-footer-btn").addEventListener("click", closeModal);
  modalOverlay.addEventListener("click", (e) => {
    if (e.target === modalOverlay) closeModal();
  });

  const select = modalOverlay.querySelector("#enroll-learner-select");
  const enrollBtn = modalOverlay.querySelector("#enroll-btn");
  if (select && enrollBtn) {
    select.addEventListener("change", () => {
      enrollBtn.disabled = !select.value;
    });
    enrollBtn.addEventListener("click", async () => {
      const learnerId = select.value;
      if (!learnerId) return;
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

function showLearnerProgress(row) {
  const modalOverlay = document.createElement("div");
  modalOverlay.className = "modal-overlay";

  const total = row.classroomCount + row.homeCount;

  const classroomRows = row.classroom.length === 0
    ? `<tr><td colspan="5" class="empty-row">No classroom-mode records.</td></tr>`
    : row.classroom
        .sort((a, b) => new Date(b.completedAt ?? 0) - new Date(a.completedAt ?? 0))
        .map((r) => `<tr>
          <td>${escapeAttr(r.moduleId)}</td>
          <td>${r.strokeAccuracyPct != null ? `${r.strokeAccuracyPct}%` : "—"}</td>
          <td>${r.sequencingErrors ?? "—"}</td>
          <td>${r.timeOnTaskSeconds != null ? `${r.timeOnTaskSeconds}s` : "—"}</td>
          <td>${formatDate(r.completedAt)}</td>
        </tr>`)
        .join("");

  const homeRows = row.home.length === 0
    ? `<tr><td colspan="5" class="empty-row">No home-mode records.</td></tr>`
    : row.home
        .sort((a, b) => new Date(b.completedAt ?? 0) - new Date(a.completedAt ?? 0))
        .map((r) => `<tr>
          <td>${escapeAttr(r.moduleId)}</td>
          <td>${r.strokeAccuracyPct != null ? `${r.strokeAccuracyPct}%` : "—"}</td>
          <td>${r.sequencingErrors ?? "—"}</td>
          <td>${r.timeOnTaskSeconds != null ? `${r.timeOnTaskSeconds}s` : "—"}</td>
          <td>${formatDate(r.completedAt)}</td>
        </tr>`)
        .join("");

  modalOverlay.innerHTML = `
    <div class="modal-card modal-wide">
      <div class="modal-header">
        <h3>${escapeAttr(row.learnerName)} — Progress (${total} records)</h3>
        <button class="modal-close" id="close-modal-btn">&times;</button>
      </div>
      <div class="modal-body">
        <h4 class="mode-section-title">Classroom Mode (${row.classroomCount})</h4>
        <div class="table-wrap" style="margin-bottom:20px;">
          <table>
            <thead><tr>
              <th>Module</th><th>Accuracy</th><th>Errors</th><th>Time on Task</th><th>Completed</th>
            </tr></thead>
            <tbody>${classroomRows}</tbody>
          </table>
        </div>
        <h4 class="mode-section-title">Home Mode (${row.homeCount})</h4>
        <div class="table-wrap">
          <table>
            <thead><tr>
              <th>Module</th><th>Accuracy</th><th>Errors</th><th>Time on Task</th><th>Completed</th>
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

  document.body.appendChild(modalOverlay);
  const closeModal = () => modalOverlay.remove();
  modalOverlay.querySelector("#close-modal-btn").addEventListener("click", closeModal);
  modalOverlay.querySelector("#close-modal-footer-btn").addEventListener("click", closeModal);
  modalOverlay.addEventListener("click", (e) => {
    if (e.target === modalOverlay) closeModal();
  });
}
