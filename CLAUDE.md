# Project Management System (Flutter + Firebase)

Product spec: there is **no `docs/SPEC.md`**. For Phases 3.5–9 the design screenshots in `design/screens/` are the spec, and the decisions below fill the gaps. Phase-by-phase plan: `docs/PLAN.md`.
This file = decisions, architecture, and build rules. If they conflict, ask me. If behaviour isn't visible in a screenshot or written here, ask — don't invent it.

## Stack (decided)
- Flutter (target: Android + Web first; Windows desktop optional)
- State management: **Riverpod** (`flutter_riverpod`, use `riverpod_annotation` only if I ask)
- Navigation: **go_router** with role-aware redirects
- Backend: **Firebase** — Auth, Cloud Firestore, Cloud Storage, FCM
- Models: plain immutable Dart classes with `fromMap` / `toMap` (add `freezed` later only if needed)
- Lints: `flutter_lints`, keep `flutter analyze` at 0 issues

## Architecture: feature-first

lib/
main.dart
app/ # app widget, router, theme, constants
core/ # shared: firebase providers, utils, widgets, error handling
features/
auth/ # login, register, auth state, role
projects/ # project CRUD, members, progress
tasks/ # task CRUD, status, subtasks, comments, help notes
chat/ # per-project chat
leave/ # leave requests + On Leave badge
notifications/ # in-app center + FCM
dashboard/ # Admin dashboard, Member "My Tasks"
reports/ # analytics, calendar, PDF export

each feature: data/ (repositories, models) · application/ (providers) · presentation/ (screens, widgets)
Rules: UI never talks to Firestore directly — only through a repository. Repositories are exposed via Riverpod providers.

## Requirements numbering
Existing code cites FR numbers (e.g. FR-2.5, FR-3.6) from a spec that isn't in the repo. Keep those references as they are. For new work, cite an FR only if it's already used in the code; otherwise write **"FR unknown"** and cite the screenshot or the decision number here instead. Never invent FR numbers or requirements. When implementing a phase, list the screenshots/decisions it covers and confirm each is satisfied before calling the phase done.

## Key decisions on the spec
1. **Hybrid role model.** At registration the user picks a default role (Admin or Member, per FR-1.1) — this decides which dashboard they land on right after login/register (FR-1.3) and is stored on `users/{uid}.defaultRole`. The role's stored/code value is exactly `"leader"` for Admin and `"member"` for Member — use `leader`, never `pm`, `pl` or `admin`, anywhere in code, Firestore fields, enum names (`UserRole.leader`), or debug output. Actual permissions are per project: `projects/{id}.members` = map `{uid: "leader" | "member"}` plus `memberIds[]` (for `array-contains` queries). A user's role inside a specific project always follows that project's `members` map, even if it differs from their `defaultRole` (e.g. an Admin added as a member on someone else's project sees that project as a Member). The home screen shows the user's projects grouped by their role in each, and a user can switch which dashboard view they're in.
   - **Note — display vs. stored terminology:** the UI shows **"Admin"** and **"Member"** to the user everywhere (buttons, toggles, labels, headers, badges, tooltips, screen titles). Internally — in code, Firestore field values, enum names (`UserRole.leader` / `UserRole.member`), variable names, route/file/folder names (`/leader/...`, `features/leader/`), rules, and debug/log output — the role stays exactly `leader` and `member`, never `admin` as a stored value. The only bridge between the two is `UserRole.label` (`leader` → "Admin", `member` → "Member"); UI code shows `role.label`, never `role.value` or `role.name`. When writing UI text, use Admin/Member; when writing code, Firestore data, or rules, use leader/member. Do not conflate the two.
