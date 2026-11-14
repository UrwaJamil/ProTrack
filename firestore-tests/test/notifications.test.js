// notifications/{nid}: the help-accepted notice written by the helper's
// app in the same batch as the `help_accepted` history entry (Phase 4).
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

// m1 = assignee who asked for help (request req1), m2 = the named
// helper, m3 = another Member, admin = Admin.
const MEMBERS = { admin: 'leader', m1: 'member', m2: 'member', m3: 'member' };
const TASK = 'projects/p1/tasks/t1';
const NID = 'help_accepted_req1';

describe('notification rules', () => {
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
      await db.doc(TASK).set(storedTask({
        status: 'blocked',
        helpNote: { text: 'Stuck', taggedUserId: 'm2', requestId: 'req1' },
      }));
      await db.doc(`${TASK}/history/req1`).set({
        who: 'm1',
        action: 'help_requested',
        from: 'in_progress',
        to: 'm2',
        at: day(2026, 10, 3),
      });
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();
  const notice = (sender, overrides = {}) => ({
    userId: 'm1',
    senderId: sender,
    type: 'help_accepted',
    projectId: 'p1',
    taskId: 't1',
    message: 'Mia accepted your help request',
    read: false,
    createdAt: now(),
    ...overrides,
  });

  // Like TaskActivityRepository.acceptHelp.
  const accept = (uid, { id = NID, data = notice(uid), withEntry = true } = {}) => {
    const db = as(uid);
    const batch = db.batch();
    if (withEntry) {
      batch.set(db.doc(`${TASK}/history/accept_req1`), {
        who: uid,
        action: 'help_accepted',
        to: 'm1',
        at: now(),
      });
    }
    batch.set(db.doc(`notifications/${id}`), data);
    return batch.commit();
  };

  const seedNotice = () =>
    env.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().doc(`notifications/${NID}`).set({
        ...notice('m2'),
        createdAt: day(2026, 10, 4),
      }),
    );

  it('the helper accepts: history entry + notice in one batch', async () => {
    await assertSucceeds(accept('m2'));
    await assertSucceeds(as('m1').doc(`notifications/${NID}`).get());
  });

  it('only once per request', async () => {
    await assertSucceeds(accept('m2'));
    await assertFails(accept('m2'));
    await assertFails(accept('m2', { withEntry: false }));
  });

  it('no notice without the accept entry in the same batch', async () => {
    await assertFails(accept('m2', { withEntry: false }));
  });

  it('only to the member who asked', async () => {
    await assertFails(accept('m2', { data: notice('m2', { userId: 'm3' }) }));
    await assertFails(accept('m2', { data: notice('m2', { userId: 'admin' }) }));
  });

  it('not by anyone but the named helper, and never as someone else',
    async () => {
      await assertFails(accept('m3'));
      await assertFails(accept('m1'));
      await assertFails(accept('admin'));
      await assertFails(accept('outsider'));
      await assertFails(accept('m2', { data: notice('m3') }));
    });

  it('fixed id, known type, valid shape', async () => {
    await assertFails(accept('m2', { id: 'random' }));
    // Only known types (help_accepted for now).
    await assertFails(accept('m2', { data: notice('m2', { type: 'spam' }) }));
    await assertFails(accept('m2', { data: notice('m2', { read: true }) }));
    await assertFails(accept('m2', { data: notice('m2', { extra: 1 }) }));
    await assertFails(
      accept('m2', { data: notice('m2', { message: 'x'.repeat(201) }) }),
    );
    await assertFails(
      accept('m2', { data: notice('m2', { createdAt: day(2026, 1, 1) }) }),
    );
  });

  it('only the recipient reads it', async () => {
    await seedNotice();
    await assertSucceeds(as('m1').doc(`notifications/${NID}`).get());
    await assertFails(as('m2').doc(`notifications/${NID}`).get());
    await assertFails(as('m3').doc(`notifications/${NID}`).get());
    await assertSucceeds(
      as('m1').collection('notifications').where('userId', '==', 'm1').get(),
    );
    await assertFails(as('m1').collection('notifications').get());
  });

  it('the recipient only flips read', async () => {
    await seedNotice();
    const doc = (uid) => as(uid).doc(`notifications/${NID}`);
    await assertSucceeds(doc('m1').update({ read: true }));
    await assertFails(doc('m1').update({ message: 'edited' }));
    await assertFails(doc('m1').update({ read: 'yes' }));
    await assertFails(doc('m2').update({ read: true }));
    await assertFails(doc('outsider').update({ read: true }));
  });

  it('only the recipient deletes', async () => {
    await seedNotice();
    const doc = (uid) => as(uid).doc(`notifications/${NID}`);
    await assertFails(doc('m2').delete());
    await assertFails(doc('admin').delete());
    await assertFails(doc('outsider').delete());
    await assertSucceeds(doc('m1').delete());
  });

  it('sender and recipient must share the project', async () => {
    // A recipient outside the project, even with the right request.
    await env.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().doc(`${TASK}/history/req1`).update({ who: 'outsider' }),
    );
    await assertFails(
      accept('m2', { data: notice('m2', { userId: 'outsider' }) }),
    );
  });

  it('a project is required, and it must be a real one', async () => {
    const noProject = notice('m2');
    delete noProject.projectId;
    await assertFails(accept('m2', { data: noProject }));
    await assertFails(
      accept('m2', { data: notice('m2', { projectId: 'nope' }) }),
    );
  });
});
