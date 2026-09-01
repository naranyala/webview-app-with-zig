import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const pdfSave = vi.hoisted(() => vi.fn());

vi.mock("jspdf", () => ({
  jsPDF: vi.fn(() => ({
    internal: { pageSize: { getWidth: () => 595, getHeight: () => 842 } },
    setTextColor: vi.fn(),
    setFont: vi.fn(),
    setFontSize: vi.fn(),
    setDrawColor: vi.fn(),
    line: vi.fn(),
    splitTextToSize: vi.fn((text) => text.split("\n")),
    text: vi.fn(),
    addPage: vi.fn(),
    save: pdfSave,
  })),
}));

import App from "./App.svelte";

const nativeBindings = [
  "enterFullscreen",
  "exitFullscreen",
  "minimizeWindow",
  "maximizeWindow",
  "restoreWindow",
  "closeWindow",
];

beforeEach(() => {
  for (const binding of nativeBindings) {
    window[binding] = vi.fn().mockResolvedValue(undefined);
  }
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

async function openNotes() {
  render(App);
  await fireEvent.click(screen.getByRole("button", { name: /Chain Notes.*Capture connected thoughts/ }));
  await waitFor(() => expect(screen.getByText("Notebook")).not.toBeNull());
}

describe("tool launcher", () => {
  it("lists the toolkit and opens Chain Notes fullscreen", async () => {
    render(App);

    expect(screen.getAllByRole("button", { name: /Disk Scanner/ })).toHaveLength(2);
    expect(screen.getAllByRole("button", { name: /Audio Equalizer/ })).toHaveLength(2);
    expect(screen.getAllByRole("button", { name: /Chain Notes/ })).toHaveLength(2);

    await fireEvent.click(screen.getByRole("button", { name: /Chain Notes.*Capture connected thoughts/ }));

    await waitFor(() => expect(screen.getByText("Notebook")).not.toBeNull());
    expect(window.enterFullscreen).toHaveBeenCalledOnce();
    expect(screen.getByText("Local draft")).not.toBeNull();
  });

  it("switches opened workspaces and returns home from the fixed rail button", async () => {
    await openNotes();

    await fireEvent.click(screen.getByRole("button", { name: "Open home launcher" }));
    await waitFor(() => expect(screen.getByText("Pick a tool.")).not.toBeNull());
    await fireEvent.click(screen.getByRole("button", { name: /Disk Scanner.*Map storage usage/ }));
    await waitFor(() => expect(screen.getByText("Scan target")).not.toBeNull());
    await fireEvent.click(screen.getByRole("button", { name: "Open home launcher" }));
    await waitFor(() => expect(screen.getByText("Pick a tool.")).not.toBeNull());
    await fireEvent.click(screen.getByRole("button", { name: /Chain Notes.*Capture connected thoughts/ }));
    await waitFor(() => expect(screen.getByText("Notebook")).not.toBeNull());
    await fireEvent.click(screen.getByRole("button", { name: /01 Disk Scanner/ }));
    expect(screen.getByText("Scan target")).not.toBeNull();
    expect(window.enterFullscreen).toHaveBeenCalledTimes(3);

    await fireEvent.click(screen.getByRole("button", { name: "Open home launcher" }));
    await waitFor(() => expect(screen.getByText("Pick a tool.")).not.toBeNull());
    expect(window.exitFullscreen).toHaveBeenCalledTimes(3);
  });
});

describe("Chain Notes", () => {
  it("filters notes and creates an editable local draft", async () => {
    await openNotes();

    const search = screen.getByPlaceholderText("Search notes");
    await fireEvent.input(search, { target: { value: "scanner" } });
    expect(screen.getByRole("button", { name: /Scanner flow/ })).not.toBeNull();
    expect(screen.queryByRole("button", { name: /Toolkit north star/ })).toBeNull();

    await fireEvent.click(screen.getByRole("button", { name: "New" }));
    const title = screen.getByRole("textbox", { name: "Note title" });
    const body = screen.getByRole("textbox", { name: "Note body" });
    await fireEvent.input(title, { target: { value: "Release notes" } });
    await fireEvent.input(body, { target: { value: "Ship the first toolkit draft." } });

    expect(title).toHaveProperty("value", "Release notes");
    expect(screen.getByText("5 words")).not.toBeNull();
  });

  it("exports the current note as a PDF", async () => {
    await openNotes();

    await fireEvent.click(screen.getByRole("button", { name: "Export PDF" }));

    expect(pdfSave).toHaveBeenCalledOnce();
    expect(pdfSave).toHaveBeenCalledWith("toolkit-north-star.pdf");
  });
});
