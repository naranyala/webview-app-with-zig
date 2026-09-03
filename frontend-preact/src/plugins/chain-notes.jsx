import { jsPDF } from 'jspdf';
import { useMemo, useState } from 'preact/hooks';

const starterNotes = [
  {
    id: 'north-star',
    title: 'Toolkit north star',
    tag: 'Planning',
    updated: 'Today',
    body: 'Build a collection of small tools that feel calm, fast, and useful.\n\nStart with the local desktop experience, then connect each tool to a focused backend service.'
  },
  {
    id: 'scanner-flow',
    title: 'Scanner flow',
    tag: 'Product',
    updated: 'Yesterday',
    body: '1. Pick a volume.\n2. Start a cancellable scan.\n3. Stream progress without blocking the window.\n4. Surface the largest folders first.'
  },
  {
    id: 'audio-ideas',
    title: 'Audio ideas',
    tag: 'Research',
    updated: 'Aug 28',
    body: 'Keep the first equalizer app-local. A system-wide audio route needs a separate platform and driver plan.'
  }
];

function chainLabel(id) {
  if (id === 'north-star') return '01';
  if (id === 'scanner-flow') return '02';
  return '03';
}

export function ChainNotes() {
  const [notes, setNotes] = useState(() =>
    starterNotes.map((note) => ({ ...note }))
  );
  const [activeNoteId, setActiveNoteId] = useState('north-star');
  const [noteQuery, setNoteQuery] = useState('');
  const [noteTitle, setNoteTitle] = useState(starterNotes[0].title);
  const [noteBody, setNoteBody] = useState(starterNotes[0].body);

  const filteredNotes = useMemo(
    () =>
      notes.filter((note) =>
        `${note.title} ${note.tag} ${note.body}`
          .toLowerCase()
          .includes(noteQuery.toLowerCase())
      ),
    [notes, noteQuery]
  );
  const noteWordCount = noteBody.trim()
    ? noteBody.trim().split(/\s+/).length
    : 0;

  function selectNote(note) {
    setActiveNoteId(note.id);
    setNoteTitle(note.title);
    setNoteBody(note.body);
  }

  function updateNote(title, body) {
    setNotes((current) =>
      current.map((item) =>
        item.id === activeNoteId
          ? {
              ...item,
              title: title || 'Untitled note',
              body,
              updated: 'Just now'
            }
          : item
      )
    );
  }

  function createNote() {
    const note = {
      id: `note-${Date.now()}`,
      title: 'Untitled note',
      tag: 'Draft',
      updated: 'Just now',
      body: 'Start writing here...'
    };
    setNotes((current) => [...current, note]);
    selectNote(note);
  }

  function exportNoteAsPdf() {
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    const margin = 52;
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const title = noteTitle || 'Untitled note';
    const safeName =
      title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '') || 'chain-note';
    let y = 72;

    doc.setTextColor(35, 36, 40);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(25);
    doc.text(title, margin, y);
    y += 24;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(110, 112, 120);
    doc.text(`CHAIN NOTES  /  ${new Date().toLocaleDateString()}`, margin, y);
    y += 28;
    doc.setDrawColor(220, 221, 224);
    doc.line(margin, y, pageWidth - margin, y);
    y += 28;
    doc.setTextColor(55, 56, 62);
    doc.setFontSize(11);

    const lines = doc.splitTextToSize(
      noteBody || 'Empty note.',
      pageWidth - margin * 2
    );
    for (const line of lines) {
      if (y > pageHeight - margin) {
        doc.addPage();
        y = margin;
      }
      doc.text(line, margin, y);
      y += 17;
    }

    doc.save(`${safeName}.pdf`);
  }

  return (
    <section className="tool-page">
      <div className="tool-heading">
        <div>
          <p className="eyebrow">Writing</p>
          <h1>Notes</h1>
          <p>Capture, search, export to PDF.</p>
        </div>
        <span className="mock-badge">Local</span>
      </div>

      <div className="notes-layout">
        <aside className="tool-panel notes-list-panel">
          <div className="notes-list-heading">
            <div>
              <span className="panel-label">Notebook</span>
              <h2>{notes.length} notes</h2>
            </div>
            <button
              type="button"
              className="new-note-button"
              onClick={createNote}
            >
              + New
            </button>
          </div>
          <label className="search-field">
            <span className="sr-only">Search notes</span>
            <input
              type="search"
              placeholder="Search…"
              value={noteQuery}
              onInput={(event) => setNoteQuery(event.currentTarget.value)}
            />
          </label>
          <div className="notes-list">
            {filteredNotes.map((note) => (
              <button
                type="button"
                key={note.id}
                className={`note-list-item${activeNoteId === note.id ? ' active' : ''}`}
                onClick={() => selectNote(note)}
              >
                <span className="note-list-meta">
                  <span>{note.tag}</span>
                  <span>{note.updated}</span>
                </span>
                <strong>{note.title}</strong>
                <span>{note.body.replace(/\s+/g, ' ').slice(0, 72)}</span>
              </button>
            ))}
            {filteredNotes.length === 0 && (
              <p className="empty-notes">No notes found.</p>
            )}
          </div>
        </aside>

        <article className="tool-panel note-editor">
          <div className="note-editor-heading">
            <div>
              <span className="panel-label">
                Chain / {chainLabel(activeNoteId)}
              </span>
              <span className="note-saved">Saved locally</span>
            </div>
            <button
              type="button"
              className="export-button"
              onClick={exportNoteAsPdf}
            >
              PDF
            </button>
          </div>
          <input
            className="note-title-input"
            aria-label="Note title"
            value={noteTitle}
            onInput={(event) => {
              const next = event.currentTarget.value;
              setNoteTitle(next);
              updateNote(next, noteBody);
            }}
          />
          <div className="note-meta-row">
            <span>{noteWordCount} words</span>
          </div>
          <textarea
            className="note-body-input"
            aria-label="Note body"
            value={noteBody}
            onInput={(event) => {
              const next = event.currentTarget.value;
              setNoteBody(next);
              updateNote(noteTitle, next);
            }}
          />
          <div className="note-editor-footer">
            <span>Exports current note only.</span>
            <button
              type="button"
              className="text-button"
              onClick={exportNoteAsPdf}
            >
              Download →
            </button>
          </div>
        </article>
      </div>
    </section>
  );
}