2. **Login and register screen layout:** logo at top. The **register** screen then has a role toggle (Admin / Member) that sets `users/{uid}.defaultRole`. The **login** screen has **no** role toggle — the landing dashboard always comes from the account's stored `users/{uid}.defaultRole`, never from anything chosen at login. Below that: the email/password fields (plus name on register) and the primary action button. At the bottom: a link to switch between login and register ("Don't have an account? Create new account" / "Already have an account? Log in").
   - **Role values:** stored and compared as exactly `"leader"` / `"member"` (`UserRole.value` / `UserRole.fromValue`). `fromValue` is strict — any other value (missing, different casing, legacy abbreviation) is rejected, never coerced into a role.
   - **Session states** (`AuthStatus` in `auth_controller.dart`): `loading` (initial check, or signed in with the profile not yet resolved), `authenticated` (profile loaded, role known), `unauthenticated`, `profileMissing` (signed in but no `users/{uid}` doc). There is no fallback role: a missing or unreadable profile signs the user out with a message ("Account setup was not completed. Please register again." for a missing doc) and never routes to a dashboard.
   - **Routing:** while `loading`/`profileMissing`, the router holds on the splash screen (`/splash`); it redirects to `/leader/...` or `/member/...` only when `authenticated`, so login goes `/login → /splash → dashboard`. Unauthenticated users can only be on `/login` or `/register`.
   - **Registration:** `register()` creates the Auth account, writes `users/{uid}`, then sets the session from the role it wrote; the auth listener is ignored meanwhile (`_isRegistering`), so a Member lands straight on `/member/projects`. If the profile write fails, the new Auth user is deleted (sign-out fallback) and the register screen shows an error — no Auth account may exist without a profile doc.
3. **Permissions are enforced in Firestore Security Rules**, not just hidden in the UI.
   - Members: read whole project; update only tasks where `assignedTo` contains their uid, and only fields: `status`, `helpNote`, `subtasks`, `attachments`.
   - Admins (`leader`): full write on the project's tasks/members.
   - **Projects (Phase 2, in `firestore.rules`):**
     - **Read:** users listed in `memberIds`. List queries must filter `memberIds array-contains uid`.
     - **Create:** only when `users/{uid}.defaultRole == "leader"`, with `createdBy == uid`, `memberIds == [uid]`, `members[uid] == "leader"`, `status == "active"` and server timestamps.
     - **Update:** only by a project leader. `createdBy` and `createdAt` are immutable, the creator stays `"leader"`, `memberIds` must equal the keys of `members` (no duplicates), roles are only `leader`/`member`, `deadline > startDate`, name 1–100 chars, description ≤500.
     - **Delete:** only a project leader. The app also refuses while the project has tasks; rules can't count a subcollection, and Firestore never cascades.
     - **`members` and `memberIds`** are always written together, in one transaction (`ProjectRepository.addMember` / `removeMember`).
   - **Tasks (Phase 3, `projects/{pid}/tasks/{tid}`):**
     - **Read:** project members; plus a `{path=**}/tasks` collection-group rule letting anyone read tasks whose `assignedTo` contains their uid (My Tasks must filter `assignedTo array-contains uid`).
     - **Create/delete:** project leader of an active project. Create checks allowed keys, title 1–100, description ≤2000, priority/status values, `assignedTo` ⊆ project `memberIds` with no duplicates, `createdBy == uid`, server timestamps, ≤50 subtasks.
     - **Update:** a leader edits anything but `createdBy`/`createdAt` (same validation); an assignee who is still a project member may change only `status`, `helpNote`, `subtasks`, `attachments` (+ `updatedAt == request.time`), keeping the subtask count. Nothing is writable while the project is archived. Rules can't loop, so they can't prove an assignee only flipped `done` — the app only toggles it (`setSubtaskDone`, in a transaction).
     - **Admin edits never write `status`** (`TaskDraft.toMap(includeStatus: false)`), so a stale edit form can't overwrite an assignee's change; status goes through the status selector.
     - **Removing a member** also removes them from that project's tasks' `assignedTo`, in the same transaction (`ProjectRepository.removeMember`); the confirm dialog shows the count.
   - **Comments (Phase 4, `…/tasks/{tid}/comments/{cid}`):** project members read and create (`authorId == uid`, text 1–2000). The author may edit `text` (sets `editedAt`, shown as an "edited" label) or delete their own; a project leader may delete any comment on their project. No attachments until Storage is decided (decision 8) — the attach button is hidden.
   - **History (Phase 4, `…/tasks/{tid}/history/{hid}`):** project members read; create only with `who == uid` and `at == request.time`, written in the same batch/transaction as the change it records; never updated or deleted.
   - **Leave and notifications rules:** see decisions 6 and 7.
   - **Users:** any signed-in user may `get` a profile. `list` queries must set `limit <= 30` (the email search, avatar `whereIn` lookups), which makes bulk scraping harder. `emailLower`, when present, must equal `email.trim().lower()`.
   - **Deploying:** `firebase.json` points at `firestore.rules`, so `firebase deploy --only firestore:rules` works. `firestore.indexes.json` holds the My Tasks index (`firebase deploy --only firestore:indexes`). Rules emulator tests live in `firestore-tests/` (`npm install` once, then `npm test` there; needs Java 21+).
