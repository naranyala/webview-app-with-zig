# Testing

Three layers: Zig unit tests, Node check scripts, and vitest component
tests, all reachable from one command. CI
(`.github/workflows/ci.yml`: GTK/WebKitGTK + Zig 0.16.0 + Node 20) runs
dependency checks, `zig build test --summary all`, and `zig build`.

## Commands

| Command | Covers |
| --- | --- |
| `zig build test --summary all` | Everything: backend unit tests + all frontend checks below |
| `zig build` | Full frontend build + native binary |
| `zig build run` / `./run.sh` | Build and launch the GUI |
| `zig build dev` | Frontend dev server |
| `cd frontend-preact && npm test` | All `check-*.mjs` suites in order, then vitest component tests |
| `npm run test:components` | `vitest run` over `src/**/*.test.jsx` (jsdom) |
| `npm run check` | Biome lint + format over the frontend |
| `npm run check:bindings` | `bindings.d.ts` + `backend.js` in sync with `bound_names` (14) |
| `npm run build` | `check` + `check:bindings` + single-file `dist/index.html` |

## Frontend suites (`frontend-preact/check-*.mjs`)

| Suite | Covers |
| --- | --- |
| `check-backend-errors` | Envelope normalization, timeouts, validation, mocks, `savePdf` bridge |
| `check-quiz-data` | Bundled quiz collections |
| `check-qna` | Q&A serialization, legacy notes, chat import shapes |
| `check-note-markdown` | Markdown blocks, inline spans, figure embeds, SVG sanitize, print reset |
| `check-paper` | Paper model, validation, citations, figures, stats |
| `check-note-search` | Production search: exact rank, typo recall, empty/unknown queries |
| `check-note-search-benchmark` | 300-note benchmark; fuzzysort faster than Fuse, < 50 ms avg |
| `check-note-pdf` | Per-engine PDF validity, markdown/code, figures (placeholder + raster), chain growth |
| `check-note-pdf-benchmark` | Single + chain budgets (2 s / 5 s per engine) |
| `check-paper-pdf` | Per-engine paper render, raster figures, fallback |
| `check-paper-pdf-benchmark` | Sample-paper budget (5 s per engine) |

## Component tests (`vitest run`)

`frontend-preact/vitest.config.js`: jsdom environment, first-party
`@preact/preset-vite` for JSX, and an alias swapping the compile-time
StyleX runtime for `test/stylex-stub.js` (`create` = identity, `props`
returns a fixed class name — components under test only read `className`).
Suites live next to the code as `src/**/*.test.jsx`; today that is
`src/plugins/todo.test.jsx` (empty render, add, toggle, status filter,
calendar-month render). Pure logic stays in `check-*.mjs`; vitest covers
rendered-component behavior only. Note: pinned `esbuild@0.25` conflicts
with vite's peer range, so `package.json` pins `"overrides":
{ "esbuild": "$esbuild" }` — plain `npm install` / `npm ci` work with no
flags and the committed lockfile keeps CI deterministic.

## Benchmarks

| Command | Workload |
| --- | --- |
| `npm run benchmark:notes` | 1,200 notes × 20 typo searches per search engine |
| `npm run benchmark:pdf` | One note × 10 plus 20-note chain × 5 per PDF engine |
| `npm run benchmark:paper` | Sample paper × 5 per PDF engine |

Benchmark scripts double as imports for the automated budget checks above.

## Backend tests (`zig build test`)

Unit tests live next to the code: counter/timestamp/health (`backend.zig`),
PDF filename/payload/disk round-trips (`backend.zig`), storage CRUD + reload
(`storage.zig`), registry ordering/dupes/lifecycle (`plugin.zig`), binding-set
uniqueness (`core_plugin.zig`), config and logging.
