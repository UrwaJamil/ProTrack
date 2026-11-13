// notifications/{nid} of type help_requested: the notice to the named
// helper, written by the requester's app in the same batch as the task's
// Blocked + helpNote update and the `help_requested` history entry
// (TaskActivityRepository.requestHelp).
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  createEnv,
  projectDoc,
  storedTask,
  FieldValue,
} = require('./helpers');

// m1 = assignee asking for help, m2 = the named helper, m3 = another
// Member, admin = Admin.
const MEMBERS = { admin: 'leader', m1: 'member', m2: 'member', m3: 'member' };
const TASK = 'projects/p1/tasks/t1';

describe('help_requested notification rules', () => {
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
      await db.doc(TASK).set(storedTask({ status: 'in_progress' }));
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();
  const notice = (sender, overrides = {}) => ({
    userId: 'm2',
    senderId: sender,
    type: 'help_requested',
    projectId: 'p1',
    taskId: 't1',
    message: 'Sam requested your help on Design login screen',
    read: false,
    createdAt: now(),
    ...overrides,
  });

  // Like TaskActivityRepository.requestHelp.
  const request = (uid, {
    requestId = 'req1',
    helper = 'm2',
    id = `help_requested_${requestId}`,
    data = notice(uid),
    withEntry = true,
    withTask = true,
  } = {}) => {
    const db = as(uid);
    const batch = db.batch();
    batch.set(db.doc(`notifications/${id}`), data);
    if (withTask) {
      batch.update(db.doc(TASK), {
        status: 'blocked',
        helpNote: { text: 'Stuck', taggedUserId: helper, requestId },
        updatedAt: now(),
      });
    }
    if (withEntry) {
      batch.set(db.doc(`${TASK}/history/${requestId}`), {
        who: uid,
        action: 'help_requested',
        from: 'in_progress',
        to: helper,
        at: now(),
      });
    }
    return batch.commit();
  };

  it('the requester notifies the named helper in the same batch',
    async () => {
      await assertSucceeds(request('m1'));
      await assertSucceeds(as('m2').doc('notifications/help_requested_req1').get());
      await assertFails(as('m1').doc('notifications/help_requested_req1').get());
    });

  it('only once per request', async () => {
    await assertSucceeds(request('m1'));
    await assertFails(request('m1', { withEntry: false }));
    await assertFails(request('m1', { withEntry: false, withTask: false }));
  });

  it('never without the request entry and help note in the same batch',
    async () => {
      await assertFails(request('m1', { withEntry: false }));
      await assertFails(request('m1', { withTask: false }));
    });

  it('only to the helper the note names', async () => {
    await assertFails(request('m1', { data: notice('m1', { userId: 'm3' }) }));
    await assertFails(request('m1', { helper: 'm3' }));
    await assertFails(request('m1', { data: notice('m1', { userId: 'm1' }) }));
  });

  it('never as someone else, never by an outsider', async () => {
    await assertFails(request('m1', { data: notice('m3') }));
    await assertFails(request('outsider'));
  });

  it('fixed id and valid shape', async () => {
    await assertFails(request('m1', { id: 'random' }));
    await assertFails(request('m1', { id: 'help_accepted_req1' }));
    await assertFails(request('m1', { data: notice('m1', { read: true }) }));
    await assertFails(request('m1', { data: notice('m1', { extra: 1 }) }));
    await assertFails(
      request('m1', { data: notice('m1', { message: 'x'.repeat(201) }) }),
    );
  });
});