4. **Chat messages live in a subcollection** (`projects/{id}/messages`), never an array in a document. One chat per project, chat id = project id.
5. **Task comments and history** are subcollections of the task (`comments`, `history`).
6. **Leave** (Phase 6): `leaveRequests` collection; an approved request in the current date range shows the "On Leave" badge (computed on read, not stored as a flag). The badge appears wherever members are listed (Team, members section, assignee picker, chat participants) even though the screenshots don't show it.
   - **Types:** `sick | casual | emergency | other`, picked with chips (no dropdown). Labels: Sick, Casual, Emergency, Other.
   - **Allowances:** yearly, per type, in `settings/leave` (Admin-editable). Defaults: Casual 10, Sick 8, Emergency 3; Other is unlimited and has no balance. Fiscal year = calendar year, no carry-over.
   - **Day counting:** working days only — Saturday and Sunday excluded, plus dates in the Admin-editable `settings/leave.holidays` list (empty by default). A **Half day** toggle is offered only for single-day requests (0.5 days). `workingDays` is computed in the app and stored on the request.
   - **Balance:** remaining = allowance − approved days of that type in the year; pending days are shown separately and don't reduce the balance until approved.
   - **Approval:** any Admin who leads a project the requester belongs to may approve or reject (rejection reason optional). Admins can request leave too; nobody can decide their own request.
   - **Lifecycle:** `pending → approved | rejected` by an approver; `pending → cancelled` by the requester only. Decided requests are immutable.
   - **Screens:** Member Leave (stats + My requests), Request Leave, Leave detail (chevron), Admin Leave Management (Pending / History tabs). Both roles' Leave tabs can reach "Request Leave".
