import "./main.css";
import { activeFrontend } from "./frontends/index.js";
import { mount } from "svelte";

const app = mount(activeFrontend.component, {
  target: document.getElementById("app"),
});

export default app;
