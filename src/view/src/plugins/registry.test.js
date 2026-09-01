import { describe, expect, it } from "vitest";
import { frontendPlugins, getFrontendPlugin } from "./index.js";

describe("frontend plugin registry", () => {
  it("registers the active toolkit plugins with unique ids", () => {
    const ids = frontendPlugins.map((plugin) => plugin.id);

    expect(new Set(ids).size).toBe(ids.length);
    expect(ids).toEqual(["disk", "equalizer", "notes"]);
    expect(frontendPlugins.every((plugin) => ["function", "object"].includes(typeof plugin.component))).toBe(true);
  });

  it("resolves a plugin by id", () => {
    expect(getFrontendPlugin("notes").title).toBe("Chain Notes");
    expect(getFrontendPlugin("unknown")).toBeUndefined();
  });
});
