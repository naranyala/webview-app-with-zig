import { describe, expect, it } from "vitest";
import { activeFrontend, frontends, getFrontend } from "./index.js";

describe("frontend registry", () => {
  it("keeps the current toolkit frontend active", () => {
    expect(frontends).toHaveLength(1);
    expect(activeFrontend).toBe(getFrontend("toolkit"));
    expect(["function", "object"]).toContain(typeof activeFrontend.component);
  });
});
