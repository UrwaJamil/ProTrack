# ProTrack build plan (Phases 3.5 – 9)

Source of truth: `design/screens/*.jpg` (screenshots = spec; there is no `docs/SPEC.md`) plus the decisions in `CLAUDE.md`. Requirements not cited in existing code are marked **FR unknown**.

Build order: **3.5 → 4 → 6 → 8 → 7 → 9**. One phase at a time; each ships model + repository + Firestore rules + emulator tests + UI, and is done only when `flutter analyze`, `flutter test` and (if rules changed) `firestore-tests` `npm test` all pass.

Environment: Flutter 3.47.1 / Dart 3.13.1 at `C:\src\flutter`. Rules tests need **JDK 21** (only Java 1.8 found so far).

---

## Phase 3.5 — Design pass (FR unknown; screenshots 01, 03, 04)

**Theme (`lib/app/theme.dart`)**
- Bundle Plus Jakarta Sans TTFs (Regular 400, Medium 500, SemiBold 600, Bold 700, ExtraBold 800) in `assets/fonts/` + `assets/fonts/OFL.txt`; declare in `pubspec.yaml`; set `fontFamily`. Register the OFL text with `LicenseRegistry` so it shows in the licence page.
- `AppPalette` / `AppColors`: status pill pairs + dot colour for Not Started, In Progress, On Hold, Blocked, Completed, Overdue, Pending, Approved (blue), Rejected, Cancelled; `unreadTint`; `destructiveTint`; card surface tuned to the mock; light **and** dark values.
- Phone app bar theme: light bar on the page background, title left (decision 11).

**Shared widgets (`lib/core/widgets/`)**
| Widget | Change | Used by |
|---|---|---|
| `PillToggle<T>` | + optional `count` per segment, + `compact` size | Task tabs, Leave Pending/History, Theme toggle |
| `StatusPill` | + leading dot, + new statuses | tasks, leave, calendar |
| `StatTile` | new | Leave stats, Analytics |
| `TagChip` (+ `TagChip.add`) | new | skills, leave type chips |
| `SectionCard` | new (title + trailing caption + child) | Profile, Member Profile, Leave |
| `SettingsRow` | new (icon tile, label, trailing chevron/widget) | Profile |
| `RoleBadge` | new (`light` / `filled`) | Profile header, comments, Team |
| `CountBadge` | new | "2 new", "3 Pending" |
| `InfoBanner` | new | Need Help, Request Leave balance |
| `DestructiveButton` | new (`tinted` / `outlined`) | Log out |

**Chrome:** `ProTrackAppBar` → page title (+ optional back), bell, avatar on phones; sidebar keeps logo + "ProTrack" on wide layouts. Each tab screen supplies its title.

**Profile (both roles)** — `features/profile/presentation/`
- `profile_screen.dart` rebuilt: `ProfileHeader` (avatar, name + edit icon → inline edit, email, `RoleBadge`), `SkillsSection` (chips + "+ Add skill"; Admins too), `ThemeSection` (PillToggle Light/Dark/System on existing `themeModeProvider`), `SettingsRow`s (Analytics for Admin, Change password), Log out.
- New `/change-password` route + `change_password_screen.dart`: current password, new password with the existing checklist (`password_policy.dart`), confirm. `AuthRepository.changePassword(current, next)` re-authenticates then updates; hidden when the account has no `password` provider. Never logs passwords.
- Retire `theme_mode_menu_button.dart` and `profile_settings_section.dart` if nothing else uses them.

**Tests:** widget tests for each new shared widget (incl. dark mode), Profile Admin vs Member variants, name edit, change-password validation + error mapping (fake repo), app bar phone vs wide.

---

## Phase 4 — Help, comments, history (FR-3.5/3.6 existing; rest FR unknown; screenshots 01, 02)

**Model** (`features/tasks/data/`)
- `HelpNote {text, taggedUserId, requestedBy, createdAt, acceptedAt?}` on `Task` (nullable).
- `TaskComment {id, authorId, text, createdAt, editedAt?}`.
- `TaskHistoryEntry {id, who, action, from?, to?, at}`; `HistoryAction` enum: `created, status_changed, reassigned, subtask_completed, subtask_reopened, help_requested, help_accepted, deadline_changed, edited`.

**Repositories**
- `TaskRepository`: every write that changes status / assignees / subtasks / deadline also adds a history doc in the same batch or transaction; `requestHelp(task, text, helperId)` (status → blocked + helpNote + history); `acceptHelp(task)`; leaving Blocked clears `helpNote`.
- New `TaskActivityRepository`: `watchComments`, `addComment`, `editComment`, `deleteComment`, `watchHistory(limit)` (paged).

**Rules** (`firestore.rules`) — comments and history as in CLAUDE.md decision 3; `helpNote` shape check (text 1–500, `taggedUserId` a project member ≠ requester, `requestedBy == uid`); **accept rule (decided: option a)** — a separate, narrow task-update path: `request.auth.uid == resource.data.helpNote.taggedUserId`, the helper is still a project member, the project is active, `resource.data.helpNote.acceptedAt` is unset, `request.resource.data.helpNote.acceptedAt == request.time`, and the diff touches only `helpNote` with only `acceptedAt` added inside it. `acceptHelp` writes the task update + `help_accepted` history entry + requester notification in one batch (the notification half lands with Phase 8; until then the batch is task + history).

