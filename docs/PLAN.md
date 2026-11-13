# ProTrack build plan (Phases 4 – 9)

> **ADD-ONLY RULE:** never modify or delete files that exist in origin/main. New screens go in new files using the existing theme and widgets. The only allowed edits to existing files are additive (new routes, rules for new collections, pubspec dependencies), each shown to me as a diff and approved first. CLAUDE.md is read-only.

Source of truth: `design/screens/*.jpg` (screenshots = spec) plus the decisions in `CLAUDE.md`. Requirements not cited in existing code are marked **FR unknown**.

Build order: **4 → 6 → 8 → 7 → 9**. One phase at a time; each ships model + repository + Firestore rules + emulator tests + UI, and is done only when `flutter analyze`, `flutter test` and (if rules changed) `firestore-tests` `npm test` all pass. Every phase also adds its new screens to the dev preview (`lib/dev_preview/`).

Environment: Flutter 3.47.1 / Dart 3.13.1 at `C:\src\flutter`. Rules tests need **JDK 21** (only Java 1.8 found so far).

Under the add-only rule, existing screens (Task detail, the Team / Calendar / Leave / Profile tabs, Analytics, Notifications placeholders), existing repositories, models and widgets stay exactly as they are. New screens are reached through **new** routes; adding each route to `lib/routing/app_router.dart` is an additive diff shown for approval first.

---

## Phase 4 — Comments and history (FR unknown; screenshot 01)

**Model** (new files in `features/tasks/data/`)
- `TaskComment {id, authorId, text, createdAt, editedAt?}`.
- `TaskHistoryEntry {id, who, action, from?, to?, at}`.

**Repository** (new file)
- `TaskActivityRepository`: `watchComments`, `addComment`, `editComment`, `deleteComment`, `watchHistory(limit)` (paged).

**Rules** (additive, approved diff to `firestore.rules`): new `comments` and `history` subcollection matches as in CLAUDE.md decision 3.

**UI** (new files)
- A task activity screen (comments with composer, history list) at a new route under the task.
- Widgets: `CommentTile`, `CommentComposer` (send only), `HistoryTile`.

**Tests:** model round-trips, widget tests for the composer; emulator: comments CRUD by author/leader/outsider, history create/no-update.

---

## Phase 6 — Leave (FR unknown; screenshots 02, 03)

**Model** (new, `features/leave/data/`): `LeaveRequest`, `LeaveType`, `LeaveStatus`, `LeaveSettings {allowances, holidays}`; pure `workingDaysBetween(from, to, holidays, halfDay)` and `LeaveBalance` calculators (unit-tested).

**Proposed rules design (confirm at phase start; additive rules for the new `leaveRequests` / `settings` collections):**
- On submit the app stores `approverIds` = leaders of the requester's projects, minus the requester. Approvers list Pending with `approverIds array-contains uid`.
- Decisions must also name `decidedVia: projectId`; rules check `get(project).members[uid] == 'leader'` and the requester is in that project and `uid != userId`. So a forged `approverIds` entry can read the request but can't decide it.
- Requester: create (pending, own uid, valid dates/type), read own, cancel own pending.

**Screens / new routes** (new files under `features/leave/`)
- Leave overview (stats, Request Leave button, My requests; Pending/History management for Admins).
- Request Leave (chips, dates, half-day toggle for single day, reason, total days, balance banner).
- Leave detail (+ Cancel when pending).
- Leave settings (allowances + holidays editor).
- Member Profile (`/leader/team/:uid`, read-only skills, current tasks, Add to project via the existing `ProjectRepository.addMember`).

---

## Phase 8 — Notifications (FR unknown; screenshots 01, 03)

- New `features/notifications/data/`: `AppNotification`, `NotificationType`, `NotificationRepository` (watch mine, unread count, markRead, markAllRead).
- New notification center screen (new file, new route): unread tint + dot, per-type icon, relative time (`core/utils/relative_time.dart`, new file, no `intl`), Mark all as read, "caught up" empty state.
- Rules (additive, new `notifications` collection) + emulator tests for the sender/recipient checks and read-flag-only updates.

## Phase 7 — Calendar (FR unknown; screenshot 04)

- New `features/reports/presentation/calendar_screen.dart` (new route): custom Monday-first month grid, dots (red if overdue), "Tasks on selected day" (icon, title, project name, status/Overdue pill).
- New `calendarTasksProvider` merging the existing `projectTasksProvider` for projects the Admin leads. No rules changes.

## Phase 9 — Analytics (FR-2.5 progress; rest FR unknown; screenshot 03)

- Add `fl_chart` (approved; pubspec diff shown first). New `features/reports/`: `analyticsProvider` (counts per status, completed %, overdue, blocked) over projects I lead; a new analytics screen (new file, new route) with stat tiles, donut (+ grey Not Started) and project progress bars.
- Loading / empty / error states on every new screen.

---

## Open questions (answer before the phase that needs them)

**Phase 6**
1. **Who edits `settings/leave`?** Proposal: any user whose `defaultRole` is `leader` (no mock exists for this screen).
2. **Leave stat tiles:** Used = approved days this year (all types); Remaining = sum of remaining Casual + Sick + Emergency; Pending = pending days (all types)?
3. **Over-balance requests:** block submission, or allow with a warning?
4. **No approver available** (e.g. an Admin who belongs only to projects they lead alone): block with a message?

**All phases**
5. Under the add-only rule the new screens can't replace the existing tab placeholders (Team, Calendar, Leave, Analytics, Notifications) or be linked from existing screens. How should users reach them — new routes only (reachable by URL / dev preview), or will you approve specific additive route changes?
