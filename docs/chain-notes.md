# Chain Notes

Local Q&A notebook for external AI chats: each exchange is one record with a
title, a **Question**, and an **Answer**, persisted on-device and searchable
with typo tolerance.

## Q&A model

Stored bodies use a canonical plain-text envelope so old and new clients stay
compatible:

```text
Question:
<question text>

Answer:
<answer text>
```

- `frontend-preact/src/plugins/qna.js` — `serializeQna` / `parseStoredQna` /
  `parseExternalChat`. Legacy free-form bodies still parse (question empty,
  whole body as answer).
- Import accepts `Question:`/`Answer:`, `Q:`/`A:`, `User:`/`Assistant:`
  (Markdown bold variants included), or two plain paragraphs.
- `check-qna.mjs` covers round-trips, legacy notes, and every import shape.

## Persistence

- **Native shell**: Zig `Storage` (`src/backend/storage.zig`) keeps a
  versioned `state.json` (`{version, counter, notes}`) in the OS data dir,
  with atomic tmp-file + rename writes and reload tests.
- **Browser dev**: `backend.js` mocks persist to `localStorage` ( guarded —
  the native shell's opaque origin throws, so it falls back to memory).

## Fuzzy search

`src/plugins/note-search.js` exposes one production engine behind
`createNoteSearcher` / `searchNotes`; the alternatives live on only for
comparison in `benchmark-notes-search.mjs`:

| Engine | Role | 1,200 records, typo queries |
| --- | --- | --- |
| fuzzysort | Production default | ~2.4 ms avg, selective matches |
| Fuse.js | Benchmark comparison | ~38 ms avg |
| fast-fuzzy | Benchmark comparison | ~3.8 ms avg, ~126 ms index |
| Exact | Substring baseline | ~0.6 ms avg, 0 typo matches |

```sh
cd frontend-preact && npm run benchmark:notes
```

`check-note-search.mjs` asserts exact-match behavior plus typo recall;
`check-note-search-benchmark.mjs` asserts fuzzysort stays faster than Fuse on
the same workload. Note: fuzzysort matches subsequences, so benchmarks use
omission-style typos (`persistnce`), not substitutions.

## Markdown

`src/plugins/note-markdown.js` parses a dependency-free subset — fenced code
(indentation preserved, unclosed fences run to EOF), `#`–`####` headings,
`-`/`1.` lists, `>` quotes, `---` rules, `**bold**` / `*italic*` / `` `code` ``
— shared by screen, print, and PDF paths. `check-note-markdown.mjs` covers it.

## PDF export

`src/plugins/note-pdf.js` renders the same block model through three engines:

| Engine | Avg, one note (~4 KB) | Avg, 20-note chain | Notes |
| --- | --- | --- | --- |
| jsPDF (default) | ~2.8 ms | ~12.9 ms | Fastest |
| pdf-lib | ~5.4 ms, smallest files | ~37.7 ms | Smallest output |
| pdfmake | ~81 ms, largest files | ~131 ms | Embeds Roboto; declarative |

```sh
cd frontend-preact && npm run benchmark:pdf
```

- `Note ->` exports the active exchange; `Chain ->` exports every visible
  exchange as one multi-page document.
- **Native shell**: bytes go through the `savePdf` binding into the user's
  Documents folder (validated name, unique filenames, `Saved to …` feedback).
  **Browser**: anchor download instead.
- **Print** renders the chain into a print-only page under a strict CSS reset
  (`PRINT_CSS_RESET`: `@page` margins, normalized type, `pre-wrap` code,
  page-break rules), so the OS print dialog — including Save as PDF — handles
  output deterministically.
- Code blocks render monospace with shaded backgrounds in every engine;
  non-WinAnsi characters degrade to `?` in pdf-lib instead of throwing.