**UI**
- `task_detail_screen.dart`: title card (`TASK #TSK-…`, title, tappable status chip, project name) + tabs Details | Comments (n) | History; help banner (Blocked note for everyone; Accept for the tagged helper).
- New `need_help_screen.dart` at `…/tasks/:taskId/help` (both `/leader/...` and `/member/...` trees).
- Widgets: `TaskTitleCard`, `CommentTile` (role badge, "edited", menu for edit/delete), `CommentComposer` (send only), `HistoryTile`, `HelpBanner`, `HelperRadioTile`.
- Helper list provider: project members − me − anyone on approved leave today (leave lookup stubbed to "nobody" until Phase 6), sorted by skill count desc.

**Tests:** model round-trips, history-in-same-batch (fake Firestore), helper sorting/filtering, widget tests for tabs/composer/Need Help validation (required, 500 max, counter); emulator: comments CRUD by author/leader/outsider, history create/no-update, helpNote shape. **Accept-rule tests (required):** tagged helper sets `acceptedAt` once ✔; helper changes any other field (incl. other `helpNote` keys, `status`, `updatedAt`) ✘; helper sets it a second time ✘; another member ✘; the requester ✘; a non-member ✘; a value other than `request.time` ✘.

---

## Phase 6 — Leave + Team (FR unknown; screenshots 02, 03, 04)

**Model** (`features/leave/data/`): `LeaveRequest`, `LeaveType`, `LeaveStatus`, `LeaveSettings {allowances, holidays}`; pure `workingDaysBetween(from, to, holidays, halfDay)` and `LeaveBalance` calculators (unit-tested).

**Proposed rules design (confirm at phase start):**
- On submit the app stores `approverIds` = leaders of the requester's projects, minus the requester. Approvers list Pending with `approverIds array-contains uid`.
- Decisions must also name `decidedVia: projectId`; rules check `get(project).members[uid] == 'leader'` and the requester is in that project and `uid != userId`. So a forged `approverIds` entry can read the request but can't decide it.
- Requester: create (pending, own uid, valid dates/type), read own, cancel own pending.

**Screens / routes**
- Member & Admin: Leave tab (stats tiles, Request Leave button, My requests) — Admin's tab also has the Pending/History management view.
- `/…/leave/new` Request Leave (chips, dates, half-day toggle for single day, reason, total days, balance banner, deadline-conflict warning).
- `/…/leave/:leaveId` detail (+ Cancel when pending).
- `/leader/leave/settings` allowances + holidays editor.
- `/leader/team`, `/leader/team/:uid` (Member Profile + Add to project).
- `OnLeaveBadge` added to Team rows, project members section, assignee picker, Need Help list (and chat later).
- Move placeholders out of `features/leader|member/screens/` into `features/leave/` and `features/team/`.

---

## Phase 8 — Notifications (FR unknown; screenshots 01, 03)

- `features/notifications/data/`: `AppNotification`, `NotificationType`, `NotificationRepository` (watch mine, unread count, markRead, markAllRead).
- Each trigger in CLAUDE.md decision 7 writes its notification inside the existing batch/transaction of the action (task, comment, help, leave repositories).
- UI: move `NotificationsScreen` to `features/notifications/presentation/`; header with `CountBadge`, Mark all as read, unread tint + dot, per-type icon, relative time (`core/utils/relative_time.dart`, no `intl`), tap → target, Accept on help-request tiles, "caught up" empty state.
- Real `unreadNotificationCountProvider`.
- Rules + emulator tests for the sender/recipient checks and read-flag-only updates.

## Phase 7 — Calendar (FR unknown; screenshot 04)

- `features/reports/presentation/calendar_screen.dart`: custom Monday-first month grid, dots (red if overdue), "Tasks on selected day" (icon, title, project name, status/Overdue pill).
- `calendarTasksProvider` merges `projectTasksProvider` for projects the Admin leads. No rules changes.

## Phase 9 — Analytics (FR-2.5 progress; rest FR unknown; screenshot 03)

- Add `fl_chart` (approved). `features/reports/`: `analyticsProvider` (counts per status, completed %, overdue, blocked) over projects I lead; `AnalyticsScreen` with `StatTile`s, donut (+ grey Not Started) and project progress bars.
- Polish pass: loading / empty / error states on every new screen.

---

## Open questions (answer before the phase that needs them)

**Phase 6**
1. **Who edits `settings/leave`?** Proposal: any user whose `defaultRole` is `leader`, from a gear icon on Leave Management (no mock exists for this screen — I'd style it like Profile).
2. **On Leave badge visibility.** Members must see teammates' leave (Need Help list, chat) but not the reason/type. Rules can't filter a list query by "shares a project", so I propose the approver also writes a minimal `onLeave/{lid}` doc `{userId, fromDate, toDate, halfDay}` readable by any signed-in user, in the same batch as the approval. OK?
3. **Leave stat tiles:** Used = approved days this year (all types); Remaining = sum of remaining Casual + Sick + Emergency; Pending = pending days (all types)?
4. **Over-balance requests:** block submission, or allow with a warning?
5. **No approver available** (e.g. an Admin who belongs only to projects they lead alone): block with a message?
6. **Deadline-conflict warning:** show it on Request Leave (my tasks due inside the range) and in the assignee picker (member on leave before the task deadline)?
7. **Team role label:** a row says "Member"/"Admin" — use the person's role in my project(s) (leader wins if mixed), or their `defaultRole`?