7. **Notifications** (Phase 8): in-app center first (Firestore `notifications`), **written by the client** in the same batch as the action that triggers it, until FCM + Cloud Functions exist. Push (FCM) and scheduled "deadline in 24h" reminders need Cloud Functions, which may need the Blaze plan — do these last and ask me before enabling anything paid.
   - **Triggers (recipient):** task assigned (new assignees) · comment on my task (assignees, not the commenter) · help requested (the chosen helper, with an **Accept** action) · help accepted (the requester) · task blocked (the project's leaders) · leave submitted (the approvers) · leave approved / rejected (the requester) · leave cancelled (the approvers) · due date changed (assignees).
   - **Rules:** create only when `actorId == uid`, `userId != uid`, and the sender shares a project with the recipient (checked via the referenced `projectId`) — or, for leave notifications, via the referenced leave request (requester ↔ approver). Recipients may read their own and update **only** `read`; nobody else can update; no deletes for now.
   - **Help accept flow:** the helper accepts from the notification tile or from a banner on the task. Accepting sets `helpNote.acceptedAt` and, **in the same batch**, writes a `help_accepted` history entry and the requester's notification. The helper must already be a project member. This needs **one narrow task-update rule**: only `helpNote.taggedUserId` may set `helpNote.acceptedAt` (= `request.time`), only while it's unset (once), changing no other field — not even `updatedAt` or other `helpNote` keys. Emulator tests (Phase 4) prove: the helper can set it once; the helper can't change any other field or set it again; other members, the requester and non-members can't set it.
8. Cloud Storage (attachments) may also need Blaze on new projects — verify in console; if unavailable, stub attachments behind a repository interface and defer.
9. **Auth security additions** (on top of decision 2).
   - **Email availability (register screen only):** Firebase email enumeration protection stays **on**, so the check never uses `fetchSignInMethodsForEmail`. Instead `emailIndex/{email}` docs (id = trimmed, lower-cased email; body exactly `{uid}`) are written in the **same batch** as `users/{uid}` by `UserRepository.create` (email signup and first Google sign-in). Rules: anyone may `get` one doc, nobody may `list`; a signed-in user may only create/update the entry whose id equals their own `request.auth.token.email.lower()`, holding their own uid; no delete. The check runs ~500ms after typing stops or on blur and shows "Checking…" / "Email already in use" / "Available" under the field. It's advisory: it **never** disables Create account, and the real registration attempt stays the source of truth (accounts created before the index existed aren't in it — accepted).
   - **Password policy (register screen):** at least 8 characters, upper **and** lower case, a number, a symbol (any non-letter/digit/whitespace) — `password_policy.dart` is the single source for both the live checklist + strength bar and the form validator. Create account stays disabled until every rule passes. The raw password is never stored, logged, or sent anywhere except `createUserWithEmailAndPassword` (no `authLog`/`debugPrint`/analytics). The login screen only checks that the password isn't empty (existing accounts may predate the policy).
   - **Google Sign-In ("Continue with Google" on login + register):** web uses `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`; Android uses `google_sign_in` 7 (`authenticate()` → idToken → `GoogleAuthProvider.credential`); hidden on other platforms. Dismissing the picker is a no-op.
     - **Returning user** (`users/{uid}` exists): same path as a password login, landing on the stored `defaultRole`.
     - **First sign-in** (no doc and the Auth user has the `google.com` provider): `AuthStatus.needsRole`; the router holds the user on `/choose-role` (nothing else reachable). Picking a role calls `completeGoogleSignup(role)`, which writes the same `users/{uid}` shape as email signup (name/email from the Google profile, `skillTags: []`) **only then** — the doc never exists without a `defaultRole`. A failed write keeps the user on the picker to retry.
     - **Cancel** on the picker (`cancelGoogleSignup`) deletes the new Auth account (sign-out fallback), keeping "no Auth account without a profile doc". If the app is killed mid-picker, the next launch returns to `/choose-role`; email/password users with no doc are still signed out with the setup-incomplete message.
     - Same email already registered with a password: for Gmail addresses Firebase links Google to the existing account (returning user); otherwise `account-exists-with-different-credential` → "Log in with your password instead."
   - **Password reset ("Forgot password?" on login):** opens `/forgot-password` (reachable only while unauthenticated, like `/login`/`/register`; signed-in users are redirected home). The email typed on login is pre-filled via go_router `extra` — **never** a query parameter, so it stays out of URLs and browser history. Sends Firebase's hosted reset email via `AuthController.sendPasswordReset` → `AuthRepository.sendPasswordResetEmail`. To avoid email enumeration, success is always the same neutral message ("If an account exists for this email, a reset link has been sent…") and `user-not-found` is treated as success; only real failures (`invalid-email`, network, `too-many-requests`) show an error. Malformed emails are rejected client-side before any request. Logs only that a reset was requested (plus the error code on failure) — never the email.

