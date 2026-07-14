# Principal Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only "Principal" account type, served by its own new static website (`principal-web/`), that lets a principal see every teacher, their classes/rosters, and activity counts — with zero write access anywhere.

**Architecture:** New `/principals/{uid}` Firestore collection (doc id == the account's own Firebase Auth uid, since principals are always admin-created and the uid is known up front — unlike `/parents`/`/teachers`, which use random ids + a `firebaseUid` field because self-registration means the uid isn't known at doc-creation time). Firestore rules gain an `isPrincipal()` helper and widen read-only access to `/teachers`, `/enrollments`, `/assigned_modules`, `/custom_lessons` for principals (classes/progress rules are untouched — classes are already `isSignedIn()`-readable, progress stays out of scope). Admin-web gets a new "Add principal" tab reusing its existing account-creation/trashbin machinery. `principal-web/` is a new vanilla HTML/CSS/JS static site (same stack as `admin-web/`), deployed as a second Firebase Hosting site in the same project.

**Tech Stack:** Firebase JS SDK v10 (ESM, no bundler) for the two static sites, Firestore Security Rules, Firebase Hosting multi-site.

**Cut from scope (2026-07-14):** Task 4's Cloud Function for real Firebase Auth login-activity (`lastSignInTime`) was dropped — it requires the Blaze (pay-as-you-go) plan, and the project is on Spark. The project owner chose to ship without login-activity data rather than upgrade billing. `principal-web` shows teacher/class/roster/activity-count stats only, no last-login timestamp. Tasks 5-7 below are adjusted accordingly (no `getTeacherActivity` calls, no "Last Login" column, no functions deploy step). If Blaze is enabled later, `getTeacherActivity` can be reintroduced as we originally designed it — the scaffold code was already written once and is straightforward to redo.

---

### Task 1: Firestore rules — `/principals` collection + widened reads

**Files:**
- Modify: `prjct/firestore.rules`

- [ ] **Step 1: Add the `isPrincipal()` helper and `isValidNewPrincipal()` validator**

Add right after the existing `isValidNewLearner()` function (currently the last function before the `match /{document=**}` block):

```
    // Admin-created principal doc — mirrors isValidNewTeacher/isValidNewParent's
    // shape, minus school/mobile (see isValidNewPrincipal doc at the /principals
    // match block for why the doc id itself matters here, unlike those two).
    function isValidNewPrincipal(data) {
      return data.keys().hasOnly(['fullName', 'email', 'firebaseUid', 'createdAt']) &&
        data.keys().hasAll(['fullName', 'email', 'firebaseUid', 'createdAt']) &&
        data.fullName is string && data.fullName.size() > 0 && data.fullName.size() < 100 &&
        isValidEmail(data.email) &&
        data.firebaseUid is string && data.firebaseUid != request.auth.uid &&
        isValidDateString(data.createdAt);
    }

    // A principal is read-only across teachers/classes/enrollments/
    // assignments/custom-lessons (see PRINCIPAL MONITORING note below) —
    // never parents, learners, or progress; those stay out of scope.
    function isPrincipal() {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/principals/$(request.auth.uid));
    }
```

- [ ] **Step 2: Add the `/principals/{principalId}` match block**

Add it directly after the `/learners/{learnerId}` block (before the `// Read is open to any signed-in account` comment that precedes `/classes/{classId}`):

```
    // PRINCIPAL MONITORING: a principal observes teacher usage/engagement
    // (admin-web's "Add principal" form) but never creates/edits/deletes
    // anything itself. Unlike /parents and /teachers, the doc id here is
    // set equal to the account's own Firebase Auth uid at creation time
    // (principals are always admin-created, so the uid is already known),
    // which lets `isPrincipal()` do a direct, provably-safe `get()` by
    // path instead of a query Firestore can't statically verify.
    match /principals/{principalId} {
      allow read: if isAdmin() || (isSignedIn() && principalId == request.auth.uid);
      allow create: if isAdmin() && principalId == request.resource.data.firebaseUid &&
        isValidNewPrincipal(request.resource.data);
      allow update: if false;
      allow delete: if isAdmin();
    }
```

- [ ] **Step 3: Widen `/teachers` read to include principals**

In the existing `/teachers/{teacherId}` block, change:

```
      allow read: if isAdmin() || (isSignedIn() && (resource == null || resource.data.firebaseUid == request.auth.uid));
```

to:

```
      allow read: if isAdmin() || isPrincipal() || (isSignedIn() && (resource == null || resource.data.firebaseUid == request.auth.uid));
```

- [ ] **Step 4: Widen `/enrollments` read to include principals**

In the existing `/enrollments/{enrollmentId}` block, change:

```
      allow read: if isAdmin() ||
        ownsTeacherDoc(get(/databases/$(database)/documents/classes/$(resource.data.classId)).data.teacherId) ||
        ownsParentDoc(get(/databases/$(database)/documents/learners/$(resource.data.learnerId)).data.parentId);
```

to:

```
      allow read: if isAdmin() || isPrincipal() ||
        ownsTeacherDoc(get(/databases/$(database)/documents/classes/$(resource.data.classId)).data.teacherId) ||
        ownsParentDoc(get(/databases/$(database)/documents/learners/$(resource.data.learnerId)).data.parentId);
```

- [ ] **Step 5: Widen `/assigned_modules` and `/custom_lessons` read to include principals**

In `/assigned_modules/{assignmentId}`, change `allow read: if isAdmin();` to:

```
      allow read: if isAdmin() || isPrincipal();
```

In `/custom_lessons/{lessonId}`, change `allow read: if isAdmin();` to:

```
      allow read: if isAdmin() || isPrincipal();
```

- [ ] **Step 6: Verify the rules file still compiles**

Run: `firebase deploy --only firestore:rules --dry-run` — flag `--dry-run` isn't actually supported by this CLI version for rules, so instead just run the compile check the CLI already does at the start of a real deploy without completing it:

Run: `firebase deploy --only firestore:rules`
Expected output includes: `+  cloud.firestore: rules file prjct/firestore.rules compiled successfully` followed by a successful release. If it fails to compile, fix the syntax before continuing — do not proceed to Task 2 with broken rules deployed.

- [ ] **Step 7: Commit**

```bash
git add prjct/firestore.rules
git commit -m "Add Principal role rules: /principals collection + read-only teacher/enrollment/assignment/lesson access"
```

---

### Task 2: Firebase Hosting — second site for `principal-web`

**Files:**
- Modify: `firebase.json`
- Modify: `.firebaserc`
- Create: `principal-web/index.html`
- Create: `principal-web/style.css`
- Create: `principal-web/app.js`

- [ ] **Step 1: Create the second Hosting site**

Run: `firebase hosting:sites:create salamlearn-principal`
Expected: `Site salamlearn-principal has been created in project salamlearn-55712... URL: https://salamlearn-principal.web.app`

- [ ] **Step 2: Wire up hosting targets**

Run these two commands (creates the `targets` block in `.firebaserc`):

```bash
firebase target:apply hosting admin-web salamlearn-55712
firebase target:apply hosting principal-web salamlearn-principal
```

Expected: `.firebaserc` now contains a `"targets"` key mapping both names to their site ids. Read the file back to confirm before continuing.

- [ ] **Step 3: Update `firebase.json`'s `hosting` key to an array with both targets**

Replace the current single-object `hosting` key:

```json
{
  "firestore": {
    "rules": "prjct/firestore.rules"
  },
  "hosting": {
    "public": "admin-web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**",
      "(t.innerHTML",
      "batch.delete(d.ref))"
    ]
  }
}
```

with:

```json
{
  "firestore": {
    "rules": "prjct/firestore.rules"
  },
  "hosting": [
    {
      "target": "admin-web",
      "public": "admin-web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**",
        "(t.innerHTML",
        "batch.delete(d.ref))"
      ]
    },
    {
      "target": "principal-web",
      "public": "principal-web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ]
    }
  ]
}
```

- [ ] **Step 4: Create the principal-web skeleton — login-only page**

