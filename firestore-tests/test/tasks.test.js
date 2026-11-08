// Task rules: projects/{pid}/tasks/{tid} and the "My Tasks"
// collection-group read (CLAUDE.md decision 3, FR-3.1–3.6).
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  createEnv,
  day,
  projectDoc,
  storedTask,
  newTask,
  FieldValue,
  Timestamp,
} = require('./helpers');

// admin = creator/Admin, admin2 = second Admin, m1 = assignee,
// m2 = Member not assigned, outsider = not in the project.
const MEMBERS = {
  admin: 'leader',
  admin2: 'leader',
  m1: 'member',
  m2: 'member',
};

describe('task rules', () => {
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
      await db.doc('projects/p1/tasks/t1').set(storedTask());
      // Assigned to someone no longer in the project.
      await db
        .doc('projects/p1/tasks/stale')
        .set(storedTask({ assignedTo: ['gone'] }));
      await db.doc('projects/arch/tasks/t1').set(storedTask());
    });
  });

  const as = (uid) => env.authenticatedContext(uid).firestore();
  const task = (uid, path = 'projects/p1/tasks/t1') => as(uid).doc(path);
  const tasks = (uid, project = 'p1') =>
    as(uid).collection(`projects/${project}/tasks`);
  const now = () => FieldValue.serverTimestamp();

  describe('read', () => {
    it('any project member can read and list tasks', async () => {
      await assertSucceeds(task('m2').get());
      await assertSucceeds(tasks('m2').get());
      await assertSucceeds(task('admin').get());
    });

    it('outsiders and signed-out users cannot', async () => {
      await assertFails(task('outsider').get());
      await assertFails(tasks('outsider').get());
      await assertFails(
        env.unauthenticatedContext().firestore().doc('projects/p1/tasks/t1')
          .get(),
      );
    });

    it('My Tasks: a collection-group query on your own uid works',
      async () => {
        const snap = await assertSucceeds(
          as('m1')
            .collectionGroup('tasks')
            .where('assignedTo', 'array-contains', 'm1')
            .get(),
        );
        // p1/t1 and arch/t1.
        if (snap.size !== 2) throw new Error(`expected 2, got ${snap.size}`);
      });

    it("a collection-group query for someone else's tasks is refused",
      async () => {
        await assertFails(
          as('m2')
            .collectionGroup('tasks')
            .where('assignedTo', 'array-contains', 'm1')
            .get(),
        );
        await assertFails(as('m1').collectionGroup('tasks').get());
      });
  });

  describe('create (Admin only, FR-3.1–3.3)', () => {
    it('a project Admin can create a valid task', async () => {
      await assertSucceeds(tasks('admin').add(newTask('admin')));
      await assertSucceeds(tasks('admin2').add(newTask('admin2')));
    });

    it('accepts every status, including on_hold', async () => {
      for (const status of [
        'todo', 'in_progress', 'on_hold', 'blocked', 'completed',
      ]) {
        await assertSucceeds(tasks('admin').add(newTask('admin', { status })));
      }
    });

    it('Members and outsiders cannot create tasks', async () => {
      await assertFails(tasks('m1').add(newTask('m1')));
      await assertFails(tasks('outsider').add(newTask('outsider')));
    });

    it('rejects assignees outside the project', async () => {
      await assertFails(
        tasks('admin').add(newTask('admin', { assignedTo: ['m1', 'outsider'] })),
      );
      await assertFails(
        tasks('admin').add(newTask('admin', { assignedTo: ['m1', 'm1'] })),
      );
    });

    it('rejects a forged creator or client timestamps', async () => {
      await assertFails(tasks('admin').add(newTask('admin2')));
      await assertFails(
        tasks('admin').add(
          newTask('admin', { createdAt: Timestamp.fromDate(new Date()) }),
        ),
      );
    });

    it('rejects bad values and unknown fields', async () => {
      const bad = [
        { title: '' },
        { title: 'x'.repeat(101) },
        { description: 'x'.repeat(2001) },
        { status: 'not_started' },
        { status: 'done' },
        { priority: 'urgent' },
        { deadline: '2026-10-30' },
        { subtasks: 'nope' },
        { secret: true },
      ];
      for (const overrides of bad) {
        await assertFails(tasks('admin').add(newTask('admin', overrides)));
      }
    });

    it('rejects a task missing a required field', async () => {
      const t = newTask('admin');
      delete t.deadline;
      await assertFails(tasks('admin').add(t));
    });

    it('nothing can be created in an archived project', async () => {
      await assertFails(tasks('admin', 'arch').add(newTask('admin')));
    });
  });

  describe('update by an Admin', () => {
    it('can edit and reassign', async () => {
      await assertSucceeds(
        task('admin').update({
          title: 'Design login + signup',
          assignedTo: ['m2'],
          priority: 'high',
          deadline: day(2026, 11, 2),
          subtasks: [{ title: 'Only one', done: false }],
          status: 'in_progress',
          updatedAt: now(),
        }),
      );
    });

    it('cannot change createdBy / createdAt or skip updatedAt', async () => {
      await assertFails(
        task('admin').update({ createdBy: 'admin2', updatedAt: now() }),
      );
      await assertFails(
        task('admin').update({ createdAt: day(2026, 1, 1), updatedAt: now() }),
      );
      await assertFails(task('admin').update({ title: 'No timestamp' }));
    });

    it('cannot assign someone outside the project', async () => {
      await assertFails(
        task('admin').update({ assignedTo: ['outsider'], updatedAt: now() }),
      );
    });

    it('cannot edit tasks of an archived project', async () => {
      await assertFails(
        task('admin', 'projects/arch/tasks/t1').update({
          title: 'x',
          updatedAt: now(),
        }),
      );
    });
  });

  describe('update by the assignee (FR-3.5, FR-3.6)', () => {
    it('can change status', async () => {
      for (const status of ['in_progress', 'on_hold', 'completed', 'todo']) {
        await assertSucceeds(task('m1').update({ status, updatedAt: now() }));
      }
    });

    it('can tick subtasks (same count)', async () => {
      await assertSucceeds(
        task('m1').update({
          subtasks: [
            { title: 'Wireframes', done: true },
            { title: 'Review', done: false },
          ],
          updatedAt: now(),
        }),
      );
    });

    it('cannot add or remove subtasks', async () => {
      await assertFails(
        task('m1').update({
          subtasks: [{ title: 'Wireframes', done: true }],
          updatedAt: now(),
        }),
      );
    });

    it('cannot touch Admin-only fields', async () => {
      const forbidden = [
        { title: 'Mine now' },
        { description: 'Less work' },
        { assignedTo: ['m1', 'm2'] },
        { priority: 'low' },
        { deadline: day(2027, 1, 1) },
        { createdBy: 'm1' },
      ];
      for (const change of forbidden) {
        await assertFails(task('m1').update({ ...change, updatedAt: now() }));
      }
    });

    it('cannot set an invalid status or a client updatedAt', async () => {
      await assertFails(task('m1').update({ status: 'done', updatedAt: now() }));
      await assertFails(
        task('m1').update({
          status: 'completed',
          updatedAt: Timestamp.fromDate(new Date()),
        }),
      );
    });

    it('a Member not assigned to the task cannot update it', async () => {
      await assertFails(task('m2').update({ status: 'completed', updatedAt: now() }));
    });

    it('a stale assignee no longer in the project cannot update it',
      async () => {
        await assertFails(
          task('gone', 'projects/p1/tasks/stale').update({
            status: 'completed',
            updatedAt: now(),
          }),
        );
      });

    it('cannot update tasks of an archived project', async () => {
      await assertFails(
        task('m1', 'projects/arch/tasks/t1').update({
          status: 'completed',
          updatedAt: now(),
        }),
      );
    });
  });

  describe('delete', () => {
    it('only a project Admin of an active project', async () => {
      await assertFails(task('m1').delete());
      await assertFails(task('outsider').delete());
      await assertFails(task('admin', 'projects/arch/tasks/t1').delete());
      await assertSucceeds(task('admin2').delete());
    });
  });

  describe('removing a member unassigns them (one transaction)', () => {
    it('an Admin can drop m1 from the project and its tasks together',
      async () => {
        const db = as('admin');
        const { m1: _removed, ...rest } = MEMBERS;
        await assertSucceeds(
          db.runTransaction(async (tx) => {
            const projectRef = db.doc('projects/p1');
            await tx.get(projectRef);
            tx.update(projectRef, {
              members: rest,
              memberIds: Object.keys(rest),
              updatedAt: now(),
            });
            tx.update(db.doc('projects/p1/tasks/t1'), {
              assignedTo: FieldValue.arrayRemove('m1'),
              updatedAt: now(),
            });
          }),
        );
        // m1 can no longer read the task, directly or via My Tasks.
        await assertFails(task('m1').get());
      });
  });
});
