# Principal role — design

## Purpose

Add a fourth account type, **Principal**, whose job is to observe how
Asatidz/Teachers are using and engaging with the app — not to administer
data. It is a read-only monitoring role, fully separate from the existing
admin website.

## Scope

**In scope:**
- Principal can view: every teacher, their classes, class roster sizes,
  and per-class assignment/custom-lesson activity.
- Principal can see each teacher's real login activity (last sign-in,
  account creation date) via Firebase Auth.
- Principal accounts are created only by an admin (no self-registration).

**Out of scope (explicitly deferred, not built in this pass):**
- Any create/update/delete capability for the principal — pure observation.
- Visibility into parents or learners, consent records, or progress detail
  beyond what's needed to size a class ("N students enrolled").
- Editing/removing teachers, or anything else already exclusive to the
  admin website.
- Multiple schools/orgs — this is a single-school deployment, same as the
  rest of the app; there is no school-scoping concept to add.

## Surface: a new, separate static website

Not a tab inside `admin-web/`. A new folder `principal-web/`, same stack as
`admin-web/` (plain HTML/CSS/vanilla JS, Firebase JS SDK, no build step),
deployed as its own Firebase Hosting **site** in the same Firebase project
(`salamlearn-55712`) — e.g. site id `salamlearn-principal`, giving it its
own URL (`https://salamlearn-principal.web.app`) independent of
`admin-web`'s deployment. Both sites share the same Firestore/Auth backend;
nothing about the mobile app or admin-web changes except the security rules
and (for admin) a new "Add principal" form.

`firebase.json`'s `hosting` key becomes an array with two targets instead
of one object — `admin-web`'s existing entry is preserved as-is, a second
entry points at `principal-web`. `.firebaserc` gets a `targets` mapping
tying each folder to its hosting site id via `firebase target:apply
hosting <target-name> <site-id>`.

## Data model

### New collection: `/principals/{principalId}`

Same shape as `/teachers`, minus teacher-only fields:

```
{
  fullName: string,
  email: string,
  firebaseUid: string,   // set by admin-web at creation, same pattern as teachers
  createdAt: string (ISO),
}
```

No PIN/password hash lives here (principal never has an in-app PIN flow —
this role only exists on principal-web, which is a plain Firebase
Auth email/password login, no offline-first Hive story to reconcile with).

### Admin-web: new "Add principal" form

