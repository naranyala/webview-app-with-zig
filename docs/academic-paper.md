# Academic Paper

Document workspace for reading papers: a storage-ready abstraction, a
two-column reader, and Reference Manager / Image Assets submenus in the Paper
sidebar (Reader ▶ · References ≡ · Images ◫).

## Abstraction (`paper.js`, `paper-data.js`)

```js
{
  id: 'local-first-chain-notes',   // slug
  title, subtitle,
  authors: [{ name, affiliation, email }],
  venue, year, status: 'draft' | 'final',
  abstract, keywords: [],
  sections: [{ id, title, body }], // markdown bodies
  references: [{ key, text }],
  figures: [{ id, caption, credit, svg?, dataUrl? }]
}
```

- `createPaper()` fills defaults (slugified id, `draft` status).
- `validatePaper()` checks slugs, required fields, unique section ids /
  reference keys / figure ids, figure shapes, and cited-but-unlisted keys.
- **Citations**: `[@key]` markers are numbered by first appearance (abstract
  first, then sections) via `resolveCitations()`. Unknown keys keep their
  number with a "Missing reference." placeholder and are reported in
  `missing`. `citationCounts()` maps each key to its occurrence count.
- `paperStats()` reports words, sections, references, figures, reading
  minutes. A bundled sample paper ships so the workspace opens complete.

## Reader

- **Final** status reads in true two-column flow (`column-width`, justified,
  hyphenated, column rule), collapsing to one column on narrow screens;
  **Draft** reads single-column. Toggle with chips.
- Serif reader typography, title/author/abstract/keyword header, section nav
  with smooth scroll, numbered references, live stats in the lede.
- One HTML builder (`paperContentHtml`) feeds both screen and print, so the
  two never drift.

## Reference Manager (`reference-manager.jsx`)

- Bibliography in citation order with cited-× counts and uncited badges.
- Missing-key inbox: cited-but-unlisted keys get one-click "Track it".
- Key rename cascades through abstract + sections; inline text editing;
  delete; validated add form; model problems surfaced inline.
- BibTeX export (`@misc` entries): generate → copy → download.

## Image Assets (`image-assets.jsx`)

- Figure library with previews, editable captions/credits, per-section usage
  tracking, and delete.
- PNG/JPEG uploads (≤ 1.5 MB, embedded for real everywhere) and SVG paste /
  upload (crisp inline in reader and print).
- Embed with `![Caption](fig:id)` on its own line → numbered `Figure N` in
  the reader, print, and all PDF engines. Vector art shows a labeled
  placeholder box in PDFs (none of the PDF libraries rasterize SVG);
  unknown ids render as labeled boxes instead of breaking.
- Pasted SVG is sanitized (scripts, event handlers, `javascript:` URLs
  stripped) before entering the reader DOM.

## PDF and print

`paper-pdf.js` converts the paper model into the shared PDF block pipeline —
title block, authors, abstract, keywords, one heading per section, numbered
reference list — across jsPDF, pdf-lib, and pdfmake:

```sh
cd frontend-preact && npm run benchmark:paper
```

| Engine | Avg, sample paper | Output |
| --- | --- | --- |
| jsPDF | ~24 ms | ~36 KB |
| pdf-lib | ~39 ms | ~11 KB, smallest |
| pdfmake | ~253 ms | ~44 KB |

Native exports save into Documents via `savePdf`; the browser downloads.
`Print` renders the two-column print reset (`PAPER_PRINT_CSS`) for the OS
dialog. `check-paper.mjs`, `check-paper-pdf.mjs`, and
`check-paper-pdf-benchmark.mjs` (budget: 5 s/engine) cover the feature.
