import {
  initializeApp,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  getFirestore,
  doc,
  getDoc,
  collection,
  getDocs,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

// Same public web config as admin-web/app.js and prjct/lib/firebase_options.dart's
// `web` block — safe to expose client-side; access is enforced by firestore.rules.
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

async function fetchAll(name) {
  const snap = await getDocs(collection(db, name));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function renderTable(tableEl, columns, rows, onRowClick) {
  if (rows.length === 0) {
    tableEl.innerHTML = `
      <thead><tr>${columns.map((c) => `<th>${c.label}</th>`).join("")}</tr></thead>
      <tbody><tr class="empty-row"><td colspan="${columns.length}">No records yet.</td></tr></tbody>
    `;
    return;
  }
  tableEl.innerHTML = `<thead><tr>${columns.map((c) => `<th>${c.label}</th>`).join("")}</tr></thead><tbody></tbody>`;
  const tbody = tableEl.querySelector("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    if (onRowClick) {
      tr.classList.add("clickable-row");
      tr.addEventListener("click", () => onRowClick(row));
    }
    columns.forEach((c) => {
      const td = document.createElement("td");
      td.textContent = c.value(row) ?? "—";
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

export function showLoading(message) {
  loadingMessage.textContent = message || "Please wait...";
  loadingOverlay.hidden = false;
}

export function hideLoading() {
  loadingOverlay.hidden = true;
}

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
    default:
      return "Sign-in failed. Please try again.";
  }
}

async function loadTeacherRoster() {
  const [teachers, classes, enrollments, assignedModules, customLessons] = await Promise.all([
    fetchAll("teachers"),
    fetchAll("classes"),
    fetchAll("enrollments"),
    fetchAll("assigned_modules"),
    fetchAll("custom_lessons"),
  ]);

  const classesByTeacherId = new Map();
  classes.forEach((c) => {
    const list = classesByTeacherId.get(c.teacherId) ?? [];
    list.push(c);
    classesByTeacherId.set(c.teacherId, list);
  });

  const rows = teachers.map((teacher) => {
    const ownClasses = classesByTeacherId.get(teacher.id) ?? [];
    const ownClassIds = new Set(ownClasses.map((c) => c.id));
    const studentCount = enrollments.filter((e) => ownClassIds.has(e.classId)).length;
    const activityCount =
      assignedModules.filter((a) => ownClassIds.has(a.classId)).length +
      customLessons.filter((l) => ownClassIds.has(l.classId)).length;
    return {
      ...teacher,
      classCount: ownClasses.length,
      studentCount,
      activityCount,
      _ownClasses: ownClasses,
      _enrollments: enrollments,
      _assignedModules: assignedModules,
      _customLessons: customLessons,
    };
  });

  renderTable(
    document.getElementById("table-teachers"),
    [
      { label: "Name", value: (r) => r.fullName },
      { label: "School", value: (r) => r.school },
      { label: "Classes", value: (r) => r.classCount },
      { label: "Students", value: (r) => r.studentCount },
      { label: "Assignments + Lessons", value: (r) => r.activityCount },
    ],
    rows,
    (row) => showTeacherDetail(row)
  );
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
  } finally {
    submitBtn.disabled = false;
  }
});

signoutBtn.addEventListener("click", () => signOut(auth));

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    loginView.hidden = false;
    dashboardView.hidden = true;
    loginForm.reset();
    return;
  }
  // A principal doc's id is always the account's own uid (see
  // firestore.rules' PRINCIPAL MONITORING note) — a direct get() by
  // that known path is allowed to any signed-in user reading their own
  // uid-path, whether or not the doc exists, so `.exists()` alone (not
  // a caught permission-denied) is the real "not a principal" signal.
  const principalDoc = await getDoc(doc(db, "principals", user.uid));
  if (!principalDoc.exists()) {
    accessDenied.hidden = false;
    loginView.hidden = true;
    dashboardView.hidden = false;
    whoami.textContent = user.email ?? "";
    return;
  }
  accessDenied.hidden = true;
  loginView.hidden = true;
  dashboardView.hidden = false;
  whoami.textContent = user.email ?? "";
  try {
    await loadTeacherRoster();
  } catch (err) {
    console.error("Failed to load teacher roster:", err);
    accessDenied.hidden = false;
  }
});
