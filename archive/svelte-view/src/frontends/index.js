import { defaultFrontend } from "./default.js";

const registeredFrontends = [defaultFrontend];
const frontendIds = new Set();

for (const frontend of registeredFrontends) {
  if (frontendIds.has(frontend.id)) throw new Error(`Duplicate frontend id: ${frontend.id}`);
  frontendIds.add(frontend.id);
}

export const frontends = Object.freeze(registeredFrontends);

export function getFrontend(id) {
  return frontends.find((frontend) => frontend.id === id);
}

// Keep the current frontend active until a product decision selects another.
export const activeFrontend = getFrontend("toolkit");
