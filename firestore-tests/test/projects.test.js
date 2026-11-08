// Project rules (CLAUDE.md decision 3, Phase 2) — verified by hand in the
// Rules Playground until Phase 3 brought the emulator tests.
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { createEnv, day, projectDoc, FieldValue } = require('./helpers');

describe('project rules', () => {
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
      await db.doc('users/admin').set({ defaultRole: 'leader' });
      await db.doc('users/m1').set({ defaultRole: 'member' });
      await db
        .doc('projects/p1')
        .set(projectDoc({ admin: 'leader', m1: 'member' }));
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const now = () => FieldValue.serverTimestamp();

  const newProject = (uid, overrides = {}) => ({
    ...projectDoc({ [uid]: 'leader' }, { createdBy: uid }),
    createdAt: now(),
    updatedAt: now(),
    ...overrides,
  });

  it('members read; outsiders cannot', async () => {
    await assertSucceeds(as('m1').doc('projects/p1').get());
    await assertFails(as('outsider').doc('projects/p1').get());
    await assertSucceeds(
      as('m1')
        .collection('projects')
        .where('memberIds', 'array-contains', 'm1')
        .get(),
    );
    await assertFails(as('m1').collection('projects').get());
  });

  it('only default-role Admins create, as sole leader', async () => {
    await assertSucceeds(as('admin').collection('projects').add(newProject('admin')));
    await assertFails(as('m1').collection('projects').add(newProject('m1')));
    await assertFails(
      as('admin')
        .collection('projects')
        .add(
          newProject('admin', {
            members: { admin: 'leader', m1: 'member' },
            memberIds: ['admin', 'm1'],
          }),
        ),
    );
  });

  it('only a project leader updates; invariants hold', async () => {
    const ref = (uid) => as(uid).doc('projects/p1');
    await assertSucceeds(ref('admin').update({ name: 'Renamed', updatedAt: now() }));
    await assertFails(ref('m1').update({ name: 'Mine', updatedAt: now() }));
    // memberIds must match members.
    await assertFails(
      ref('admin').update({ memberIds: ['admin'], updatedAt: now() }),
    );
    // Creator stays leader; deadline after start.
    await assertFails(
      ref('admin').update({
        members: { admin: 'member', m1: 'member' },
        updatedAt: now(),
      }),
    );
    await assertFails(
      ref('admin').update({ deadline: day(2026, 9, 1), updatedAt: now() }),
    );
  });

  it('only a project leader deletes', async () => {
    await assertFails(as('m1').doc('projects/p1').delete());
    await assertSucceeds(as('admin').doc('projects/p1').delete());
  });
});
