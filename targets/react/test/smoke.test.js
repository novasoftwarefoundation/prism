// Prism's React components, built: every axis value and state of every component
// renders classes of the components.css that @novasoftwarefoundation/prism ships.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { createElement as h } from "react";
import { renderToStaticMarkup } from "react-dom/server";

import * as Prism from "../dist/index.js";

const css = readFileSync(
  new URL(import.meta.resolve("@novasoftwarefoundation/prism/css/components.css")),
  "utf8",
);

const classes = (markup) => [
  ...new Set([...markup.matchAll(/class="([^"]*)"/g)].flatMap(([, list]) => list.split(" "))),
];

const inCss = (name) => new RegExp(`\\.${name.replace(/[^\w-]/g, "\\$&")}(?![\\w-])`).test(css);

const onChange = () => {};

test("a button's classes are classes of the generated components.css", () => {
  const markup = renderToStaticMarkup(
    h(Prism.Button, { variant: "secondary", tone: "danger", loading: true, icon: "+" }, "Save"),
  );

  assert.deepEqual(classes(markup), [
    "prism-button",
    "prism-button--secondary",
    "prism-button--danger",
    "prism-button--loading",
    "prism-button--with-icon",
    "prism-button__label",
    "prism-button__icon",
    "prism-spinner",
  ]);

  // The icon part has no look of its own, so no rule: its class is a hook for the app.
  assert.deepEqual(
    classes(markup).filter((name) => !inCss(name)),
    ["prism-button__icon"],
  );
});

test("every axis value and state of every component renders a class of the CSS", () => {
  const elements = [
    ...["primary", "secondary", "plain", "link", "text"].flatMap((variant) =>
      ["accent", "success", "warning", "danger"].map((tone) =>
        h(Prism.Button, { variant, tone, loading: true, disabled: true, icon: "+" }, "x"),
      ),
    ),
    h(Prism.TextField, { variant: "inverse", invalid: true, disabled: true }),
    h(Prism.TextArea, { defaultValue: "x" }),
    h(Prism.Field, { label: "x", errorMessage: "x" }, "x"),
    h(Prism.RadioGroup, null, h(Prism.Radio, { checked: true, disabled: true, onChange }, "x")),
    h(Prism.Select, { icon: "v", options: [{ selected: true, children: "x" }] }, "x"),
    h(Prism.Checkbox, { checked: true, disabled: true, onChange }),
    ...["medium", "small", "large"].flatMap((size) =>
      ["accent", "inverse"].map((variant) => h(Prism.Spinner, { size, variant })),
    ),
    ...["accent", "success", "warning", "danger", "neutral"].map((tone) =>
      h(Prism.Tag, { tone }, "x"),
    ),
    ...["info", "success", "warning", "danger"].map((tone) => h(Prism.MessageBar, { tone }, "x")),
    ...["incomplete", "current", "complete"].map((status) =>
      h(Prism.StepIndicator, { status }, "1"),
    ),
  ];

  const rendered = classes(elements.map((element) => renderToStaticMarkup(element)).join(""));
  assert.ok(rendered.length > 50);

  // Without a look of their own, the button's icon and the field have no rule.
  assert.deepEqual(
    rendered.filter((name) => !inCss(name)),
    ["prism-button__icon", "prism-field"],
  );
});
