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
    "prism-button__icon",
    "prism-button__label",
    "prism-spinner",
    "prism-spinner--20",
  ]);

  // The icon part has no look of its own, so no rule: its class is a hook for the app.
  assert.deepEqual(
    classes(markup).filter((name) => !inCss(name)),
    ["prism-button__icon"],
  );
});

// A tone colors the background of a primary button, and the text of the others.
test("a tone has a look with each variant it colors", () => {
  for (const tone of ["success", "warning", "danger", "neutral", "highlight"]) {
    for (const variant of ["primary", "secondary", "plain", "link", "text"]) {
      assert.ok(
        css.includes(`.prism-button--${variant}.prism-button--${tone} {`),
        `${variant} ${tone}`,
      );
    }
  }
  for (const tone of ["success", "warning", "danger"]) {
    assert.ok(css.includes(`.prism-button--soft.prism-button--${tone} {`), `soft ${tone}`);
  }
});

test("the icon goes at the start of the label, or at its end", () => {
  const start = renderToStaticMarkup(h(Prism.Button, { variant: "plain", icon: "<" }, "Back"));
  const end = renderToStaticMarkup(
    h(Prism.Button, { variant: "plain", icon: ">", iconPosition: "end" }, "Next"),
  );
  assert.match(start, /prism-button__icon">&lt;<\/span><span class="prism-button__label">Back/);
  assert.match(end, /prism-button__label">Next<\/span><span class="prism-button__icon">&gt;/);
  assert.throws(
    () => renderToStaticMarkup(h(Prism.Button, { icon: ">", iconPosition: "right" }, "Next")),
    /iconPosition: "right" is not one of "start", "end"/,
  );
});

test("plain and text buttons are padded unless padded is false", () => {
  const markup = (props) => renderToStaticMarkup(h(Prism.Button, props, "x"));
  assert.match(markup({ variant: "text" }), /class="prism-button prism-button--text prism-button--padded"/);
  assert.match(markup({ variant: "plain", padded: false }), /class="prism-button prism-button--plain"/);
  assert.match(markup({ variant: "primary" }), /class="prism-button prism-button--primary"/);
});

test("a spinner's progress: the class, the progressbar's attributes and the ring", () => {
  const markup = renderToStaticMarkup(h(Prism.Spinner, { size: 32, progress: 40 }));
  assert.match(
    markup,
    /^<span role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="40" class="prism-spinner prism-spinner--32 prism-spinner--progress"><svg/,
  );
  assert.match(
    markup,
    /class="prism-spinner__indicator"[^>]* r="42" pathLength="100" stroke-dasharray="40 100"/,
  );
  assert.match(renderToStaticMarkup(h(Prism.Spinner, { progress: 140 })), /aria-valuenow="100"/);
  // At 0, the track without the arc, whose round ends would draw a dot.
  assert.doesNotMatch(renderToStaticMarkup(h(Prism.Spinner, { progress: 0 })), /__indicator/);

  // Without one, the spinner as it was.
  assert.equal(
    renderToStaticMarkup(h(Prism.Spinner, { size: 16 })),
    '<span class="prism-spinner prism-spinner--16"></span>',
  );
});

test("every axis value and state of every component renders a class of the CSS", () => {
  const elements = [
    ...["primary", "secondary", "plain", "link", "text", "soft", "icon"].flatMap((variant) =>
      ["accent", "success", "warning", "danger", "neutral", "highlight"].flatMap((tone) =>
        [true, false].map((padded) =>
          h(Prism.Button, { variant, tone, padded, loading: true, disabled: true, icon: "+" }, "x"),
        ),
      ),
    ),
    h(Prism.TextField, { variant: "inverse", invalid: true, disabled: true }),
    h(Prism.TextArea, { defaultValue: "x" }),
    h(Prism.Field, { label: "x", errorMessage: "x" }, "x"),
    h(Prism.RadioGroup, null, h(Prism.Radio, { checked: true, disabled: true, onChange }, "x")),
    h(Prism.Select, { icon: "v", options: [{ selected: true, children: "x" }] }, "x"),
    h(Prism.Checkbox, { checked: true, disabled: true, onChange }),
    ...[16, 20, 24, 32].flatMap((size) =>
      ["accent", "inverse"].flatMap((variant) =>
        [undefined, 40].map((progress) => h(Prism.Spinner, { size, variant, progress })),
      ),
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