## UI design system
10. **Visual design, established in the auth screens and refined by the `design/screens/` mockups (Phase 3.5), applies app-wide going forward.**
    - **Font:** Plus Jakarta Sans, bundled as TTF assets under `assets/fonts/` with its OFL licence file (`assets/fonts/OFL.txt`), set as the theme's `fontFamily`. No `google_fonts` package.
    - **Status colours** (pill = tinted background + coloured text + leading dot), all in `AppColors` with light/dark pairs: Not Started (grey), In Progress (blue), On Hold (amber), Blocked (amber-red), Completed (green), Overdue (red); leave: Pending (blue), **Approved (blue, as in the mock — not green)**, Rejected (red), Cancelled (grey). Also `unreadTint` (light blue row background for unread notifications) and a destructive tint for Log out.
    - **Color tokens** (`lib/app/theme.dart`). Raw light/dark pairs live in `AppPalette` (`primaryLight`/`primaryDark`, `accentLight`/`accentDark`, `backgroundLight`/`backgroundDark`, `surfaceLight`/`surfaceDark`, `borderLight`/`borderDark`, `textPrimaryLight`/`textPrimaryDark`, `textSecondaryLight`/`textSecondaryDark`, `successLight`/`successDark`, `errorLight`/`errorDark`, plus `warningLight`/`warningDark`) and are referenced **only** inside `theme.dart`. Screens read them through the theme:
      - `ColorScheme.primary` — filled buttons, the selected role pill.
      - `ColorScheme.secondary` (= accent) — text links, focused field border; also `AppColors.progressFill`.
      - `scaffoldBackgroundColor` (= background); `ColorScheme.surfaceContainer` is also the background color (e.g. the role toggle track).
      - `ColorScheme.surface` — cards, dialogs, menus, field fill.
      - `ColorScheme.outline` (= border) — card/field borders, dividers; `surfaceContainerHighest` is also the border color (disabled filled buttons, strength-bar track).
      - `ColorScheme.onSurface` (= textPrimary) — primary text; `onSurfaceVariant` (= textSecondary) — hints, placeholders, field icons, secondary text.
      - `ColorScheme.error`.
      - `AppColors` (`Theme.of(context).appColors`) for roles `ColorScheme` has no slot for: `success` ("Available", met checklist rules, Good/Strong), `warning` (amber, outside the original palette — password "Fair" level and the Blocked task badge), `logoTile` (`backgroundDark` `#121826` in **both** modes, behind the logo), the sidebar/nav chrome on wide layouts (`sidebar*` — primary navy in light mode, surface `#1B2333` with a border edge in dark mode; the phone app bar is light, see decision 11), and the per-status task badge colors (`status*`).
      - Never hardcode `Colors.*` / `Color(0x…)` in screens. The only exceptions: `theme.dart` itself, Google's brand colors in `GoogleLogo` (required by Google's branding), and `Colors.transparent`.
    - **Logo:** `assets/Logo.png` (1536×1024, transparent, includes a low-contrast embedded wordmark) is shown only through `AppLogo` (`lib/core/widgets/app_logo.dart`): a rounded-square tile on `AppColors.logoTile`, cropped to the "P" mark (above the embedded wordmark) and inset from the rounded corners. Default 72px (auth header), 96px on the splash. The app name is rendered as real text (`appName` = "ProTrack" in the same file), never taken from the image. Reuse `AppLogo` everywhere the logo appears — don't re-crop or re-embed the image elsewhere. Swap its crop for a plain `Image.asset` once a tight square export exists.
    - **Layout pattern:**
      - **Header and card:** centered header (logo tile, app name in bold `headlineSmall`, muted `bodyMedium` tagline) above a card containing the form. The card shows on every screen width, phone included: max width 440, padding 32 wide / 20 narrow, 16px side gutters on phones. Cards are 16px radius, elevation 1, 1px outline border.
      - **Fields:** labels sit above each field (`labelLarge`, w600). The field has a leading icon inside it and placeholder text, 10px corner radius and surface fill. A focused field gets a 2px accent (`secondary`) border.
      - **Primary actions:** full width, min height 48, 12px corner radius, 15px w600 label, trailing arrow icon (`PrimaryButton`). Disabled filled buttons render greyed (border-color fill, secondary text) — never primary-colored.
      - **Secondary actions** (e.g. Google sign-in): full-width outlined buttons, same height and radius, surface fill, outline border.
      - **Role toggle**, where used: a rounded pill on a background-colored, outlined track. The selected side is filled with primary plus an icon (`Icons.workspace_premium` for Admin, `Icons.person` for Member); the unselected side is plain secondary text.
    - **Component reuse:**
      - **App-wide, in `lib/core/widgets/`:**
        - `AppLogo`.
        - `LabeledField` (label above a field) and `PrimaryButton` (both moved from auth in Phase 2).
        - `PillToggle<T>`: the rounded pill toggle; `RoleToggle` and the Projects All/My toggle are built on it.
        - `UserAvatar` / `AvatarStack`: initials circles coloured from `AppColors.avatarColors` by uid, overlapping, with a "+N" badge.
        - `EmptyState` / `ErrorState` (with Retry), in `state_views.dart`.
        - `DateField`: a read-only field that opens the date picker and takes part in form validation.
        - `formatDate` / `formatDateRange` in `core/utils/date_format.dart`; there's no `intl` dependency.
      - **Auth-only, in `lib/features/auth/presentation/widgets/`:**
        - `AuthScaffold` (header + card + optional `footer`), `RoleToggle` and `AuthSwitchLink`.
        - `GoogleSignInSection` (the "OR CONTINUE WITH" divider, Google button and TLS trust line, in `google_sign_in_button.dart`), with `GoogleLogo` alongside it.
      - **Added in Phase 3.5 (`lib/core/widgets/`):** `PillToggle` gains optional count badges and a compact size and doubles as the segmented tab bar (Comments (3) / History, Pending (3) / History, Light / Dark / System); `StatusPill` gains the leading dot and the new statuses; new `StatTile`, `TagChip` (+ "Add" variant), `SectionCard` (title + trailing caption such as "4 active"), `SettingsRow`, `RoleBadge` (light chip; filled for Admin on the profile header), `CountBadge` ("2 new", "3 Pending"), `InfoBanner`, `DestructiveButton` (Log out: tinted or outlined).
      - **Dashboard chrome:** `ProTrackAppBar` lives in `lib/navigation/`, because it reads auth and notification state.

      Follow the same visual language (spacing, radius, type scale) when building screens for Tasks and later phases. Put new shared widgets under `lib/core/widgets/` rather than one-off styling per screen, and move a feature widget there once something outside that feature needs it.
    - **Accessibility note:** white text on the dark-mode primary (`#5A7A9E`) is ~4.46:1 — just under the 4.5:1 guideline for small text. It's fine for bold button labels, but avoid small or thin text directly on that color.