Create `principal-web/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>SalamLearn Principal</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <!-- Login -->
  <section id="login-view" class="view login-view">
    <div class="login-card">
      <div class="brand">
        <div class="brand-badge">SL</div>
        <div>
          <h1>SalamLearn</h1>
          <p class="brand-sub">Principal Monitoring</p>
        </div>
      </div>
      <form id="login-form">
        <label>
          Email
          <input type="email" id="login-email" autocomplete="username" required />
        </label>
        <label>
          Password
          <input type="password" id="login-password" autocomplete="current-password" required />
        </label>
        <button type="submit" class="btn-primary">Sign in</button>
        <p id="login-error" class="error-text" hidden></p>
      </form>
      <p class="login-note">
        Access is limited to accounts explicitly granted principal rights.
        Signing in with any other account will show no data.
      </p>
    </div>
  </section>

  <!-- Dashboard -->
  <section id="dashboard-view" class="view dashboard-view" hidden>
    <header class="topbar">
      <div class="brand brand-compact">
        <div class="brand-badge">SL</div>
        <span>SalamLearn Principal</span>
      </div>
      <div class="topbar-actions">
        <span id="whoami" class="whoami"></span>
        <button id="signout-btn" class="btn-ghost">Sign out</button>
      </div>
    </header>

    <main class="content">
      <div id="access-denied" class="banner-error" hidden>
        Signed in, but this account has no principal access. Ask an admin to
        create a principal account for this email in the admin website.
      </div>

      <section id="teacher-roster-view">
        <div class="panel-head">
          <h2>Teachers</h2>
        </div>
        <div class="table-wrap"><table id="table-teachers"></table></div>
      </section>

      <section id="teacher-detail-view" hidden>
        <div class="panel-head">
          <button id="back-to-roster-btn" class="btn-ghost btn-small">&larr; Back to teachers</button>
          <h2 id="teacher-detail-name"></h2>
        </div>
        <div class="table-wrap"><table id="table-teacher-classes"></table></div>
      </section>
    </main>

    <div id="loading-overlay" class="loading-overlay" hidden>
      <p id="loading-message" class="loading-message">Please wait...</p>
    </div>
    <div id="toast-container" class="toast-container"></div>
  </section>

  <script type="module" src="app.js"></script>
</body>
</html>
```

- [ ] **Step 5: Copy the shared visual style from admin-web**

Run: `cp admin-web/style.css principal-web/style.css`

This reuses the exact same design tokens/components (login card, tabs-less topbar still uses `.topbar`/`.brand`/`.btn-primary`/`.btn-ghost`/`.table-wrap` classes already defined there) so the two sites look like one product family. No edits needed yet — later tasks only add table-specific rules if something doesn't already exist.

- [ ] **Step 6: Create the login-only `app.js`**

Create `principal-web/app.js`:

```javascript
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
});
```

- [ ] **Step 7: Deploy both hosting targets and manually verify the login page**

Run: `firebase deploy --only hosting:admin-web,hosting:principal-web`
Expected: two `Hosting URL` lines in the output, one per site, both `Deploy complete!`.

Open `https://salamlearn-principal.web.app` in a browser and confirm the login form renders (no console errors). Do not sign in yet — there's no principal account to sign in with until Task 3.

- [ ] **Step 8: Commit**

```bash
git add firebase.json .firebaserc principal-web/
git commit -m "Add principal-web: second Hosting site with a login-only shell"
```

---

### Task 3: Admin-web — "Add principal" tab

**Files:**
- Modify: `admin-web/index.html`
- Modify: `admin-web/app.js`

- [ ] **Step 1: Add the "Principals" tab button and panel to `index.html`**

In the `<nav id="tabs">` block, add a new tab button right after Asatidz:

```html
        <button class="tab-btn" data-tab="teachers">Asatidz</button>
        <button class="tab-btn" data-tab="principals">Principals</button>
```

Add a new `<section>` right after the `tab-teachers` section closes (before `tab-learners` opens):

```html
      <section id="tab-principals" class="tab-panel" hidden>
        <div class="panel-head">
          <h2>Principals</h2>
          <button class="btn-primary btn-small" data-open-form="principal">+ Add principal</button>
        </div>
        <form id="form-principal" class="add-form" hidden>
          <label>Full name <input type="text" name="fullName" required /></label>
          <label>Email <input type="email" name="email" required /></label>
          <label>Password <input type="password" name="password" minlength="6" required /></label>
          <div class="form-actions">
            <button type="submit" class="btn-primary btn-small">Create</button>
            <button type="button" class="btn-ghost btn-small" data-cancel-form="principal">Cancel</button>
          </div>
          <p class="form-error error-text" hidden></p>
        </form>
        <div class="table-search-wrap"><input class="table-search" data-table="table-principals" type="search" placeholder="Search principals..." /></div>
        <div class="table-wrap"><table id="table-principals"></table></div>
      </section>
```

- [ ] **Step 2: Confirm the generic form open/cancel wiring covers the new form**

Read `admin-web/app.js`'s handlers for `data-open-form`/`data-cancel-form` (search for `data-open-form` — they're generic, driven entirely by the `data-open-form`/`data-cancel-form` attribute value, so no per-entity code is needed there). Run:

