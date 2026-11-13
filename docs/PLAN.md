# ProTrack build plan (Phases 4 – 9)

> **ADD-ONLY RULE:** never modify or delete files that exist in origin/main. New screens go in new files using the existing theme and widgets. The only allowed edits to existing files are additive (new routes, rules for new collections, pubspec dependencies), each shown to me as a diff and approved first. CLAUDE.md is read-only.
>
> **Exceptions (approved 2026-11-13):**
> - **Placeholders are unfinished work.** The `build` body of a placeholder screen may be replaced (Notifications, Analytics, Calendar, Leave Management, Team, member Leave). Its file name, class name, constructor and route stay exactly as they are. The diff is shown before the edit.
> - **Task Details** (`task_detail_screen.dart`) gets exactly one addition: an entry button that opens the new Comments / History screen. The diff is shown before the edit.
> - **Profile** (`profile_screen.dart`, `profile_settings_section.dart`, `skill_tags_editor.dart`) is built and is **not touched**. See "Profile: mock vs. current" below.

Source of truth: `design/screens/*.jpg` (screenshots = spec) plus the decisions in `CLAUDE.md`. Requirements not cited in existing code are marked **FR unknown**.

Build order: **4 → 6 → 8 → 7 → 9**. One phase at a time; each ships model + repository + Firestore rules for new collections + emulator tests + UI, and is done only when `flutter analyze`, `flutter test` and `firestore-tests` `npm test` all pass. Every new screen is also added to the dev preview (`lib/dev_preview/`). Any edit to an existing file is shown as a diff first. Stop after each phase.

Environment: Flutter 3.47.1 / Dart 3.13.1 at `C:\src\flutter`. Rules tests need **JDK 21**: Temurin 21.0.13 at `C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot` (set `JAVA_HOME` to it if Java 8 is picked up). Verified 2026-11-13: `firestore-tests` `npm test` → 30 passing.

Apart from the exceptions above, existing screens, repositories, models and widgets stay exactly as they are. New screens are reached through **new** routes. Adding each route to `lib/routing/app_router.dart` is an additive diff, shown for approval first.

---

## Screen checklist

Mock files are in `design/screens/`. Status values: Not started → In progress → Done (analyze + tests + rules tests pass, and the screen is in the dev preview).