Mirrors the existing "Add teacher" form exactly: collects full name,
email, password; creates the Firebase Auth account via the existing
`createAuthAccountWithoutSignOut` secondary-app helper (so the admin's own
session isn't kicked out); writes the `/principals/{id}` doc with the
returned `firebaseUid`. Principal rows appear in a new "Principals" tab in
admin-web with the same delete → trashbin → restore lifecycle every other
entity already has (reusing `archiveDocToTrashbinBatch` /
`archiveAndDeleteDocsWhere` / `restoreTrashItem` — those functions are
already collection-agnostic).

## Firestore security rules

New helper, same shape as `ownsTeacherDoc` but keyed directly by uid:

```
function isPrincipal() {
  return isSignedIn() &&
    exists(/databases/$(database)/documents/principals/$(request.auth.uid));
}
```

**Decision:** unlike `/teachers` and `/parents` (random doc id +
`firebaseUid` field, because self-registration means the id can't be
known ahead of time), admin-web sets a new `/principals/{id}` document's
id **equal to** the created account's Firebase Auth uid at creation time.
Principals are always admin-created, so the uid is already known before
the doc is written — this lets the rule do a direct, provably-safe
`get()` by path instead of the query-can't-prove-it problem that `/parents`
and `/teachers` explicitly work around elsewhere in this file. The doc
still keeps a `firebaseUid` field too, purely for display/consistency with
the other two collections — the rule itself doesn't need it.

Rule changes:
- `/principals/{principalId}`: `allow read` if `isAdmin()` or
  `(isSignedIn() && principalId == request.auth.uid)`; `allow create` if
  `isAdmin()` and schema-validated (new `isValidNewPrincipal()`, same
  shape as `isValidNewTeacher`); no update; `allow delete` if `isAdmin()`.
- `/teachers/{teacherId}`: add `isPrincipal()` to the existing `allow
  read` clause (currently owner-or-admin only) so a principal can list
  every teacher, not just their own.
- `/classes/{classId}`: already `allow read: if isSignedIn()` — no change
  needed, principal already qualifies.
- `/enrollments/{enrollmentId}`: add `isPrincipal()` to `allow read`
  (currently admin-or-owner) so principal-web can size each class's
  roster.
- `/assigned_modules/{assignmentId}` and `/custom_lessons/{lessonId}`: add
  `isPrincipal()` to `allow read` (currently admin-only) so principal-web
  can show per-class activity counts.
- `/progress/{progressId}`: **not** widened — out of scope, principal
  doesn't need individual learner progress, only class/teacher-level
  activity counts.

## Login-activity data: Cloud Function

Firestore has no login-timestamp field for teachers — that data only
exists in Firebase Auth (`lastSignInTime`, `creationTime`), readable only
via the Admin SDK. This is the **first** Cloud Function in this project,
so it needs:
1. Confirming the project is on the Blaze (pay-as-you-go) plan — Cloud
   Functions aren't available on Spark. **Must verify before writing
   function code**; if still on Spark, this one piece either waits for a
   plan upgrade or falls back to a Firestore-only proxy metric (most
   recent class/enrollment touch as "last active"), same as the rejected
   alternative from brainstorming.
2. A new `functions/` directory (Node.js, `firebase-functions` +
   `firebase-admin`), one callable function `getTeacherActivity`:
   - Input: list of teacher doc ids (or none = all).
   - Server-side auth check: caller must be admin or principal (looked up
     via Firestore from the function itself using the Admin SDK, not
     trusted from a client-supplied flag).
   - For each teacher, looks up their `firebaseUid` from `/teachers/{id}`,
     then `admin.auth().getUser(uid)` for
     `metadata.lastSignInTime`/`metadata.creationTime`.
   - Returns `{ teacherId, lastSignInTime, creationTime }[]`.
3. `principal-web` calls this via `httpsCallable` after the normal
   Firestore reads, to enrich the teacher table with real login data.

## principal-web pages

1. **Login** — email/password via Firebase Auth (separate `initializeApp`
   config, same Firebase project). On success, checks
   `/principals/{uid}` exists; if not, sign out immediately and show
   "Not a recognized principal account."
2. **Teacher roster** (landing page after login) — table of every
   teacher: name, school, # classes owned, # students across those
   classes, # assignments + custom lessons created, last login (from the
   Cloud Function; shows "—" if the function call fails/pending).
3. **Teacher drill-in** — click a row to see that teacher's classes
   individually: class name/grade/section, roster size, invitation code
   status, per-class assignment/custom-lesson count. Read-only — no
   action buttons at all (no delete/restore/edit anywhere on this site).

## Testing

- Firestore rules: extend the existing rules test approach (if any) or
  manually verify via the Firebase console's Rules Playground for the new
  `isPrincipal()` paths before deploying, same as any other rules change
  in this project.
- Cloud Function: a local emulator smoke test (`firebase emulators:start
  --only functions,firestore,auth`) calling `getTeacherActivity` with a
  seeded principal + teacher, confirming both the auth check and the
  returned timestamps.
- principal-web: manual pass through login → roster → drill-in against
  the emulator or a staging teacher account, mirroring how admin-web
  changes have been hand-verified in this project so far (no existing
  admin-web test suite to extend).

## Deployment

Two independent `firebase deploy` targets going forward:
- `firebase deploy --only hosting:admin-web` (unchanged behavior, just
  now needs the target name since hosting becomes multi-site)
- `firebase deploy --only hosting:principal-web` (new)
- `firebase deploy --only firestore:rules` (shared, unchanged trigger)
- `firebase deploy --only functions` (new, first time this repo has any)
