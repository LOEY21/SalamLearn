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
  getDocs,
  query,
  where,
  writeBatch,
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

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginError.hidden = true;
  const email = document.getElementById("login-email").value.trim();
  const password = document.getElementById("login-password").value;
  const submitBtn = loginForm.querySelector("button[type=submit]");
  submitBtn.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err) {
    console.error("Sign-in failed:", err.code, err.message);
    loginError.textContent = describeAuthError(err);
    loginError.hidden = false;
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
  const allColumns = actions ? [...columns, { label: "" }] : columns;
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
    if (actions) {
      const td = document.createElement("td");
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "btn-danger";
      btn.textContent = actions.label ?? "Delete";
      btn.addEventListener("click", () => actions.onClick(row, btn));
      td.appendChild(btn);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  });
}

function renderStats(counts) {
  const grid = document.getElementById("stat-grid");
  const labels = {
    parents: "Parents",
    teachers: "Asatidz",
    learners: "Learners",
    classes: "Classes",
    enrollments: "Enrollments",
    progress: "Progress records",
  };
  grid.innerHTML = Object.entries(labels)
    .map(
      ([key, label]) => `
        <div class="stat-card">
          <div class="stat-value">${counts[key] ?? 0}</div>
          <div class="stat-label">${label}</div>
        </div>`
    )
    .join("");
}

async function loadAllData() {
  accessDenied.hidden = true;
  try {
    const [parents, teachers, learners, classes, enrollments, progress] =
      await Promise.all([
        fetchAll("parents"),
        fetchAll("teachers"),
        fetchAll("learners"),
        fetchAll("classes"),
        fetchAll("enrollments"),
        fetchAll("progress"),
      ]);

    renderStats({
      parents: parents.length,
      teachers: teachers.length,
      learners: learners.length,
      classes: classes.length,
      enrollments: enrollments.length,
      progress: progress.length,
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
      { label: "Remove", onClick: (row, btn) => confirmDeleteParent(row, btn) }
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
      { label: "Remove", onClick: (row, btn) => confirmDeleteTeacher(row, btn) }
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
      classes
    );

    const learnerNameById = new Map(learners.map((l) => [l.id, l.name]));
    const recentProgress = [...progress]
      .sort((a, b) => new Date(b.completedAt ?? 0) - new Date(a.completedAt ?? 0))
      .slice(0, 100);
    renderTable(
      document.getElementById("table-progress"),
      [
        { label: "Learner", value: (r) => learnerNameById.get(r.learnerId) ?? r.learnerId },
        { label: "Module", value: (r) => r.moduleId },
        { label: "Accuracy", value: (r) => (r.strokeAccuracyPct != null ? `${r.strokeAccuracyPct}%` : "—") },
        { label: "Errors", value: (r) => r.sequencingErrors },
        { label: "Time on task", value: (r) => (r.timeOnTaskSeconds != null ? `${r.timeOnTaskSeconds}s` : "—") },
        { label: "Assigned", value: (r) => (r.assignedByTeacher ? "Yes" : "No") },
        { label: "Completed", value: (r) => formatDate(r.completedAt) },
      ],
      recentProgress
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

document.getElementById("form-parent").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  form.querySelector(".form-error").hidden = true;
  const submitBtn = form.querySelector("button[type=submit]");
  const data = new FormData(form);
  submitBtn.disabled = true;
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
  } catch (err) {
    console.error(err);
    showFormError(form, describeAuthError(err) !== "Sign-in failed. Please try again." ? describeAuthError(err) : "Could not create parent — see console for details.");
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
  } catch (err) {
    console.error(err);
    showFormError(form, describeAuthError(err) !== "Sign-in failed. Please try again." ? describeAuthError(err) : "Could not create teacher — see console for details.");
  } finally {
    submitBtn.disabled = false;
  }
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
  submitBtn.disabled = true;
  try {
    await writeBatch(db)
      .set(doc(collection(db, "learners")), {
        parentId: data.get("parentId"),
        name: data.get("name").trim(),
        age: Number(data.get("age")),
        avatar: data.get("avatar").trim() || "🧒",
        gradeLevel: data.get("gradeLevel").trim() || "Grade 1",
        createdAt: new Date().toISOString(),
      })
      .commit();
    form.hidden = true;
    form.reset();
    await loadAllData();
  } catch (err) {
    console.error(err);
    showFormError(form, "Could not create learner — see console for details.");
  } finally {
    submitBtn.disabled = false;
  }
});

// ---- Cascade delete ----
// Firestore record only (no Firebase Auth account deletion — that needs an
// Admin SDK / Cloud Function, which this app doesn't have). Deleting a
// parent/teacher here removes their cloud footprint and everything that
// hangs off it; their Firebase Auth login still exists but "sign in on any
// device" will find no matching profile doc afterwards.
async function deleteDocsWhere(collectionName, field, value) {
  const snap = await getDocs(query(collection(db, collectionName), where(field, "==", value)));
  if (snap.empty) return;
  const batch = writeBatch(db);
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function cascadeDeleteLearner(learnerId) {
  await Promise.all([
    deleteDocsWhere("enrollments", "learnerId", learnerId),
    deleteDocsWhere("progress", "learnerId", learnerId),
    deleteDocsWhere("assigned_modules", "learnerId", learnerId),
  ]);
  await writeBatch(db).delete(doc(db, "learners", learnerId)).commit();
}

async function cascadeDeleteClass(classId) {
  await Promise.all([
    deleteDocsWhere("enrollments", "classId", classId),
    deleteDocsWhere("assigned_modules", "classId", classId),
  ]);
  await writeBatch(db).delete(doc(db, "classes", classId)).commit();
}

async function confirmDeleteLearner(row, btn) {
  if (!window.confirm(`Remove learner "${row.name}"? This deletes their cloud record, enrollments, progress, and assignments. This cannot be undone.`)) {
    return;
  }
  btn.disabled = true;
  try {
    await cascadeDeleteLearner(row.id);
    await loadAllData();
  } catch (err) {
    console.error(err);
    window.alert("Could not remove this learner — see console for details.");
    btn.disabled = false;
  }
}

async function confirmDeleteParent(row, btn) {
  if (!window.confirm(`Remove parent "${row.fullName}"? This also deletes their learners and everything tied to those learners. This cannot be undone.`)) {
    return;
  }
  btn.disabled = true;
  try {
    const learners = await getDocs(query(collection(db, "learners"), where("parentId", "==", row.id)));
    for (const learnerDoc of learners.docs) {
      await cascadeDeleteLearner(learnerDoc.id);
    }
    await writeBatch(db).delete(doc(db, "parents", row.id)).commit();
    await loadAllData();
  } catch (err) {
    console.error(err);
    window.alert("Could not remove this parent — see console for details.");
    btn.disabled = false;
  }
}

async function confirmDeleteTeacher(row, btn) {
  if (!window.confirm(`Remove teacher "${row.fullName}"? This also deletes their classes and related enrollments/assignments. This cannot be undone.`)) {
    return;
  }
  btn.disabled = true;
  try {
    const classes = await getDocs(query(collection(db, "classes"), where("teacherId", "==", row.id)));
    for (const classDoc of classes.docs) {
      await cascadeDeleteClass(classDoc.id);
    }
    await writeBatch(db).delete(doc(db, "teachers", row.id)).commit();
    await loadAllData();
  } catch (err) {
    console.error(err);
    window.alert("Could not remove this teacher — see console for details.");
    btn.disabled = false;
  }
}