`grep -n "data-open-form" admin-web/app.js`

Expected: a single generic `document.querySelectorAll('[data-open-form]')`-style handler with no hardcoded entity list. If it's generic (it is, per the existing parent/teacher/learner forms already working this way), no change needed here — just confirms Step 1 is sufficient for the button to work.

- [ ] **Step 3: Add the principal creation submit handler**

In `admin-web/app.js`, add this right after the existing `form-teacher` submit handler (after its closing `});`):

```javascript
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
```

- [ ] **Step 4: Add principals to `loadAllData` and its table render**

In `admin-web/app.js`'s `loadAllData` function, add `"principals"` to the parallel fetch list:

```javascript
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
```

Right after the existing `table-teachers` `renderTable(...)` call inside `loadAllData`, add:

```javascript
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
```

- [ ] **Step 5: Add the delete-with-trashbin handler**

Add this right after `confirmDeleteTeacher` (reuses the same `archiveDocToTrashbinBatch` helper already defined above it — principals have no dependent data to cascade, unlike parents/teachers/classes):

```javascript
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
```

- [ ] **Step 6: Add "principals" to the trashbin's detail-label switch**

In `getTrashDetails`'s `switch (row.collection)`, add a case right after `case "teachers":` (it already falls through to the same `fullName (email)` format):

```javascript
    case "parents":
    case "teachers":
    case "principals":
      return `${d.fullName || ""} (${d.email || ""})`;
```

(This replaces the existing `case "parents": case "teachers":` pair — just add `case "principals":` as a third fallthrough label into the same case.)

- [ ] **Step 7: Manually verify in the browser**

Run: `firebase deploy --only hosting:admin-web`

Open `https://salamlearn-55712.web.app`, sign in as an existing admin, click the new "Principals" tab, click "+ Add principal", fill in a test name/email/password, submit. Confirm:
1. A toast reads "Principal created successfully".
2. The new row appears in the Principals table.
3. In the Firebase console (or via `firebase firestore:get` — actually use the console, this project has no CLI data-read shortcut set up), confirm the new `/principals/{uid}` document's id matches the "Reset Password" flow's target account's uid (Firebase Console → Authentication tab, find the email, compare uid to the Firestore doc id).
4. Click "Remove" on the test principal, confirm it disappears from the table and a matching `principals_<uid>` doc appears under Trashbin.

- [ ] **Step 8: Commit**

```bash
git add admin-web/index.html admin-web/app.js
git commit -m "Add principal account creation/removal to admin-web"
```

---

### Task 4: CUT FROM SCOPE — Cloud Function for login activity

**Status: not implemented.** This task originally added a `getTeacherActivity`
Cloud Function (Admin SDK lookup of each teacher's Firebase Auth
`lastSignInTime`/`creationTime`). Implementing it revealed the project is on
the Firebase Spark (free) plan, and Cloud Functions require Blaze
(pay-as-you-go). The project owner chose to ship principal-web without
login-activity data rather than upgrade billing (2026-07-14).

Nothing was deployed or committed for this task — a scaffold was written and
then deleted along with the revert of `firebase.json`'s `functions` entry.
Tasks 5-7 below have been adjusted to not depend on this function (no
`getTeacherActivity` calls, no "Last Login" column, no functions deploy step).

**To reintroduce later:** if Blaze gets enabled, the original function code
(callable `getTeacherActivity`, admin-or-principal check via Firestore,
per-teacher `auth.getUser()` lookup) is straightforward to rebuild from this
plan's git history (see the version of this file before 2026-07-15) or from
scratch following the same shape.

---

### Task 5: principal-web — teacher roster with activity counts

**Files:**
- Modify: `principal-web/app.js`

- [ ] **Step 1: Add the Firestore imports and shared helpers**

At the top of `principal-web/app.js`, extend the existing import block:

```javascript
import {
  getFirestore,
  doc,
  getDoc,
  collection,
  getDocs,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
```

