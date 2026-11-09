// Builds the panel into public/panel.js: one classic script with Prism's tokens.json
// in it, so the extension loads no module and fetches no file. The version shown is
// the design's, from design/mix.exs, which the release checks against its tag.
import { readFileSync } from "node:fs";
import { build } from "esbuild";

const version = readFileSync(new URL("../../design/mix.exs", import.meta.url), "utf8").match(/version: "([^"]+)"/)[1];

await build({
  entryPoints: ["src/panel.js"],
  outfile: "public/panel.js",
  bundle: true,
  format: "iife",
  target: "es2023",
  define: { PRISM_VERSION: JSON.stringify(version) },
  logLevel: "warning",
});
