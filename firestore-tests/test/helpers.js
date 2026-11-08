// Shared setup for the rules tests. Run through `npm test`, which starts
// the Firestore emulator (needs Java 21+) and sets FIRESTORE_EMULATOR_HOST.
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const { FieldValue, Timestamp } = firebase.firestore;

async function createEnv() {
  const [host, port] = (
    process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080'
  ).split(':');
  return initializeTestEnvironment({
    projectId: 'demo-protrack',
    firestore: {
      host,
      port: Number(port),
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
}

const day = (y, m, d) => Timestamp.fromDate(new Date(y, m - 1, d));

/** A project doc as the app writes it (members + matching memberIds). */
function projectDoc(members, overrides = {}) {
  return {
    name: 'Mobile App Redesign',
    description: '',
    startDate: day(2026, 10, 1),
    deadline: day(2026, 11, 28),
    status: 'active',
    createdBy: 'admin',
    members,
    memberIds: Object.keys(members),
    createdAt: day(2026, 10, 1),
    updatedAt: day(2026, 10, 1),
    ...overrides,
  };
}

/** A stored task (already-resolved timestamps), for seeding. */
function storedTask(overrides = {}) {
  return {
    title: 'Design login screen',
    description: 'Mockups for light and dark mode.',
    assignedTo: ['m1'],
    priority: 'medium',
    status: 'todo',
    deadline: day(2026, 10, 30),
    subtasks: [
      { title: 'Wireframes', done: false },
      { title: 'Review', done: false },
    ],
    createdBy: 'admin',
    createdAt: day(2026, 10, 2),
    updatedAt: day(2026, 10, 2),
    ...overrides,
  };
}

/** A task as `TaskRepository.create` sends it. */
function newTask(createdBy, overrides = {}) {
  return {
    ...storedTask({ createdBy }),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    ...overrides,
  };
}

module.exports = {
  createEnv,
  day,
  projectDoc,
  storedTask,
  newTask,
  FieldValue,
  Timestamp,
};