| Screen | Mock file | New or placeholder | Phase | Status |
|---|---|---|---|---|
| Task Comments + Task History (tabs "Comments (n)" / "History") | `01_member_task_notif_profile.jpg` | **New** screen + new route under the task; one entry button added to existing Task Details | 4 | Done (see Phase 4 notes) |
| Need Help (opened from Comments/History) | `02_member_leave_help.jpg` | **New** screen + new route | 4 | Done (see Phase 4 notes) |
| Leave (member) | `02_member_leave_help.jpg` | **Placeholder**: `RequestLeaveScreen` (`features/member/screens/request_leave_screen.dart`, `/member/leave`) | 6 | Done (see Phase 6 notes) |
| Leave Detail (Cancel while pending) | none (decided 2026-11-13) | **New** screen + new route | 6 | Done (see Phase 6 notes) |
| Request Leave | `02_member_leave_help.jpg` | **New** screen + new route; class `LeaveRequestFormScreen` (`RequestLeaveScreen` is already the placeholder's name) | 6 | Done (see Phase 6 notes) |
| Leave Management (admin) | `03_admin_leave_notif_analytics_profile.jpg` | **Placeholder**: `LeaveRequestsScreen` (`features/leader/screens/leave_requests_screen.dart`, `/leader/leave`) | 6 | Done (see Phase 6 notes) |
| Team | `04_admin_team_calendar.jpg` | **Placeholder**: `TeamMembersScreen` (`features/leader/screens/team_members_screen.dart`, `/leader/team`) | 6 | Done (see Phase 6 notes) |
| Member Profile (opened from Team) | `04_admin_team_calendar.jpg` | **New** screen + new route `/leader/team/:uid` | 6 | Done (see Phase 6 notes) |
| Notifications (member + admin) | `01_member_task_notif_profile.jpg`, `03_admin_leave_notif_analytics_profile.jpg` | **Placeholder**: `NotificationsScreen` (`features/common/notifications_screen.dart`, `/notifications`) | 8 | Not started |
| Calendar | `04_admin_team_calendar.jpg` | **Placeholder**: `CalendarScreen` (`features/leader/screens/calendar_screen.dart`, `/leader/calendar`) | 7 | Not started |
| Analytics | `03_admin_leave_notif_analytics_profile.jpg` | **Placeholder**: `AnalyticsScreen` (`features/leader/screens/analytics_screen.dart`, `/leader/analytics`) | 9 | Not started |
| Profile (member + admin) | `01_member_task_notif_profile.jpg`, `03_admin_leave_notif_analytics_profile.jpg` | **Existing, built. Not touched** (gaps listed below for your decision) | — | Built |

---

## Phase 4 — Comments, history, Need Help (FR unknown; screenshots 01, 02)

**Model** (new files in `features/tasks/data/`)
- `TaskComment {id, authorId, text, createdAt, editedAt?}`.
- `TaskHistoryEntry {id, who, action, from?, to?, at}`.

**Repository** (new files)
- `TaskActivityRepository`: `watchComments`, `addComment`, `editComment`, `deleteComment`, `watchHistory(limit)` (paged), `addHistory`.
- `HelpRequestRepository` (or a method on the new repository): writes `helpNote {text, taggedUserId?, taggedSkill?}` through a new code path. The existing `TaskRepository` stays untouched.

**Rules** (additive, approved diff to `firestore.rules`): new `comments` and `history` subcollection matches, as in CLAUDE.md decision 3. `helpNote` is already writable by assignees under the existing task rules.

**UI** (new files)
- Task activity screen: header (task id, title, status pill, project / sprint line), `PillToggle` tabs "Comments (n)" / "History", comment list with author avatar + role badge + time, composer with send (the attach icon is a stub until Storage exists), history list with "load more".
- Need Help screen: info banner, related-task card, "What is blocking you?" (required, character counter), "Who can help?" list of the task's project members except me, least busy first (fewest active tasks), skill tags as subtitle (radio select; from Phase 6, people on approved leave today are excluded), sending sets the task to Blocked, Request Help button + "<name> will receive an immediate ping" caption.
- Widgets: `CommentTile`, `CommentComposer`, `HistoryTile`, `HelperOptionTile`.
- Existing Task Details: one entry button to the activity screen (diff first).

**Tests:** model round-trips, helper-ranking unit test, composer widget test. Emulator: comments CRUD by author / leader / outsider; history create-only (no update or delete).

**Phase 4 notes (committed 2026-11-13)**
- Built: comments (post / edit own / delete own or as Admin), history (help requests and accepts only; existing flows don't write history yet), Need Help (sets Blocked + `helpNote {text, taggedUserId, requestId}` + a `help_requested` entry in one batch), and "I can help" for the named helper (`help_accepted` entry at `accept_<requestId>`, once per request, plus a notification for the requester, in one batch).
- `helpNote` is read and written only by `TaskActivityRepository`; the existing `Task` model and `TaskRepository` are unchanged.
- Rules added: `comments` and `history` blocks under tasks (emulator tests in `firestore-tests/test/activity.test.js`).
- Rules added: `notifications` (approved 2026-11-13). Create: signed-in sender who shares the notification's `projectId` with the recipient, `senderId` = writer, known types only (`help_accepted` for now), `read == false`, server `createdAt`; a `help_accepted` notice is further tied to the sender's accept entry in the same batch, at `help_accepted_<requestId>`, to the member who asked. Read / update (`read` only) / delete: recipient only. Emulator tests in `firestore-tests/test/notifications.test.js`. Every notification needs a `projectId`, so Phase 6 leave notifications will need this rule extended.
- Need Help caption: "NAME will be notified with this task attached." Now true (follow-up, 2026-11-13): `requestHelp` writes a `help_requested` notification for the named helper ("NAME requested your help on TASK") at `help_requested_<requestId>`, in the same batch as the Blocked + `helpNote` update and the history entry. Rules allow it only in that batch, only to the helper the note names, once per request. Emulator tests: `firestore-tests/test/help_requested_notifications.test.js`.
- Dev-preview smoke test fixed inside `lib/dev_preview/` and `test/dev_preview/` (all its earlier failures predated Phase 4): pushed screens kept `currentConfiguration.uri` at `/` (the test now reads `router.state`; the preview's "Screens" button now checks the match count), and switching to the Member session hung because `login()` awaited a fake-async future inside `runAsync`.
- Test status at commit: `flutter analyze` clean; `flutter test` 241 passed, 1 skipped, 1 failed (the known preview issue below); rules tests 63 passing.
- Test status after the helper-notification follow-up: `flutter analyze` clean; `flutter test` 243 passed, 2 skipped (one is the known preview issue, skipped with a reason), 0 failed; rules tests 69 passing.

**Known limitations (decided 2026-11-13)**
- "Who can help?" counts active tasks in **this project only**. Rules don't let the requester read other projects' tasks. Kept per project for now; a cross-project count would need a server-side counter (Cloud Function) or a looser tasks read rule.

## Issues in existing code to report

Bugs found in files that existed before the add-only rule. They aren't fixed here (existing app files are off-limits); each needs an approved edit.

| # | Where | Issue | Found by | Workaround |
|---|---|---|---|---|
| 1 | `ProjectDetailScreen` (projects feature) | `RenderFlex overflowed by 79 pixels on the right` at phone width (390 px) when an Admin views a project where they're a Member (dev preview: Admin › "Project detail: Admin as Member", Project Phoenix). | `test/dev_preview/preview_smoke_test.dart` | That preview check is skipped with a reason (`_knownIssues` in the test). Remove the skip once the screen is fixed. |

---

## Phase 6 — Leave, Team, Member Profile (FR unknown; screenshots 02, 03, 04)

**Model** (new, `features/leave/data/`): `LeaveRequest`, `LeaveType` (Sick / Casual / Emergency / Other), `LeaveStatus`, `LeaveSettings {allowances, holidays}`; pure `workingDaysBetween(from, to, holidays, halfDay)` and `LeaveBalance` calculators (unit-tested).

**Rules (applied 2026-11-13, approved diff; emulator tests in `firestore-tests/test/leave.test.js`):**
- `leaveRequests/{id}`. **Create:** the requester only, status pending, type sick/casual/emergency/other, `fromDate <= toDate`, `halfDay` only for one day, reason ≤500, `0 < workingDays <= 366`, 1–50 `approverIds` (leaders of the requester's projects, minus the requester), server `createdAt`. **Read:** the requester or anyone in `approverIds`. **Decide:** pending → approved/rejected only; only `status`, `decidedBy`, `decidedVia`, `decidedAt` change; `decidedBy` is the writer, who must be in `approverIds`, a `leader` of `decidedVia` (a project the requester is in), and never the requester. **Delete (= cancel):** the requester, while pending.
- `leaveDays/{id}`: `{userId, fromDate, toDate}` only, created only in the batch that turns `leaveRequests/{same id}` from pending to approved (values copied from it); any signed-in user may `get`, `list` needs `limit <= 200`; never updated or deleted. The On Leave badge reads it (computed on read; no reason exposed).
- `settings/leave`: read by signed-in users; **write: false** (console only, see below).
- `notifications`: optional `leaveId`, new types `leave_approved` / `leave_rejected`, allowed only in the deciding batch, at `leave_<leaveId>`, from the decider to the requester, with `projectId == decidedVia`. "New request" notices to approvers are Phase 8.

**Console step: seed `settings/leave`** (the app falls back to these defaults while the doc is missing). Firebase console → Firestore → Start collection `settings` → document id `leave` → fields:
- `allowances` (map): `casual` (number) 10, `sick` (number) 8, `emergency` (number) 3
- `holidays` (array of strings, `YYYY-MM-DD`), e.g. `2026-12-25`. May be empty.

**Phase 6 done criteria (changed 2026-11-13, strict add-only):** the On Leave badge shows on **Team** and **Member Profile** only. The CLAUDE.md row ("members list, task assignee picker, chat participants") is not met by design; see the hooks below.

**Hooks to add later (existing files, each needs an approved edit):**
- On Leave badge in the project **members list** (`projects/presentation/widgets/team_members_section.dart`) and the task **assignee picker** (`tasks/presentation/widgets/assignee_picker.dart`): add `OnLeaveIndicator(uid: …)` from `features/leave/presentation/widgets/leave_badges.dart`.
- Chat participants: when Phase 5 builds chat, use the same `OnLeaveIndicator`.

**Screens**
- Leave (member), filling the placeholder `RequestLeaveScreen`: Used / Remaining / Pending stat tiles, Request Leave button, "My requests" list (date range, working days, type chip, status pill).
- Request Leave (new, `LeaveRequestFormScreen`): available-balance banner, type dropdown + chips, start/end `DateField`s, reason, "Total days: n · Working days", Submit Request, "Approval typically arrives within 24 hours".
- Leave Management (admin), filling the placeholder `LeaveRequestsScreen`: "n Pending" badge, Pending / History toggle, request cards (avatar, name, dates, type chip, reason, Reject / Approve).
- Team, filling the placeholder `TeamMembersScreen`: search field, member rows (avatar, name, role label, "n active tasks", On Leave badge).
- Member Profile (new, `/leader/team/:uid`): avatar, name, email, role badge, read-only skills, current tasks with status pills, "Add to project" through the existing `ProjectRepository.addMember`.

**Phase 6 notes (committed 2026-11-13)**
- New: `features/leave/` (models, `LeaveRepository`, providers, balance / working-days / approver / validation logic, Leave tab body, Request Leave, Leave Detail, Leave Management body, widgets), `features/team/` (team providers, Team body, Member Profile, Add to project sheet), `core/widgets/on_leave_badge.dart`.
- Existing files changed (approved diffs): `firestore.rules` (additive only: vs origin/main no line is removed; the original TODO comment is kept), `lib/routing/app_router.dart` (3 routes), the build bodies of `RequestLeaveScreen`, `LeaveRequestsScreen`, `TeamMembersScreen`, and `helperCandidatesProvider` (people on approved leave today are left out of "Who can help?").
- Dev preview: `PreviewLeaveRepository` + `MockLeave`; new entries Admin › Team, Leave, Member profile (+ on leave); Member › Leave, Request leave, Leave detail (pending / approved).
- Tests: `flutter analyze` clean; `flutter test` 287 passed, 2 skipped (the known Project Detail issue + one earlier skip), 0 failed; rules tests 96 passing.

**Known limitations**
- Approvers are frozen at submit time (`approverIds`). A leader added to the requester's project later doesn't see older requests; a removed one still sees them but can no longer decide (the rules check current leadership of `decidedVia`).
- Admins (default role `leader`) have no Request Leave screen; the Admin Leave tab is management only, as in the mocks.
- Overlapping requests aren't prevented. Balance and "no approver" are checked in the app only (rules can't sum requests).
- Team counts active tasks across the projects the Admin belongs to; Member Profile lists only tasks in those projects (rules don't allow reading others).

**Differences from the mocks**
- *Leave (member, mock 02):* dates use the app's shared format ("Nov 12 – Nov 14, 2026", not "12 – 14 Nov 2026"). The mock's working-day counts don't match the 2026 calendar ("12 – 14 Nov · 3 working days" ends on a Saturday; "24 – 25 Oct" is a weekend); the app computes them and the preview data uses corrected dates.
- *Request Leave (mock 02):* added a **Half day** switch (only when start = end), a reason character counter (500 max), the deadline-conflict warning, and an inline red blocking message (over balance / no approver / no working days). The totals row shows the computed "n working days" on the right where the mock just says "Working days". "Other" shows "No yearly limit" in the banner. The type dropdown has a leading icon (field style rule).
- *Leave Detail:* no mock; follows 02's card style (range, status pill, working days, type chip, reason, requested / decided by), with an outlined red **Cancel request** + confirm dialog while pending.
- *Leave Management (mock 03):* counts are text in the toggle ("Pending (3)") rather than a separate count bubble; each card adds working days to the date line and, while pending, the requester's tasks due during the leave; History cards show the status pill and "by NAME · date".
- *Team (mock 04):* same layout; role is Admin/Member by role in the Admin's projects; the On Leave badge sits under "n active tasks" on the right (inline next to the role it overflowed at 390 px).
- *Member Profile (mock 04):* task rows add the project name and use the existing task status badges (icon + label) instead of the mock's dot pills; the On Leave badge sits next to the role; **Add to project** is disabled with a caption when there's no active project of yours left to add them to.

---

## Phase 8 — Notifications (FR unknown; screenshots 01, 03)

- New `features/notifications/data/`: `AppNotification`, `NotificationType`, `NotificationRepository` (watch mine, unread count, markRead, markAllRead, create).
- Fills the placeholder `NotificationsScreen`: "Notifications" + "n new" chip, Mark all as read, unread tint + dot, per-type icon, title + subtitle/quote, relative time (`core/utils/relative_time.dart`, new file, no `intl`), "You're completely caught up" empty state.
- Rules (additive, new `notifications` collection) + emulator tests for the sender/recipient checks and read-flag-only updates.

## Phase 7 — Calendar (FR unknown; screenshot 04)

- Fills the placeholder `CalendarScreen`: custom Monday-first month grid with prev/next, selected-day circle, deadline dots (red if overdue), "Tasks on selected day" (icon, title, project · sprint, status / Overdue pill).
- New `calendarTasksProvider` merging the existing `projectTasksProvider` for the projects the Admin leads. No rules changes.

## Phase 9 — Analytics (FR-2.5 progress; rest FR unknown; screenshot 03)

- Add `fl_chart` (approved; pubspec diff shown first).
- New `features/reports/`: `analyticsProvider` (counts per status, completed %, overdue, blocked) over the projects I lead.
- Fills the placeholder `AnalyticsScreen`: Projects / Completed % / Overdue / Blocked tiles, "Tasks by status" donut with total in the center + legend, "Project progress" bars.
- Loading / empty / error states on every new or filled screen.

---

## Profile: mock vs. current (your decision; nothing changes until you say so)

The mock has these; the current Profile doesn't:
1. **Header block:** large initials avatar, name, email and a role badge ("Member" / "Admin"). Today these appear as form fields.
2. **"My skills" card:** chip list, "n active" count and a "+ Add skill" chip. Today it's the `SkillTagsEditor` titled "Skill tags".
3. **Theme as an inline Light / Dark / System segmented toggle** with the current mode named ("Light mode"). Today it's a `ThemeModeMenuButton` popup.
4. **Change password row.** No such feature exists yet. It would need a re-authenticate + `updatePassword` flow, or reuse of the password-reset email.
5. **Log out styling:** a full-width tinted error button (member) or an outlined error button (admin). Today it's the existing `SignOutButton`.
6. **Admin: Analytics row inside the same settings card** as Theme and Change password. Today it's a separate ListTile in that card, so this is close already.

The current Profile has these; the mock doesn't:
- An editable **Name** field and a **Save** button.
- The **Default role** shown as a field.

---

## Open questions (answer before the phase that needs them)

All questions answered (2026-11-13). Decisions below.

**Phase 4 — decided (2026-11-13)**
- **History: strict.** Existing flows (status selector, task edit, reassign, subtasks) aren't touched. History shows only actions from the new screens for now. History for existing flows can be added later, through additive hooks or a Cloud Function (Firestore trigger on task writes).
- **Request Help → Blocked:** `TaskStatus.blocked` already exists (`task_status.dart`), so Request Help sets the task's status to Blocked along with the `helpNote`. (Had it not existed, no value would have been added; a "Help requested" badge would have been shown instead.)
- **"Who can help?" candidates:** members of the task's project except the current user, least busy first (fewest active tasks), skill tags as the subtitle. From Phase 6 on, people on approved leave today are excluded.

**Phase 6 — decided (2026-11-13)**
- **`settings/leave`:** any Admin (`defaultRole == 'leader'`) may change allowances. No settings screen for now. Seed defaults Casual 10, Sick 8, Emergency 3 in `settings/leave`; they're edited in the Firebase console.
- **Leave stat tiles:** Used = approved days this year, all types. Remaining = what's left of Casual + Sick + Emergency (Other has no balance). Pending = days in pending requests.
- **Over-balance requests:** blocked with a clear message. "Other" is never blocked.
- **No approver available:** blocked with "No approver available. Contact your admin."
- **Leave detail screen** with Cancel (while pending): built, as a new screen + new route.

**Phase 6 — decided at phase start (2026-11-13)**
- **On Leave visibility:** a `leaveDays/{id}` mirror with only `{userId, fromDate, toDate}`, written in the approval batch.
- **Badge on existing screens:** no (strict add-only). Team and Member Profile only; members list / assignee picker listed as hooks.
- **Leave notifications:** approved / rejected in Phase 6; "new request" to approvers in Phase 8.
- **`settings/leave`:** read-only in the app (`write: false`); edited in the Firebase console only.

**Phase 8 — decided (2026-11-13)**
- **Notifications:** new flows (help request, comments, leave decisions) write their own notifications from the sender's app. "Task assigned" waits for the Cloud Functions step; existing task code isn't touched.
