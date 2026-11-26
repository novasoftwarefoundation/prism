// The compare screen on the web (compare.sh): a component of every kind, as on Android
// (design/test/compose, CompareScreenTest) and iOS (design/test/swiftui, CompareScreenTests),
// rendered by Prism's React package (targets/react, built) against the web package's CSS,
// into <folder>/compare-web.html. compare.sh opens it in Chrome at 100% and at 200% zoom.
//
//   node design/test/compare/web.mjs <folder>
import { mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";

const react = new URL("../../../targets/react/", import.meta.url);
const require = createRequire(new URL("package.json", react));
const { createElement: h } = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const Prism = await import(new URL("dist/index.js", react));

const out = process.argv[2];
if (!out) {
  console.error("usage: node design/test/compare/web.mjs <folder>");
  process.exit(2);
}

const flow = (...children) => h("div", { className: "flow" }, ...children);
const row = (...children) => h("div", { className: "row" }, ...children);
const plus = h(
  "svg",
  { width: 20, height: 20, viewBox: "0 0 20 20", fill: "none", stroke: "currentColor", strokeWidth: 2 },
  h("path", { d: "M10 4v12M4 10h12" }),
);
const chevron = h(
  "svg",
  { width: 16, height: 16, viewBox: "0 0 16 16", fill: "none", stroke: "currentColor", strokeWidth: 2 },
  h("path", { d: "M3 6l5 5 5-5" }),
);

const screen = h(
  "div",
  { className: "screen" },
  flow(
    ...[["primary", "Primary"], ["secondary", "Secondary"], ["soft", "Soft"], ["plain", "Plain"],
      ["link", "Link"], ["text", "Text"]].map(([variant, name]) => h(Prism.Button, { variant }, name)),
    h(Prism.Button, { variant: "icon", "aria-label": "Add" }, plus),
  ),
  flow(
    ...[["success", "Success"], ["warning", "Warning"], ["danger", "Danger"], ["neutral", "Neutral"],
      ["highlight", "Highlight"]].map(([tone, name]) =>
      h(Prism.Button, { variant: "primary", tone }, name)),
    h(Prism.Button, { variant: "primary", disabled: true }, "Disabled"),
    h(Prism.Button, { variant: "primary", loading: true }, "Loading"),
  ),
  h(Prism.Field, { label: "Email" }, h(Prism.TextField, { defaultValue: "someone@example.org" })),
  h(
    Prism.Field,
    { invalid: true, label: "Name", errorMessage: "Enter your name" },
    h(Prism.TextField, { invalid: true, defaultValue: "" }),
  ),
  h(Prism.TextField, { prefix: "€", defaultValue: "100" }),
  h(Prism.TextArea, {
    defaultValue: "Notes about the visit, on more than one line.",
    style: { height: "96px" },
  }),
  h(Prism.Select, { icon: chevron }, "Bosnia and Herzegovina"),
  h("label", { className: "row" }, h(Prism.Checkbox, { defaultChecked: true }), "Remember me"),
  h(
    Prism.RadioGroup,
    {},
    h(Prism.Radio, { name: "answer", defaultChecked: true }, "Yes"),
    h(Prism.Radio, { name: "answer" }, "No"),
  ),
  h(
    "div",
    { className: "row spinners" },
    h(Prism.Spinner, { variant: "accent" }),
    h(Prism.Spinner, { variant: "accent", size: 32, progress: 40 }),
  ),
  flow(
    ...[["accent", "Accent"], ["success", "Success"], ["warning", "Warning"], ["danger", "Danger"],
      ["neutral", "Neutral"]].map(([tone, name]) => h(Prism.Tag, { tone }, name)),
  ),
  h(Prism.MessageBar, {}, "Saved"),
  h(Prism.MessageBar, { tone: "warning" }, "Your session ends in 5 minutes. Save your work to keep it."),
  row(
    h(Prism.StepIndicator, { status: "complete" }, "1"),
    h(Prism.StepIndicator, { status: "current" }, "2"),
    h(Prism.StepIndicator, {}, "3"),
  ),
  h(Prism.ImagePicker, {
    preview: h("div", { className: "preview" }),
    button: h(Prism.Button, { variant: "primary" }, "Choose a photo"),
  }),
);

const css = (file) => new URL(`../../../targets/web/css/${file}`, import.meta.url).href;
const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Prism compare screen</title>
<link rel="stylesheet" href="${css("base.css")}">
<link rel="stylesheet" href="${css("components.css")}">
<style>
  /* Tailwind's preflight, the part an app with Prism's preset has. */
  *, ::before, ::after { box-sizing: border-box; border: 0 solid; margin: 0; padding: 0; }
  button, input, textarea { background: transparent; font: inherit; color: inherit; }
  body { background: #fff; font-family: "Nunito Sans", sans-serif; }
  /* A 393 px wide phone; the dashed line is its edge, and what runs past it runs off the
     screen. At 200% zoom, Chrome's device scale factor is twice as large and the screen half
     as wide in CSS pixels, as with the browser's own zoom. */
  html { width: 393px; outline: 1px dashed #f0f; }
  html.zoom { width: 196.5px; }
  /* The spinner without progress stands still, so each run draws it the same. */
  *, ::before, ::after { animation-play-state: paused !important; animation-delay: 0s !important; }
  .screen { display: flex; flex-direction: column; gap: 16px; padding: 16px; }
  .flow { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 8px; }
  .row { display: flex; align-items: center; gap: 8px; }
  .spinners { gap: 16px; }
  .preview { width: 100%; height: 100%; background: #bbb; }
</style>
<script>if (location.hash === "#200") document.documentElement.className = "zoom";</script>
</head>
<body>
${renderToStaticMarkup(screen)}
<script>
  // The page's height, for compare.sh's window, once its fonts are in.
  document.fonts.ready.then(() => {
    document.body.dataset.height = Math.ceil(document.documentElement.getBoundingClientRect().height);
  });
</script>
</body>
</html>
`;

mkdirSync(out, { recursive: true });
writeFileSync(join(out, "compare-web.html"), page);
