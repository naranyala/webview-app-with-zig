<script>
  import { jsPDF } from "jspdf";

  const starterNotes = [
    {
      id: "north-star",
      title: "Toolkit north star",
      tag: "Planning",
      updated: "Today",
      body: "Build a collection of small tools that feel calm, fast, and useful.\n\nStart with the local desktop experience, then connect each tool to a focused backend service.",
    },
    {
      id: "scanner-flow",
      title: "Scanner flow",
      tag: "Product",
      updated: "Yesterday",
      body: "1. Pick a volume.\n2. Start a cancellable scan.\n3. Stream progress without blocking the window.\n4. Surface the largest folders first.",
    },
    {
      id: "audio-ideas",
      title: "Audio ideas",
      tag: "Research",
      updated: "Aug 28",
      body: "Keep the first equalizer app-local. A system-wide audio route needs a separate platform and driver plan.",
    },
  ];

  let notes = $state(starterNotes.map((note) => ({ ...note })));
  let activeNoteId = $state("north-star");
  let noteQuery = $state("");
  let noteTitle = $state(starterNotes[0].title);
  let noteBody = $state(starterNotes[0].body);
  let filteredNotes = $derived(notes.filter((note) => `${note.title} ${note.tag} ${note.body}`.toLowerCase().includes(noteQuery.toLowerCase())));
  let noteWordCount = $derived(noteBody.trim() ? noteBody.trim().split(/\s+/).length : 0);

  function selectNote(note) {
    activeNoteId = note.id;
    noteTitle = note.title;
    noteBody = note.body;
  }

  function updateNote() {
    const note = notes.find((item) => item.id === activeNoteId);
    if (!note) return;
    note.title = noteTitle || "Untitled note";
    note.body = noteBody;
    note.updated = "Just now";
  }

  function createNote() {
    const note = {
      id: `note-${Date.now()}`,
      title: "Untitled note",
      tag: "Draft",
      updated: "Just now",
      body: "Start writing here...",
    };
    notes = [...notes, note];
    selectNote(note);
  }

  function exportNoteAsPdf() {
    const doc = new jsPDF({ unit: "pt", format: "a4" });
    const margin = 52;
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const title = noteTitle || "Untitled note";
    const safeName = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "chain-note";
    let y = 72;

    doc.setTextColor(35, 36, 40);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(25);
    doc.text(title, margin, y);
    y += 24;
    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    doc.setTextColor(110, 112, 120);
    doc.text(`CHAIN NOTES  /  ${new Date().toLocaleDateString()}`, margin, y);
    y += 28;
    doc.setDrawColor(220, 221, 224);
    doc.line(margin, y, pageWidth - margin, y);
    y += 28;
    doc.setTextColor(55, 56, 62);
    doc.setFontSize(11);

    const lines = doc.splitTextToSize(noteBody || "Empty note.", pageWidth - margin * 2);
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
</script>

<section class="tool-page">
  <div class="tool-heading">
    <div>
      <p class="eyebrow">Writing utility / Mock 03</p>
      <h1>Chain Notes</h1>
      <p>Keep ideas connected, shape a clean draft, and export the current note as a portable PDF.</p>
    </div>
    <span class="mock-badge">Local draft</span>
  </div>

  <div class="notes-layout">
    <aside class="tool-panel notes-list-panel">
      <div class="notes-list-heading">
        <div>
          <span class="panel-label">Notebook</span>
          <h2>{notes.length} notes</h2>
        </div>
        <button class="new-note-button" onclick={createNote}>New</button>
      </div>
      <label class="search-field">
        <span class="sr-only">Search notes</span>
        <input type="search" placeholder="Search notes" bind:value={noteQuery} />
      </label>
      <div class="notes-list">
        {#each filteredNotes as note}
          <button class:active={activeNoteId === note.id} class="note-list-item" onclick={() => selectNote(note)}>
            <span class="note-list-meta"><span>{note.tag}</span><span>{note.updated}</span></span>
            <strong>{note.title}</strong>
            <span>{note.body.replace(/\s+/g, " ").slice(0, 72)}</span>
          </button>
        {/each}
        {#if filteredNotes.length === 0}
          <p class="empty-notes">No notes found.</p>
        {/if}
      </div>
    </aside>

    <article class="tool-panel note-editor">
      <div class="note-editor-heading">
        <div>
          <span class="panel-label">Chain / {activeNoteId === "north-star" ? "01" : activeNoteId === "scanner-flow" ? "02" : "03"}</span>
          <span class="note-saved">Saved locally</span>
        </div>
        <button class="export-button" onclick={exportNoteAsPdf}>Export PDF</button>
      </div>
      <input class="note-title-input" aria-label="Note title" bind:value={noteTitle} oninput={updateNote} />
      <div class="note-meta-row">
        <span>{noteWordCount} words</span>
        <span>Markdown-friendly text</span>
      </div>
      <textarea class="note-body-input" aria-label="Note body" bind:value={noteBody} oninput={updateNote}></textarea>
      <div class="note-editor-footer">
        <span>PDF export includes this current note only.</span>
        <button class="text-button" onclick={exportNoteAsPdf}>Download draft -&gt;</button>
      </div>
    </article>
  </div>
</section>
