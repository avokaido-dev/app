# Avokaido — end-user web app

Self-serve sign-up + workspace management for Avokaido customers. Live at **https://avokaido-app.web.app**.

Separate from `avokaido_admin` (which is the internal @avokaido.com system-admin panel at `avokaido-de9e1.web.app`). Both apps share the same Firebase project `avokaido-de9e1` (Auth, Firestore, Functions, Storage).

## Flow

1. Anyone lands at `/` → redirected to `/signin` if signed out.
2. Sign in with **GitHub**, **Microsoft**, or **Apple** (OAuth via Firebase Auth).
3. First-time users have no `workspaceId` claim → redirected to `/create-workspace` → enter a name → calls `createWorkspace` cloud function → they become the org admin of the new workspace.
4. Subsequent visits land directly in `/workspace/overview` with tabs:
   - **Overview** — workspace info + downloads (reads `releases/{platform}` to expose the desktop app).
   - **Team** — invite by email (calls `sendInvite`), list members, remove members (org-admin only).
   - **Settings** — workspace name (org-admin only).

Invited users land on `/invite/{token}`, which attempts the `avokaido://claim?token=…` deep link (opens the desktop `develop_platform`) and offers a download fallback.

## One-time Firebase console setup

Three OAuth providers must be enabled before sign-in works:

1. Open https://console.firebase.google.com/project/avokaido-de9e1/authentication/providers.
2. Enable **GitHub**:
   - Register an OAuth app at https://github.com/settings/developers → callback URL is the one Firebase shows (ends in `/__/auth/handler`).
   - Paste Client ID + Secret back into Firebase.
3. Enable **Microsoft**:
   - Register an app at https://portal.azure.com → App registrations → New registration. Redirect URI = the Firebase handler URL.
   - Paste Application (client) ID + a client secret you generate.
4. Enable **Apple**:
   - Requires an Apple Developer account + Services ID + Sign in with Apple domain verification. Firebase docs: https://firebase.google.com/docs/auth/web/apple.

## Deploy

```sh
flutter build web --release
firebase deploy --only hosting:app --project avokaido-de9e1
```

Hosting target `app` → site `avokaido-app` → https://avokaido-app.web.app. Configured in `firebase.json` + `.firebaserc`.

## Related cloud functions

Defined in `../develop_platform/firebase_backend/functions/src/index.ts`:

- `createWorkspace({ name })` — self-serve workspace creation.
- `sendInvite({ email, workspaceId })` — org admins can invite their own team.
- `listWorkspaceMembers()` — returns users with matching `workspaceId`.
- `removeWorkspaceMember({ uid })` — org admin removes a member.
- `redeemInvite({ token })` — desktop client and invite landing page both call this.

## Local dev

```sh
flutter pub get
flutter run -d chrome
```

Requires you to be signed in to Firebase (`firebase login`) so `cloud_functions` calls work against the live project.