11. **Dashboard navigation (Phase 2).**
    - **Admin tabs:** Projects, Team, Calendar, Leave, Profile (`/leader/projects|team|calendar|leave|profile`).
    - **Member tabs:** Projects, My Tasks, Leave, Profile (`/member/projects|tasks|leave|profile`). Members land on `/member/projects`.
    - **No Alerts or Analytics tabs:**
      - Notifications open from the bell in `ProTrackAppBar` (`/notifications`, one route for both roles). The unread dot reads `unreadNotificationCountProvider`, stubbed at 0 until Phase 8.
      - Analytics opens from the Admin's Profile tab (`/leader/analytics`).
    - **Profile tab** (both roles) also holds the theme switcher and Sign out.
    - **App bar (updated in Phase 3.5 to match the mockups):**
      - **Phones** (bottom nav): a light bar on the page background — the **page title** on the left (e.g. "Leave", "Team"; pushed screens add a back arrow), then the bell (with unread dot) and the avatar (opens the Profile tab). No logo, app name or search in the bar.
      - **Wide layouts** (`AdaptiveShell` sidebar): the sidebar keeps the logo + "ProTrack"; the top bar shows the page title, bell and avatar.
      - Search is deferred (see Phase 7).
    - **Profile tab (both roles):** avatar header, name with an **edit icon** (inline name editing), email, `RoleBadge`; **My skills** with editable chips and "+ Add skill" (Admins too); **Theme** Light / Dark / System (already persisted by `themeModeProvider`); **Change password** (re-authenticates with the current password; hidden for Google-only accounts; new password follows `password_policy.dart`); Admins also get an **Analytics** row; **Log out**.
    - **Team tab (Admin):** everyone in projects the Admin leads (union of their `memberIds`, excluding themselves), with search. Each row shows "n active tasks" = tasks not `completed` (Not Started, In Progress, On Hold, Blocked) across projects the Admin leads, plus the On Leave badge. A row opens **Member Profile** (`/leader/team/:uid`): skills (read-only), current tasks, and **Add to project** (picker of projects the Admin leads that the user isn't in; uses `ProjectRepository.addMember`).
    - **Task Details:** a title card (label "TASK #TSK-7F3K" from `Task.shortId`, title, status chip, project name — no sprint concept) above tabs **Details | Comments (n) | History**, Details being the default and holding the existing info card and subtasks. Tapping the status chip opens the existing status selector (when the user may change status). Comments get a composer pinned to the bottom (send only; attach hidden). History pages in with "load more".
    - **Need Help** (`…/tasks/:taskId/help`, assignees only): info banner, related-task card, required "What is blocking you?" (max 500, live counter), single-select "Who can help?" = the project's members except me and anyone on approved leave today, sorted by number of skills (most first; skills shown as subtitle), "Request Help" + caption "<name> will receive an immediate ping with this task attached."
      - Request Help sets the status to **Blocked**, writes `helpNote`, a history entry and the helper's notification. Choosing Blocked in the status selector opens Need Help instead (a reason is required). Moving the task out of Blocked clears `helpNote`.
    - **Calendar tab (Admin):** month grid (weeks start Monday, prev/next), dots on days with deadlines (red if any are overdue), and "Tasks on selected day" for all tasks in projects the Admin leads.
    - **Analytics** (`/leader/analytics`): projects the Admin leads only. Stat tiles (Projects, Completed %, Overdue, Blocked), a "Tasks by status" donut with the total in the centre (Completed, In Progress, On Hold, Blocked, and a grey **Not Started** segment), and per-project progress bars. Uses `fl_chart` (approved). No PDF export for now.
    - **Project routes:**
      - `/leader/projects/new` and `/leader/projects/:id/edit` are Admin-dashboard only.
      - `/leader/projects/:id` and `/member/projects/:id` render the same `ProjectDetailScreen`.
      - What a screen allows comes from that project's `members` map, via `ProjectPermissions`, never from the route. An Admin who is a Member of someone else's project gets the read-only view.
    - **Project display rules:**
      - The short id is `PRJ-` plus the first 4 characters of the doc id, derived and never stored.
      - Overdue is computed on read: active, deadline day passed, progress < 100.
      - Filter chips: All = non-archived, split into Active + Overdue; Archived is counted separately.
      - The Admin's "My Projects" = projects they're a member of but didn't create.
      - Progress is `computeProgress(taskStatuses)` (FR-2.5): `projectProgressProvider` reads the project's live tasks (`projectTasksProvider`); only `completed` counts as done; 0% while loading or with no tasks.

## Data model (Firestore)

users/{uid} name, email, emailLower, defaultRole(leader|member), skillTags[], photoUrl, createdAt
emailIndex/{lowercasedEmail} uid (written with users/{uid}; see decision 9)
projects/{pid} name, description, startDate, deadline, status(active|archived),
createdBy, members{uid: role}, memberIds[], createdAt, updatedAt
projects/{pid}/tasks/{tid} title, description, assignedTo[], priority(high|medium|low),
status(todo|in_progress|on_hold|blocked|completed), deadline,
helpNote{text, taggedUserId, requestedBy, createdAt, acceptedAt?}, subtasks[{title,done}],
attachments[], createdBy, createdAt, updatedAt
projects/{pid}/tasks/{tid}/comments/{cid} authorId, text, createdAt, editedAt?
projects/{pid}/tasks/{tid}/history/{hid} who, action, from?, to?, at
projects/{pid}/messages/{mid} text, senderId, createdAt, mentions[], attachments[], pinned
leaveRequests/{lid} userId, type(sick|casual|emergency|other), fromDate, toDate, halfDay,
workingDays, reason, status(pending|approved|rejected|cancelled),
approverIds[], decidedBy?, decidedAt?, rejectionReason?, createdAt
settings/leave allowances{casual, sick, emergency}, holidays[], updatedBy, updatedAt
notifications/{nid} userId, actorId, type, projectId?, taskId?, leaveId?, message, read, createdAt

Note: `helpNote` has no `taggedSkill` (dropped — the helper is always a person; their skills are shown, not stored). `helpNote` is null unless the task is Blocked.

Note: `approverIds` (and how the leave read/decision rules use it) is a Phase 6 proposal in `docs/PLAN.md`, to be confirmed at the start of that phase.

Note: `users.emailLower` (= `email.trim().toLowerCase()`) is the "Assign Team Member" prefix-search key. It's written at signup and back-filled on the next sign-in for older profiles. The query `orderBy('emailLower').startAt([q]).endAt([q+'']).limit(10)` uses Firestore's automatic single-field index, so it needs no composite index. The project list query (`memberIds array-contains uid`) is sorted in the app, so it needs no index either.

Note: tasks are a subcollection of the project (not top-level) so rules and queries stay simple. "My Tasks across all projects" is `collectionGroup('tasks').where('assignedTo', arrayContains: uid)`, sorted in the app, so it needs no composite index — only a collection-group single-field index (Arrays / array-contains) on `tasks.assignedTo`, defined in `firestore.indexes.json`.

Note — task status display vs. stored (FR-3.6): `TaskStatus.label` bridges them like `UserRole.label`: `todo` → "Not Started", `in_progress` → "In Progress", `on_hold` → "On Hold", `completed` → "Completed". `blocked` ("Blocked") is a separate "needs help" state: from Phase 4 it's in the status selector, but choosing it opens Need Help (a blocker reason is required), and leaving it clears `helpNote` (decision 11). On Hold has its own badge colors (`statusOnHold*` in `AppColors`). Overdue (computed on read): deadline day passed and not completed.

## Build phases (do ONE phase at a time, stop after each)
| # | Phase | Done when |
|---|-------|-----------|
| 0 | Scaffold: packages, folder structure, theme (light+dark), router, Firebase init, placeholder screens | `flutter run` shows a themed app; `flutter analyze` clean |
| 1 | Auth: register/login/logout, user doc, profile with skill tags, auth-gated router | I can register, log in, and stay logged in after restart |
| 2 | Projects: create/edit/archive project, add/remove members (search by email), project list with progress % | Admin creates a project and adds a member who then sees it |
| 3 | Tasks: create/edit/delete/reassign (Admin), per-task deadline + priority, status updates (assignee), overdue highlight, Member "My Tasks" screen, Firestore rules for permissions | Member can edit only their own tasks; rules verified in emulator/tests |
| 3.5 | Design pass: Plus Jakarta Sans, palette/status colours, new shared widgets, phone app bar, Profile redesign (both roles) incl. name edit, skills, theme, Change password | Screens match `design/screens/` styling in light + dark; widget tests pass |
| 4 | Blocked/Help: Need Help screen (pick a helper), status Blocked + help note, help accept flow, Task Details tabs, comments, task history (sub-tasks already done) | Blocked note visible to Admin and team; comments + history rules verified in emulator |
| 5 | Project chat: realtime messages, @mentions, pin, image/file share (if storage available) — *not in the current mockups; order TBD* | Two accounts chat in realtime, one chat per project |
| 6 | Leave + Team: request (types, half day, balances, holidays) → Admin approve/reject/cancel → On Leave badge everywhere members are listed + deadline-conflict warning; Team tab + Member Profile + Add to project; leave settings | Badge shows in members list, task assignee picker, chat participants; leave rules verified in emulator |
| 7 | Calendar of deadlines only. Kanban, search/filters, favorites are **deferred** | Calendar shows every deadline in projects I lead |
| 8 | Notifications: in-app center (client-written, decision 7) incl. help Accept action; FCM push later | Assigned task → assignee sees notification; rules verified in emulator |
| 9 | Analytics (`fl_chart`), polish, empty/error/loading states. PDF report deferred | Analytics matches the mock for projects I lead |

Build order: 3.5 → 4 → 6 → 8 → 7 → 9 (Phase 5 chat is not scheduled yet).

## Working rules for Claude Code
- Start each phase with a short plan (files to create/change) and wait for my OK.
- Small, working increments. After each step run `flutter analyze` and fix issues; run `flutter test` when tests exist.
- Each phase ships data model + repository + Firestore rules + emulator tests + UI together. A phase is **not done** until `flutter analyze` is clean, `flutter test` passes and (if rules changed) `npm test` in `firestore-tests/` passes. If any of these can't be run (e.g. no JDK 21), say so explicitly and leave the phase open.
- Never commit secrets. `firebase_options.dart` is fine to commit; service-account keys are not.
- Every screen needs loading, empty, and error states.
- Don't add packages without saying why. Prefer well-maintained ones (check pub.dev score).
- Keep widgets small; extract when a build method passes ~80 lines.
- Add unit tests for repositories' permission logic and progress-% calculation.
- Commit-ready state at the end of each phase, with a one-paragraph summary of what changed and what to test manually.
- If something needs manual setup (Firebase console, indexes, SHA-1 keys), give me exact steps instead of guessing.