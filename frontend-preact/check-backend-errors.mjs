// Bridge error-handling tests: normalization, timeouts, client-side
// validation, and mock/unavailable behavior in `src/backend.js`.
// Run: `npm test`. `zig build test` runs it via `npm run test`.
import {
  backend,
  backendError,
  errorDetails,
  getDefaultTimeout,
  setDefaultTimeout
} from './src/backend.js';

let failures = 0;

function check(name, condition, extra = '') {
  if (condition) {
    console.log(`ok: ${name}`);
  } else {
    failures += 1;
    console.error(`FAIL: ${name}${extra ? ` (${extra})` : ''}`);
  }
}

function withWindow(stub, fn) {
  const previous = globalThis.window;
  globalThis.window = stub;
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      if (previous === undefined) delete globalThis.window;
      else globalThis.window = previous;
    });
}

// 1. Mock fallbacks when no bindings exist.
await withWindow({}, async () => {
  check('mock increment resolves 0', (await backend.increment(1)) === 0);
  check('mock getStatus resolves ok', (await backend.getStatus()) === 'ok');
});

// 2. Native values pass through with args forwarded.
await withWindow(
  {
    increment: (delta) => Promise.resolve(delta * 2),
    getStatus: () => Promise.resolve('ok')
  },
  async () => {
    check('native increment forwards args', (await backend.increment(21)) === 42);
    check('native getStatus passes through', (await backend.getStatus()) === 'ok');
  }
);

// 3. Structured envelope rejections normalize to code + message.
await withWindow(
  {
    increment: () =>
      Promise.reject(
        new Error('{"code":"MalformedJson","message":"arguments must be JSON"}')
      )
  },
  async () => {
    try {
      await backend.increment(1);
      check('envelope rejection surfaces', false);
    } catch (error) {
      const details = errorDetails(error);
      check('envelope code preserved', details.code === 'MalformedJson', details.code);
      check(
        'envelope message preserved',
        details.message === 'arguments must be JSON',
        details.message
      );
    }
  }
);

// 4. Bare backend error names map to friendly messages.
await withWindow(
  { minimizeWindow: () => Promise.reject(new Error('"WindowUnavailable"')) },
  async () => {
    try {
      await backend.minimizeWindow();
      check('bare-name rejection surfaces', false);
    } catch (error) {
      const details = errorDetails(error);
      check('bare-name code preserved', details.code === 'WindowUnavailable', details.code);
      check(
        'bare-name has friendly message',
        details.message === 'The native window is unavailable.',
        details.message
      );
    }
  }
);

// 5. Hanging bindings time out with code Timeout.
setDefaultTimeout(30);
await withWindow({ getStatus: () => new Promise(() => {}) }, async () => {
  try {
    await backend.getStatus();
    check('timeout fires', false);
  } catch (error) {
    check('timeout code is Timeout', errorDetails(error).code === 'Timeout');
  }
});
setDefaultTimeout(getDefaultTimeout() === 30 ? 5000 : getDefaultTimeout());
check('default timeout restored', getDefaultTimeout() === 5000);

// 6. Missing bindings with mocks disabled reject as Unavailable.
await withWindow({ __PREACT_MOCK_BRIDGE__: false }, async () => {
  try {
    await backend.reset();
    check('unavailable rejection surfaces', false);
  } catch (error) {
    check('unavailable code is Unavailable', errorDetails(error).code === 'Unavailable');
  }
});

// 7. Client-side validation rejects without touching the binding.
let bindingCalled = false;
await withWindow(
  {
    increment: () => {
      bindingCalled = true;
      return Promise.resolve(0);
    }
  },
  async () => {
    try {
      await backend.increment('two');
      check('invalid delta rejected', false);
    } catch (error) {
      check('invalid delta code is InvalidArgument', errorDetails(error).code === 'InvalidArgument');
      check('binding not called for invalid delta', bindingCalled === false);
    }
  }
);

// 8. backendError stays a display string for all shapes.
check(
  'backendError formats envelopes',
  backendError(new Error('{"code":"Timeout","message":"slow"}')) === 'slow'
);
check(
  'backendError formats unknown input',
  typeof backendError(null) === 'string' && backendError(null).length > 0
);

if (failures > 0) {
  console.error(`${failures} bridge error test(s) failed`);
  process.exit(1);
}
console.log('bridge error handling: all tests passed');