(No Functions import — Task 4's `getTeacherActivity` Cloud Function was cut from scope, see that task's note. Login activity isn't shown.)

Add these two helpers (same as `admin-web/app.js`'s, needed for the table):

```javascript
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
```

- [ ] **Step 2: Add the roster-loading function**

```javascript
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
```

- [ ] **Step 3: Wire roster loading into the sign-in flow**

In the `onAuthStateChanged` callback from Task 2, replace the line `whoami.textContent = user.email ?? "";` (the second occurrence, in the "principal recognized" branch after `accessDenied.hidden = true;`) with:

```javascript
  whoami.textContent = user.email ?? "";
  try {
    await loadTeacherRoster();
  } catch (err) {
    console.error("Failed to load teacher roster:", err);
    accessDenied.hidden = false;
  }
```

- [ ] **Step 4: Manually verify**

Run: `firebase deploy --only hosting:principal-web`

Sign in at `https://salamlearn-principal.web.app` with the principal account created in Task 3. Confirm the teacher table renders with real numbers for at least one existing teacher account (classes/students/activity counts matching what's visible in admin-web's own Asatidz tab for the same teacher).

- [ ] **Step 5: Commit**

```bash
git add principal-web/app.js
git commit -m "Add teacher roster with activity counts and login data to principal-web"
```

---

### Task 6: principal-web — teacher drill-in detail view

**Files:**
- Modify: `principal-web/app.js`

- [ ] **Step 1: Add the detail-view render function**

```javascript
function showTeacherDetail(teacherRow) {
  document.getElementById("teacher-roster-view").hidden = true;
  const detailView = document.getElementById("teacher-detail-view");
  detailView.hidden = false;
  document.getElementById("teacher-detail-name").textContent = teacherRow.fullName;

  const classRows = teacherRow._ownClasses.map((cls) => {
    const roster = teacherRow._enrollments.filter((e) => e.classId === cls.id);
    const activity =
      teacherRow._assignedModules.filter((a) => a.classId === cls.id).length +
      teacherRow._customLessons.filter((l) => l.classId === cls.id).length;
    return {
      name: cls.name,
      gradeLevel: cls.gradeLevel,
      section: cls.section,
      studentCount: roster.length,
      activityCount: activity,
      invitationCode: cls.invitationCode,
    };
  });

  renderTable(
    document.getElementById("table-teacher-classes"),
    [
      { label: "Class", value: (r) => r.name },
      { label: "Grade", value: (r) => r.gradeLevel },
      { label: "Section", value: (r) => r.section },
      { label: "Students", value: (r) => r.studentCount },
      { label: "Assignments + Lessons", value: (r) => r.activityCount },
      { label: "Invitation Code", value: (r) => r.invitationCode },
    ],
    classRows
  );
}

document.getElementById("back-to-roster-btn").addEventListener("click", () => {
  document.getElementById("teacher-detail-view").hidden = true;
  document.getElementById("teacher-roster-view").hidden = false;
});
```

- [ ] **Step 2: Manually verify**

Run: `firebase deploy --only hosting:principal-web`

Sign in, click a teacher row, confirm the detail view shows that teacher's classes with correct per-class student/activity counts, and "Back to teachers" returns to the roster table.

- [ ] **Step 3: Commit**

```bash
git add principal-web/app.js
git commit -m "Add teacher class drill-in view to principal-web"
```

---

### Task 7: Final end-to-end pass

- [ ] **Step 1: Full deploy of everything touched by this feature**

```bash
firebase deploy --only firestore:rules,hosting:admin-web,hosting:principal-web
```

Expected: all three deploy steps report success. (No `functions` target — Task 4 was cut from scope.)

- [ ] **Step 2: Walk the whole flow once, start to finish**

1. In admin-web, create a fresh test principal account.
2. Sign into `principal-web` with it — confirm the teacher roster loads with real counts (no login-timestamp column, per the Task 4 scope cut).
3. Drill into a teacher with at least one class that has students and at least one assignment/custom lesson — confirm the numbers match what admin-web / the Flutter teacher dashboard show for that same class.
4. In admin-web, remove the test principal — confirm it moves to Trashbin and (if you sign out and back in as that same account in principal-web) principal-web now shows "Access is limited to accounts explicitly granted principal rights" instead of the roster.
5. Restore the test principal from admin-web's Trashbin — confirm principal-web grants access again on the next sign-in.

- [ ] **Step 3: Update `prjct/CLAUDE.md` or root docs if this repo tracks deployed surfaces there**

Check: `grep -rn "admin-web" CLAUDE.md prjct/CLAUDE.md 2>/dev/null`. If either file documents `admin-web` as a deployed surface, add a one-line mention of `principal-web` alongside it for future-you's sake. If neither file mentions hosting/deployment at all, skip this step — don't introduce a new documentation convention that isn't already there.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "Principal role: verified end-to-end (create/monitor/remove/restore)"
```
