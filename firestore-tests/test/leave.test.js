// Phase 6: leaveRequests, leaveDays, settings/leave and the leave
// decision notification (LeaveRepository.submit / cancel / decide).
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { createEnv, day, projectDoc, FieldValue } = require('./helpers');

// p1: admin leads, m1 + m2 are Members. p2: admin2 leads, m3 only.
// m1 asks for leave; admin is the approver.
const P1 = { admin: 'leader', m1: 'member', m2: 'member' };
const P2 = { admin2: 'leader', m3: 'member' };

describe('leave rules', () => {
  let env;

  before(async () => {
    env = await createEnv();
  });

  after(async () => {
    await env.cleanup();
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();

  // As LeaveDraft.toMap + createdAt.
  const draft = (uid, overrides = {}) => ({
    userId: uid,
    type: 'casual',
    fromDate: day(2026, 11, 12),
    toDate: day(2026, 11, 14),
    halfDay: false,
    reason: 'Family event out of town',
    workingDays: 3,
    status: 'pending',
    approverIds: ['admin'],
    createdAt: now(),
    ...overrides,
  });

  // A stored pending request (resolved timestamps), for seeding.
  const stored = (overrides = {}) => ({
    ...draft('m1'),
    createdAt: day(2026, 11, 1),
    ...overrides,
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('projects/p1').set(projectDoc(P1));
      await db.doc('projects/p2').set(projectDoc(P2, { createdBy: 'admin2' }));
      await db.doc('leaveRequests/l1').set(stored());
      // The agreed defaults (docs/PLAN.md, Phase 6 console step).
      await db.doc('settings/leave').set({
        allowances: { casual: 10, sick: 8, emergency: 3 },
        holidays: ['2026-12-25'],
      });
    });
  });

  describe('leaveRequests: submit', () => {
    it('a Member submits their own pending request', async () => {
      await assertSucceeds(as('m1').collection('leaveRequests').add(draft('m1')));
    });

    it('never for someone else, never pre-decided', async () => {
      await assertFails(as('m1').collection('leaveRequests').add(draft('m2')));
      await assertFails(
        as('m1').collection('leaveRequests').add(draft('m1', { status: 'approved' })),
      );
    });

    it('checks type, dates, half day, reason, days and approvers', async () => {
      const add = (o) => as('m1').collection('leaveRequests').add(draft('m1', o));
      await assertFails(add({ type: 'vacation' }));
      await assertFails(add({ fromDate: day(2026, 11, 15) }));
      await assertFails(add({ halfDay: true }));
      await assertSucceeds(
        add({ halfDay: true, toDate: day(2026, 11, 12), workingDays: 0.5 }),
      );
      await assertFails(add({ reason: 'x'.repeat(501) }));
      await assertFails(add({ workingDays: 0 }));
      await assertFails(add({ approverIds: [] }));
      await assertFails(add({ approverIds: ['admin', 'm1'] }));
      await assertFails(add({ createdAt: day(2026, 11, 1) }));
      await assertFails(add({ decidedBy: 'admin' }));
    });
  });

  describe('leaveRequests: read', () => {
    it('the requester and the named approvers only', async () => {
      await assertSucceeds(as('m1').doc('leaveRequests/l1').get());
      await assertSucceeds(as('admin').doc('leaveRequests/l1').get());
      await assertFails(as('m2').doc('leaveRequests/l1').get());
      await assertFails(as('admin2').doc('leaveRequests/l1').get());
    });

    it('list queries must filter to mine or to my approvals', async () => {
      await assertSucceeds(
        as('m1').collection('leaveRequests').where('userId', '==', 'm1').get(),
      );
      await assertSucceeds(
        as('admin')
          .collection('leaveRequests')
          .where('approverIds', 'array-contains', 'admin')
          .get(),
      );
      await assertFails(as('admin').collection('leaveRequests').get());
    });
  });

  // As LeaveRepository.decide.
  const decide = (uid, {
    status = 'approved',
    via = 'p1',
    withDays = status === 'approved',
    withNotice = true,
    days = {},
    notice = {},
  } = {}) => {
    const db = as(uid);
    const batch = db.batch();
    batch.update(db.doc('leaveRequests/l1'), {
      status,
      decidedBy: uid,
      decidedVia: via,
      decidedAt: now(),
    });
    if (withDays) {
      batch.set(db.doc('leaveDays/l1'), {
        userId: 'm1',
        fromDate: day(2026, 11, 12),
        toDate: day(2026, 11, 14),
        ...days,
      });
    }
    if (withNotice) {
      batch.set(db.doc('notifications/leave_l1'), {
        userId: 'm1',
        senderId: uid,
        type: status === 'approved' ? 'leave_approved' : 'leave_rejected',
        projectId: via,
        leaveId: 'l1',
        message: `Ada ${status} your Casual leave (Nov 12 – Nov 14, 2026)`,
        read: false,
        createdAt: now(),
        ...notice,
      });
    }
    return batch.commit();
  };

  describe('leaveRequests: decide', () => {
    it('the approver approves: request + leaveDays + notice together', async () => {
      await assertSucceeds(decide('admin'));
      await assertSucceeds(as('m1').doc('notifications/leave_l1').get());
    });

    it('the approver rejects: no leaveDays', async () => {
      await assertSucceeds(decide('admin', { status: 'rejected' }));
    });

    it('only once', async () => {
      await assertSucceeds(decide('admin'));
      await assertFails(decide('admin', { status: 'rejected' }));
    });

    it('not by the requester, a Member, or a leader of another project',
      async () => {
        await assertFails(decide('m1'));
        await assertFails(decide('m2'));
        await assertFails(decide('admin2', { via: 'p2' }));
      });

    it('only through a project the decider leads and the requester is in',
      async () => {
        await assertFails(decide('admin', { via: 'p2' }));
        await assertFails(decide('admin', { via: 'nope' }));
      });

    // Each check below is isolated: the request is seeded (rules off) so
    // that every other condition holds and only the one under test fails.
    const seed = (id, data) =>
      env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc(`leaveRequests/${id}`).set(stored(data)));
    const decideRaw = (uid, id, via, status = 'approved') =>
      as(uid).doc(`leaveRequests/${id}`).update({
        status,
        decidedBy: uid,
        decidedVia: via,
        decidedAt: now(),
      });

    it('no self-approval, even when listed as an approver and leading the project',
      async () => {
        // admin leads p1, is in p1 and (forged) in approverIds.
        await seed('own', { userId: 'admin', approverIds: ['admin'] });
        await assertFails(decideRaw('admin', 'own', 'p1'));
      });

    it('the decider must be a leader of decidedVia', async () => {
      // m2 is (forged) an approver and shares p1 with m1, but is a Member.
      await seed('l2', { approverIds: ['admin', 'm2'] });
      await assertFails(decideRaw('m2', 'l2', 'p1'));
      await assertSucceeds(decideRaw('admin', 'l2', 'p1'));
    });

    it('decidedVia must include the requester', async () => {
      // admin2 is an approver and leads p2, but m1 isn't in p2.
      await seed('l3', { approverIds: ['admin', 'admin2'] });
      await assertFails(decideRaw('admin2', 'l3', 'p2'));
    });

    it('pending → approved / rejected only', async () => {
      await assertFails(decideRaw('admin', 'l1', 'p1', 'pending'));
      await assertFails(decideRaw('admin', 'l1', 'p1', 'cancelled'));
      await seed('done', { status: 'rejected' });
      await assertFails(decideRaw('admin', 'done', 'p1', 'approved'));
      await assertFails(decideRaw('admin', 'done', 'p1', 'rejected'));
    });

    it('only the decision fields change', async () => {
      for (const extra of [
        { reason: 'edited' },
        { userId: 'm2' },
        { toDate: day(2026, 11, 20) },
        { approverIds: ['admin', 'admin2'] },
      ]) {
        await assertFails(
          as('admin').doc('leaveRequests/l1').update({
            status: 'approved',
            decidedBy: 'admin',
            decidedVia: 'p1',
            decidedAt: now(),
            ...extra,
          }),
        );
      }
      // decidedBy must be the writer; decidedAt must be the server time.
      await assertFails(
        as('admin').doc('leaveRequests/l1').update({
          status: 'approved',
          decidedBy: 'admin2',
          decidedVia: 'p1',
          decidedAt: now(),
        }),
      );
      await assertFails(
        as('admin').doc('leaveRequests/l1').update({
          status: 'approved',
          decidedBy: 'admin',
          decidedVia: 'p1',
          decidedAt: day(2026, 11, 1),
        }),
      );
    });

    it('only the decision fields change (one extra field)', async () => {
      await assertFails(
        as('admin').doc('leaveRequests/l1').update({
          status: 'approved',
          decidedBy: 'admin',
          decidedVia: 'p1',
          decidedAt: now(),
          workingDays: 1,
        }),
      );
      await assertFails(
        as('admin').doc('leaveRequests/l1').update({
          status: 'cancelled',
          decidedBy: 'admin',
          decidedVia: 'p1',
          decidedAt: now(),
        }),
      );
    });
  });

  describe('leaveRequests: cancel', () => {
    it('the requester deletes it while pending', async () => {
      await assertFails(as('admin').doc('leaveRequests/l1').delete());
      await assertSucceeds(as('m1').doc('leaveRequests/l1').delete());
    });

    it('not once decided (approved or rejected)', async () => {
      await assertSucceeds(decide('admin'));
      await assertFails(as('m1').doc('leaveRequests/l1').delete());
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc('leaveRequests/r1').set(stored({ status: 'rejected' })));
      await assertFails(as('m1').doc('leaveRequests/r1').delete());
    });
  });

  describe('leaveDays', () => {
    it('never without approving the request in the same batch', async () => {
      await assertFails(
        as('admin').doc('leaveDays/l1').set({
          userId: 'm1',
          fromDate: day(2026, 11, 12),
          toDate: day(2026, 11, 14),
        }),
      );
      await assertFails(decide('admin', { status: 'rejected', withDays: true }));
      // Not later for an already-approved request either.
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc('leaveRequests/a1').set(
          stored({ status: 'approved', decidedBy: 'admin', decidedVia: 'p1' })));
      await assertFails(
        as('admin').doc('leaveDays/a1').set({
          userId: 'm1',
          fromDate: day(2026, 11, 12),
          toDate: day(2026, 11, 14),
        }),
      );
      // Nor by the requester.
      await assertFails(
        as('m1').doc('leaveDays/l1').set({
          userId: 'm1',
          fromDate: day(2026, 11, 12),
          toDate: day(2026, 11, 14),
        }),
      );
    });

    it('copies the request exactly, nothing more', async () => {
      await assertFails(decide('admin', { days: { userId: 'm2' } }));
      await assertFails(decide('admin', { days: { toDate: day(2026, 11, 20) } }));
      await assertFails(decide('admin', { days: { reason: 'x' } }));
    });

    it('any signed-in user reads it; list needs a limit', async () => {
      await assertSucceeds(decide('admin'));
      await assertSucceeds(as('m3').doc('leaveDays/l1').get());
      await assertSucceeds(
        as('m3')
          .collection('leaveDays')
          .where('toDate', '>=', day(2026, 11, 13))
          .limit(200)
          .get(),
      );
      await assertFails(as('m3').collection('leaveDays').get());
      await assertFails(env.unauthenticatedContext().firestore().doc('leaveDays/l1').get());
    });

    it('never changed or removed', async () => {
      await assertSucceeds(decide('admin'));
      await assertFails(
        as('admin').doc('leaveDays/l1').update({ toDate: day(2026, 11, 20) }),
      );
      await assertFails(as('admin').doc('leaveDays/l1').delete());
      await assertFails(as('m1').doc('leaveDays/l1').delete());
    });
  });

  describe('leave decision notification', () => {
    it('never without the decision in the same batch', async () => {
      await assertFails(
        as('admin').doc('notifications/leave_l1').set({
          userId: 'm1',
          senderId: 'admin',
          type: 'leave_approved',
          projectId: 'p1',
          leaveId: 'l1',
          message: 'Ada approved your leave',
          read: false,
          createdAt: now(),
        }),
      );
    });

    it('type must match the decision, id and recipient fixed', async () => {
      await assertFails(decide('admin', { notice: { type: 'leave_rejected' } }));
      await assertFails(decide('admin', { notice: { userId: 'm2' } }));
      await assertFails(decide('admin', { notice: { taskId: 't1' } }));
    });

    it('leaveId only on leave notices', async () => {
      await assertFails(decide('admin', { notice: { type: 'help_accepted' } }));
    });

    it('the decision itself works without a notice', async () => {
      await assertSucceeds(decide('admin', { withNotice: false }));
    });
  });

  describe('settings/leave', () => {
    it('signed-in users read it; nobody writes it from the app', async () => {
      await assertSucceeds(as('m1').doc('settings/leave').get());
      await assertFails(
        env.unauthenticatedContext().firestore().doc('settings/leave').get(),
      );
      for (const uid of ['admin', 'm1']) {
        await assertFails(
          as(uid).doc('settings/leave').set({ allowances: { casual: 99 } }),
        );
        await assertFails(
          as(uid).doc('settings/leave').update({ holidays: [] }),
        );
        await assertFails(as(uid).doc('settings/leave').delete());
      }
      await assertFails(as('admin').doc('settings/other').get());
    });
  });
});
