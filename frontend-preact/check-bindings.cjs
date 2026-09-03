// Guards `bindings.d.ts` + `src/backend.js` against drift from
// `src/backend/core_plugin.zig` (`bound_names`).
// Run: `npm run check:bindings`. CI runs it after `npm run check`.
const fs = require('node:fs');
const path = require('node:path');

const expected = [
  'increment',
  'reset',
  'getSystemInfo',
  'getTimestamp',
  'getStatus',
  'minimizeWindow',
  'maximizeWindow',
  'restoreWindow',
  'closeWindow'
];

const root = __dirname;
const bindings = fs.readFileSync(
  path.join(root, 'src', 'bindings.d.ts'),
  'utf8'
);
const bridge = fs.readFileSync(
  path.join(root, 'src', 'backend.js'),
  'utf8'
);

let failed = false;
for (const name of expected) {
  if (!bindings.includes(name)) {
    console.error(`missing ${name} in src/bindings.d.ts`);
    failed = true;
  }
  if (!bridge.includes(name)) {
    console.error(`missing ${name} in src/backend.js`);
    failed = true;
  }
}

if (failed) process.exit(1);
console.log(`bindings in sync (${expected.length} names)`);
