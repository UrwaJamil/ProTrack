// Phase 4 rules: projects/{pid}/tasks/{tid}/comments and /history
// (CLAUDE.md decision 5), plus the Need Help batch (Blocked status +
// helpNote + history entry).
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

// admin = Admin, m1 = assignee of t1, m2 = Member not assigned (the
// helper named in t1's help note), m3 = another Member, outsider = not in
// the project.
const MEMBERS = { admin: 'leader', m1: 'member', m2: 'member', m3: 'member' };
const T1 = 'projects/p1/tasks/t1';
const BLOCKED = 'projects/p1/tasks/blocked';
const SELF = 'projects/p1/tasks/self';

describe('task activity rules', () => {
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
      await db.doc('projects/p1').set(projectDoc(MEMBERS));
      await db
        .doc('projects/arch')
        .set(projectDoc(MEMBERS, { status: 'archived' }));
      await db.doc(T1).set(storedTask({ status: 'in_progress' }));
      // A pending help request from m1, naming m2.
      await db.doc(BLOCKED).set(storedTask({
        status: 'blocked',
        helpNote: { text: 'Stuck', taggedUserId: 'm2', requestId: 'req1' },
      }));
      // The assignee named as their own helper.
      await db.doc(SELF).set(storedTask({
        status: 'blocked',
        helpNote: { text: 'Stuck', taggedUserId: 'm1', requestId: 'req2' },
      }));
      await db.doc('projects/arch/tasks/t1').set(storedTask());
      await db.doc(`${T1}/comments/byM1`).set({
        authorId: 'm1',
        text: 'First!',
        createdAt: day(2026, 10, 3),
      });
      await db.doc('projects/arch/tasks/t1/comments/byM1').set({
        authorId: 'm1',
        text: 'Old',
        createdAt: day(2026, 10, 3),
      });
      await db.doc(`${T1}/history/h1`).set({
        who: 'm1',
        action: 'help_requested',
        at: day(2026, 10, 3),
      });
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();
  const comments = (uid, task = T1) => as(uid).collection(`${task}/comments`);
  const history = (uid, task = T1) => as(uid).collection(`${task}/history`);
  const comment = (authorId, overrides = {}) => ({
    authorId,
    text: 'On it',
    createdAt: now(),
    ...overrides,
  });
  const accept = (who) => ({
    who,
    action: 'help_accepted',
    to: 'm1',
    at: now(),
  });
  const entry = (who, overrides = {}) => ({
    who,
    action: 'help_requested',
    from: 'in_progress',
    to: 'm2',
    at: now(),
    ...overrides,
  });

  describe('comments', () => {
    it('project members read; outsiders cannot', async () => {
      await assertSucceeds(comments('m2').get());
      await assertSucceeds(comments('admin').get());
      await assertFails(comments('outsider').get());
    });

    it('any project member posts as themselves', async () => {
      await assertSucceeds(comments('m2').add(comment('m2')));
      await assertSucceeds(comments('admin').add(comment('admin')));
    });

    it('rejects outsiders, forged authors, bad shapes and client times',
      async () => {
        await assertFails(comments('outsider').add(comment('outsider')));
        await assertFails(comments('m2').add(comment('m1')));
        await assertFails(comments('m2').add(comment('m2', { text: '   ' })));
        await assertFails(
          comments('m2').add(comment('m2', { text: 'x'.repeat(2001) })),
        );
        await assertFails(comments('m2').add(comment('m2', { pinned: true })));
        await assertFails(
          comments('m2').add(comment('m2', { createdAt: day(2026, 1, 1) })),
        );
      });

    it('no comments on a missing task or an archived project', async () => {
      await assertFails(
        comments('m2', 'projects/p1/tasks/nope').add(comment('m2')),
      );
      await assertFails(
        comments('m2', 'projects/arch/tasks/t1').add(comment('m2')),
      );
    });

    it('only the author edits, and only the text', async () => {
      const doc = (uid) => as(uid).doc(`${T1}/comments/byM1`);
      await assertSucceeds(
        doc('m1').update({ text: 'Edited', editedAt: now() }),
      );
      await assertFails(
        doc('admin').update({ text: 'Admin edit', editedAt: now() }),
      );
      await assertFails(doc('m2').update({ text: 'Nope', editedAt: now() }));
      await assertFails(
        doc('m1').update({ authorId: 'm2', editedAt: now() }),
      );
      await assertFails(
        doc('m1').update({ text: 'Edited', editedAt: day(2026, 1, 1) }),
      );
    });

    it('the author or a project Admin deletes; others cannot', async () => {
      await assertFails(as('m2').doc(`${T1}/comments/byM1`).delete());
      await assertFails(as('outsider').doc(`${T1}/comments/byM1`).delete());
      await assertSucceeds(as('m1').doc(`${T1}/comments/byM1`).delete());

      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc(`${T1}/comments/again`).set({
          authorId: 'm1',
          text: 'Again',
          createdAt: day(2026, 10, 4),
        }),
      );
      await assertSucceeds(as('admin').doc(`${T1}/comments/again`).delete());
    });

    it('nothing changes while the project is archived', async () => {
      const doc = (uid) => as(uid).doc('projects/arch/tasks/t1/comments/byM1');
      await assertFails(doc('m1').update({ text: 'x', editedAt: now() }));
      await assertFails(doc('m1').delete());
      await assertFails(doc('admin').delete());
    });
  });

  describe('history', () => {
    it('project members read; outsiders cannot', async () => {
      await assertSucceeds(history('m2').get());
      await assertFails(history('outsider').get());
    });

    it('the assignee or a project Admin writes an entry as themselves',
      async () => {
        await assertSucceeds(history('m1').add(entry('m1')));
        await assertSucceeds(
          history('admin').add(
            entry('admin', { action: 'status_changed', to: 'completed' }),
          ),
        );
      });

    it('rejects others, forged writers, unknown actions, bad shapes',
      async () => {
        await assertFails(history('m2').add(entry('m2')));
        await assertFails(history('outsider').add(entry('outsider')));
        await assertFails(history('m1').add(entry('admin')));
        await assertFails(history('m1').add(entry('m1', { action: 'hacked' })));
        await assertFails(history('m1').add(entry('m1', { extra: 1 })));
        await assertFails(history('m1').add(entry('m1', { to: 42 })));
        await assertFails(
          history('m1').add(entry('m1', { at: day(2026, 1, 1) })),
        );
        await assertFails(
          history('m1', 'projects/arch/tasks/t1').add(entry('m1')),
        );
      });

    it('entries are never updated or deleted, even by an Admin', async () => {
      const doc = (uid) => as(uid).doc(`${T1}/history/h1`);
      await assertFails(doc('m1').update({ action: 'created' }));
      await assertFails(doc('admin').update({ action: 'created' }));
      await assertFails(doc('m1').delete());
      await assertFails(doc('admin').delete());
    });
  });

  describe('help_accepted', () => {
    const acceptAt = (uid, task = BLOCKED, id = 'accept_req1') =>
      as(uid).doc(`${task}/history/${id}`).set(accept(uid));

    it('the helper named in the help note accepts once', async () => {
      await assertSucceeds(acceptAt('m2'));
      // Same request again: the entry exists, so this is an update.
      await assertFails(acceptAt('m2'));
    });

    it('only at accept_<requestId>, so it cannot be repeated elsewhere',
      async () => {
        await assertFails(acceptAt('m2', BLOCKED, 'accept_other'));
        await assertFails(
          as('m2').collection(`${BLOCKED}/history`).add(accept('m2')),
        );
      });

    it('other members, the assignee, an Admin and outsiders cannot',
      async () => {
        await assertFails(acceptAt('m3'));
        await assertFails(acceptAt('m1'));
        await assertFails(acceptAt('admin'));
        await assertFails(acceptAt('outsider'));
      });

    it('the assignee cannot accept even when named as the helper',
      async () => {
        await assertFails(acceptAt('m1', SELF, 'accept_req2'));
      });

    it('not on a task without a help request', async () => {
      await assertFails(acceptAt('m2', T1, 'accept_req1'));
      await assertFails(acceptAt('m2', T1, 'accept_'));
    });

    it('the helper cannot forge it as someone else or by the open path',
      async () => {
        await assertFails(
          as('m2').doc(`${BLOCKED}/history/accept_req1`).set(accept('m1')),
        );
        // The assignee/Admin path never allows help_accepted.
        await assertFails(
          as('admin').collection(`${BLOCKED}/history`).add(accept('admin')),
        );
      });

    it('not while the project is archived', async () => {
      await env.withSecurityRulesDisabled((ctx) =>
        ctx.firestore().doc('projects/arch/tasks/t1').update({
          helpNote: { text: 'x', taggedUserId: 'm2', requestId: 'r' },
        }),
      );
      await assertFails(acceptAt('m2', 'projects/arch/tasks/t1', 'accept_r'));
    });
  });

  describe('Need Help batch', () => {
    // Like TaskActivityRepository.requestHelp: the history entry's id is
    // stored as helpNote.requestId.
    const requestHelp = (uid, requestId = 'reqA') => {
      const db = as(uid);
      const batch = db.batch();
      batch.update(db.doc(T1), {
        status: 'blocked',
        helpNote: { text: 'Rules tests fail', taggedUserId: 'm2', requestId },
        updatedAt: now(),
      });
      batch.set(db.doc(`${T1}/history/${requestId}`), entry(uid));
      return batch.commit();
    };

    it('the assignee sets Blocked + help note + history at once', async () => {
      await assertSucceeds(requestHelp('m1'));
      const snap = await as('m2').doc(T1).get();
      // The note is visible to the rest of the team.
      if (snap.data().status !== 'blocked'
        || snap.data().helpNote.text !== 'Rules tests fail') {
        throw new Error('help request not stored');
      }
    });

    it('a project Admin can too', async () => {
      await assertSucceeds(requestHelp('admin'));
    });

    it('then the named helper accepts it', async () => {
      await assertSucceeds(requestHelp('m1'));
      await assertSucceeds(
        as('m2').doc(`${T1}/history/accept_reqA`).set(accept('m2')),
      );
    });

    it('a Member not assigned cannot (all or nothing)', async () => {
      await assertFails(requestHelp('m2'));
      const snap = await as('m2').doc(T1).get();
      if (snap.data().status !== 'in_progress') {
        throw new Error('partial write');
      }
    });
  });
});
