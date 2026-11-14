// Phase 8: the notification center's new types (comment_added,
// task_blocked, leave_requested), plus the recipient's list query and
// Mark all as read.
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  createEnv,
  day,
  projectDoc,
  storedTask,
  FieldValue,
} = require('./helpers');

// admin + admin2 lead p1; m1 = assignee, m2 = Member not assigned.
// p2: admin3 leads, m1 is a Member (m2 isn't in it).
const P1 = { admin: 'leader', admin2: 'leader', m1: 'member', m2: 'member' };
const P2 = { admin3: 'leader', m1: 'member' };
const TASK = 'projects/p1/tasks/t1';

describe('notification center rules (Phase 8)', () => {
  let env;

  before(async () => {
    env = await createEnv();
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('projects/p1').set(projectDoc(P1));
      await db.doc('projects/p2').set(projectDoc(P2, { createdBy: 'admin3' }));
      await db.doc(TASK).set(
        storedTask({ status: 'in_progress', assignedTo: ['m1'] }),
      );
      await db.doc('leaveRequests/l1').set({
        userId: 'm1',
        type: 'casual',
        fromDate: day(2026, 11, 12),
        toDate: day(2026, 11, 14),
        halfDay: false,
        reason: 'Family event',
        workingDays: 3,
        status: 'pending',
        approverIds: ['admin', 'admin2', 'admin3'],
        createdAt: day(2026, 11, 1),
      });
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();

  // ---------------------------------------------------------- comments

  describe('comment_added', () => {
    const notice = (sender, to, commentId = 'c1', overrides = {}) => ({
      userId: to,
      senderId: sender,
      type: 'comment_added',
      projectId: 'p1',
      taskId: 't1',
      commentId,
      message: 'Mia commented on Design login screen',
      detail: 'On it',
      read: false,
      createdAt: now(),
      ...overrides,
    });

    // Like TaskActivityRepository.addComment.
    const post = (uid, recipients, {
      commentId = 'c1',
      withComment = true,
      id = (to) => `comment_${commentId}_${to}`,
      data = (to) => notice(uid, to, commentId),
    } = {}) => {
      const db = as(uid);
      const batch = db.batch();
      if (withComment) {
        batch.set(db.doc(`${TASK}/comments/${commentId}`), {
          authorId: uid,
          text: 'On it',
          createdAt: now(),
        });
      }
      for (const to of recipients) {
        batch.set(db.doc(`notifications/${id(to)}`), data(to));
      }
      return batch.commit();
    };

    it('the author notifies the assignee and Admins with the comment',
      async () => {
        await assertSucceeds(post('m2', ['m1', 'admin', 'admin2']));
        await assertSucceeds(as('m1').doc('notifications/comment_c1_m1').get());
      });

    it('an Admin author notifies the assignee and the other Admin',
      async () => {
        await assertSucceeds(post('admin', ['m1', 'admin2']));
      });

    it('never to the author or a Member who isn\'t assigned', async () => {
      await assertFails(post('m2', ['m2']));
      await assertFails(post('m1', ['m2']));
    });

    it('only in the batch that creates the comment, once', async () => {
      await assertFails(post('m2', ['m1'], { withComment: false }));
      await assertSucceeds(post('m2', ['m1']));
      // The comment exists now: a second notice for it is refused.
      await assertFails(post('m2', ['admin'], { withComment: false }));
    });

    it('not for someone else\'s comment', async () => {
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc(`${TASK}/comments/c9`).set({
          authorId: 'm1',
          text: 'Hi',
          createdAt: day(2026, 11, 1),
        }));
      await assertFails(post('m2', ['admin'], {
        commentId: 'c9',
        withComment: false,
      }));
    });

    it('fixed id, valid shape', async () => {
      await assertFails(post('m2', ['m1'], { id: () => 'random' }));
      await assertFails(post('m2', ['m1'], { id: () => 'comment_c1_admin' }));
      await assertFails(post('m2', ['m1'], {
        data: (to) => notice('m2', to, 'c1', { detail: 'x'.repeat(201) }),
      }));
      await assertFails(post('m2', ['m1'], {
        data: (to) => notice('m2', to, 'c1', { leaveId: 'l1' }),
      }));
      await assertFails(post('m2', ['m1'], {
        data: (to) => notice('m2', to, 'c1', { senderId: 'm1' }),
      }));
    });

    it('commentId is only allowed on comment notices', async () => {
      // A help_accepted shape with a commentId fails validNotification.
      const db = as('m2');
      await assertFails(db.doc('notifications/help_accepted_x').set({
        userId: 'm1',
        senderId: 'm2',
        type: 'help_accepted',
        projectId: 'p1',
        taskId: 't1',
        commentId: 'c1',
        message: 'm',
        read: false,
        createdAt: now(),
      }));
    });
  });

  // ------------------------------------------------------- task_blocked

  describe('task_blocked', () => {
    const notice = (sender, to, overrides = {}) => ({
      userId: to,
      senderId: sender,
      type: 'task_blocked',
      projectId: 'p1',
      taskId: 't1',
      message: 'Task Design login screen is blocked',
      detail: 'Stuck on rules',
      read: false,
      createdAt: now(),
      ...overrides,
    });

    // Like TaskActivityRepository.requestHelp (no named helper).
    const request = (uid, admins, {
      requestId = 'req1',
      withEntry = true,
      withTask = true,
      status = 'blocked',
      id = (to) => `task_blocked_${requestId}_${to}`,
      data = (to) => notice(uid, to),
    } = {}) => {
      const db = as(uid);
      const batch = db.batch();
      if (withTask) {
        batch.update(db.doc(TASK), {
          status,
          helpNote: { text: 'Stuck on rules', requestId },
          updatedAt: now(),
        });
      }
      if (withEntry) {
        batch.set(db.doc(`${TASK}/history/${requestId}`), {
          who: uid,
          action: 'help_requested',
          from: 'in_progress',
          at: now(),
        });
      }
      for (const to of admins) {
        batch.set(db.doc(`notifications/${id(to)}`), data(to));
      }
      return batch.commit();
    };

    it('the assignee notifies every project Admin in the Blocked batch',
      async () => {
        await assertSucceeds(request('m1', ['admin', 'admin2']));
        await assertSucceeds(
          as('admin2').doc('notifications/task_blocked_req1_admin2').get(),
        );
      });

    it('only to project leaders, never the writer', async () => {
      await assertFails(request('m1', ['m2']));
      await assertFails(request('m1', ['m1']));
      // An Admin who asks for help doesn't notify themselves.
      await assertFails(request('admin', ['admin']));
      await assertSucceeds(request('admin', ['admin2'], { requestId: 'r2' }));
    });

    it('only in the batch that sets Blocked with a new request', async () => {
      await assertFails(request('m1', ['admin'], { withEntry: false }));
      await assertFails(request('m1', ['admin'], { withTask: false }));
      await assertSucceeds(request('m1', ['admin']));
      // Request req1 exists now: no more notices for it.
      await assertFails(request('m1', ['admin2'], {
        withEntry: false,
        withTask: false,
      }));
    });

    it('fixed id, valid shape', async () => {
      await assertFails(request('m1', ['admin'], { id: () => 'random' }));
      await assertFails(request('m1', ['admin'], {
        id: () => 'task_blocked_req1_admin2',
      }));
      await assertFails(request('m1', ['admin'], {
        data: (to) => notice('m1', to, { detail: 5 }),
      }));
    });
  });

  // ---------------------------------------------------- leave_requested

  describe('leave_requested', () => {
    const notice = (sender, to, overrides = {}) => ({
      userId: to,
      senderId: sender,
      type: 'leave_requested',
      projectId: 'p1',
      leaveId: 'l1',
      message: 'Mo submitted a leave request',
      detail: 'Casual leave · Nov 12 – Nov 14, 2026',
      read: false,
      createdAt: now(),
      ...overrides,
    });
    const send = (uid, to, overrides = {}, id) =>
      as(uid)
        .doc(`notifications/${id || `leave_requested_l1_${to}`}`)
        .set(notice(uid, to, overrides));

    it('the requester notifies each approver through a project they lead',
      async () => {
        await assertSucceeds(send('m1', 'admin'));
        await assertSucceeds(send('m1', 'admin2'));
        await assertSucceeds(send('m1', 'admin3', { projectId: 'p2' }));
        await assertSucceeds(
          as('admin3').doc('notifications/leave_requested_l1_admin3').get(),
        );
      });

    it('the project must be one the approver leads', async () => {
      await assertFails(send('m1', 'admin3', { projectId: 'p1' }));
      await assertFails(send('m1', 'admin', { projectId: 'p2' }));
    });

    it('only to approvers named on the request', async () => {
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc('leaveRequests/l1').update({
          approverIds: ['admin'],
        }));
      await assertFails(send('m1', 'admin2'));
      await assertFails(send('m1', 'm2'));
    });

    it('only for the sender\'s own pending request', async () => {
      await assertFails(send('m2', 'admin'));
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc('leaveRequests/l1').update({
          status: 'approved',
        }));
      await assertFails(send('m1', 'admin'));
    });

    it('fixed id, no taskId, once', async () => {
      await assertFails(send('m1', 'admin', {}, 'random'));
      await assertFails(send('m1', 'admin', {}, 'leave_requested_l1_admin2'));
      await assertFails(send('m1', 'admin', { taskId: 't1' }));
      await assertSucceeds(send('m1', 'admin'));
      // Same id again = an update the recipient alone may make.
      await assertFails(send('m1', 'admin'));
    });
  });

  // -------------------------------------------- recipient: list + read

  describe('the recipient', () => {
    beforeEach(async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        for (const [id, userId, read] of [
          ['n1', 'm1', false],
          ['n2', 'm1', false],
          ['n3', 'm1', true],
          ['n4', 'm2', false],
        ]) {
          await db.doc(`notifications/${id}`).set({
            userId,
            senderId: 'admin',
            type: 'help_accepted',
            projectId: 'p1',
            taskId: 't1',
            message: 'm',
            read,
            createdAt: day(2026, 11, 1),
          });
        }
      });
    });

    it('lists only their own, newest first (the center query)',
      async () => {
        const mine = as('m1')
          .collection('notifications')
          .where('userId', '==', 'm1');
        await assertSucceeds(mine.orderBy('createdAt', 'desc').limit(50).get());
        await assertSucceeds(mine.where('read', '==', false).get());
        await assertFails(as('m1').collection('notifications').get());
        await assertFails(
          as('m1')
            .collection('notifications')
            .where('userId', '==', 'm2')
            .get(),
        );
      });

    it('Mark all as read: one batch flipping only `read`', async () => {
      const db = as('m1');
      const batch = db.batch();
      batch.update(db.doc('notifications/n1'), { read: true });
      batch.update(db.doc('notifications/n2'), { read: true });
      await assertSucceeds(batch.commit());

      // Not someone else's, and nothing but `read`.
      await assertFails(db.doc('notifications/n4').update({ read: true }));
      await assertFails(
        db.doc('notifications/n3').update({ read: false, message: 'x' }),
      );
    });
  });
});
