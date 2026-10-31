// The example design's React components, rendered to markup: the same markup as the
// Phoenix components render, with classes of the CSS the web target generates.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";
import { createElement as h } from "react";
import { renderToStaticMarkup } from "react-dom/server";

import * as Kit from "../dist/index.js";

const css = readFileSync(
  new URL("../../example_components/css/components.css", import.meta.url),
  "utf8",
);

// Markup with each tag's attributes sorted: their order isn't part of what a component
// renders (React writes an input's `checked` and `name` last).
const norm = (markup) =>
  markup.replace(/<([a-z]+)((?:\s+[^\s=>/]+(?:="[^"]*")?)*)\s*(\/?)>/g, (_, tag, attrs, close) => {
    const sorted = (attrs.match(/[^\s=]+(?:="[^"]*")?/g) ?? []).sort();
    return `<${[tag, ...sorted].join(" ")}${close}>`;
  });

const onChange = () => {};

const html = (element) => norm(renderToStaticMarkup(element));

const classes = (markup) => [
  ...new Set([...markup.matchAll(/class="([^"]*)"/g)].flatMap(([, list]) => list.split(" "))),
];

const inCss = (name) => new RegExp(`\\.${name.replace(/[^\w-]/g, "\\$&")}(?![\\w-])`).test(css);

describe("every component", () => {
  test("renders the element the web's CSS expects, with its defaults", () => {
    assert.equal(
      html(h(Kit.Button, null, "Save")),
      norm(
        '<button class="kit-button kit-button--primary"><span class="kit-button__label">Save</span></button>',
      ),
    );
    assert.equal(html(h(Kit.TextField)), norm('<input class="kit-text-field"/>'));
    assert.equal(
      html(h(Kit.TextArea, { defaultValue: "Hi" })),
      norm('<textarea class="kit-text-area">Hi</textarea>'),
    );
    assert.equal(
      html(h(Kit.Field, { label: "Name" }, "CONTROL")),
      norm('<div class="kit-field"><label class="kit-field__label">Name</label>CONTROL</div>'),
    );
    assert.equal(
      html(h(Kit.RadioGroup, null, "RADIOS")),
      norm('<div role="radiogroup" class="kit-radio-group">RADIOS</div>'),
    );
    assert.equal(
      html(h(Kit.Radio, null, "One")),
      norm(
        '<label class="kit-radio"><input type="radio" class="kit-radio__control"/><span class="kit-radio__label">One</span></label>',
      ),
    );
    assert.equal(
      html(h(Kit.Select, null, "Pick")),
      norm(
        '<div class="kit-select"><button type="button" class="kit-select__field">Pick</button></div>',
      ),
    );
    assert.equal(html(h(Kit.Spinner)), norm('<span class="kit-spinner"></span>'));
    assert.equal(html(h(Kit.Checkbox)), norm('<input type="checkbox" class="kit-checkbox"/>'));
    assert.equal(
      html(h(Kit.Tag, null, "New")),
      norm('<span class="kit-tag kit-tag--neutral"><span class="kit-tag__label">New</span></span>'),
    );
    assert.equal(
      html(h(Kit.MessageBar, null, "Saved")),
      norm('<div class="kit-message-bar kit-message-bar--info">Saved</div>'),
    );
    assert.equal(
      html(h(Kit.StepIndicator, null, "1")),
      norm('<span class="kit-step-indicator">1</span>'),
    );
  });

  test("is an export of the package, one per design component", () => {
    const components = Object.keys(Kit).filter((name) => /^[A-Z]/.test(name));
    assert.deepEqual(components.sort(), [
      "Button",
      "Checkbox",
      "Field",
      "MessageBar",
      "Radio",
      "RadioGroup",
      "Select",
      "Spinner",
      "StepIndicator",
      "Tag",
      "TextArea",
      "TextField",
    ]);
  });
});

describe("axes", () => {
  test("every value adds its variant's class; a default without a look adds none", () => {
    for (const [element, expected] of [
      [h(Kit.Button, { variant: "quiet", roomy: false }, "x"), "kit-button kit-button--quiet"],
      [h(Kit.Button, { variant: "subtle", roomy: false }, "x"), "kit-button kit-button--subtle"],
      [h(Kit.Button, { variant: "icon" }, "x"), "kit-button kit-button--icon"],
      [h(Kit.Button, { tone: "accent" }, "x"), "kit-button kit-button--primary"],
      [h(Kit.Button, { tone: "danger" }, "x"), "kit-button kit-button--primary kit-button--danger"],
      [h(Kit.TextField, { variant: "inverse" }), "kit-text-field kit-text-field--inverse"],
      [h(Kit.Spinner, { size: 24 }), "kit-spinner"],
      [
        h(Kit.Spinner, { size: 16, variant: "accent" }),
        "kit-spinner kit-spinner--accent kit-spinner--16",
      ],
      [h(Kit.Tag, { tone: "accent" }, "x"), "kit-tag kit-tag--accent"],
      [h(Kit.MessageBar, { tone: "danger" }, "x"), "kit-message-bar kit-message-bar--danger"],
      [
        h(Kit.StepIndicator, { status: "current" }, "1"),
        "kit-step-indicator kit-step-indicator--current",
      ],
    ]) {
      assert.match(html(element), new RegExp(`^<[a-z]+ class="${expected}"`), expected);
    }
  });
});

describe("states", () => {
  test("a state the CSS writes as a class adds it, on the component or its part", () => {
    assert.equal(
      html(h(Kit.TextField, { invalid: true })),
      norm('<input class="kit-text-field kit-text-field--invalid"/>'),
    );
    assert.equal(
      html(h(Kit.Button, { loading: true }, "Save")),
      norm(
        '<button class="kit-button kit-button--primary kit-button--loading">' +
          '<span class="kit-button__label">Save</span><span class="kit-spinner kit-spinner--16"></span></button>',
      ),
    );
    // The radio's row is no form control, so its disabled state is a class; it
    // disables the radio's control too.
    assert.equal(
      html(h(Kit.Radio, { disabled: true }, "One")),
      norm(
        '<label class="kit-radio kit-radio--disabled"><input type="radio" disabled="" class="kit-radio__control"/>' +
          '<span class="kit-radio__label">One</span></label>',
      ),
    );
  });

  test("disabled and checked on a form control set the element's own attribute", () => {
    assert.ok(
      html(h(Kit.Button, { disabled: true }, "x")).startsWith(
        norm('<button disabled="" class="kit-button kit-button--primary">'),
      ),
    );
    assert.equal(
      html(h(Kit.TextField, { disabled: true })),
      norm('<input disabled="" class="kit-text-field"/>'),
    );
    assert.equal(
      html(h(Kit.Checkbox, { checked: true, disabled: true, onChange })),
      norm('<input type="checkbox" disabled="" checked="" class="kit-checkbox"/>'),
    );
    assert.ok(
      html(h(Kit.Radio, { checked: true, onChange }, "One")).includes(
        norm('<input type="radio" checked="" class="kit-radio__control"/>'),
      ),
    );
  });

  test("a state the app doesn't set adds nothing, and leaves a control uncontrolled", () => {
    assert.equal(
      html(h(Kit.Checkbox, { defaultChecked: true })),
      norm('<input type="checkbox" checked="" class="kit-checkbox"/>'),
    );
  });

  test("a select's option takes selected, which adds its class", () => {
    const options = [
      { selected: true, id: "a", children: "A" },
      { className: "extra", children: "B" },
    ];

    assert.equal(
      html(h(Kit.Select, { options }, "Pick")),
      norm(
        '<div class="kit-select"><button type="button" class="kit-select__field">Pick</button>' +
          '<ul role="listbox" class="kit-select__listbox">' +
          '<li role="option" aria-selected="true" id="a" class="kit-select__option kit-select__option--selected">A</li>' +
          '<li role="option" class="kit-select__option extra">B</li></ul></div>',
      ),
    );
  });
});

describe("flags", () => {
  test("a flag is a boolean prop with the design's default, adding its class while true", () => {
    assert.match(
      html(h(Kit.Button, { strong: true }, "x")),
      /class="kit-button kit-button--primary kit-button--strong"/,
    );
    assert.doesNotMatch(html(h(Kit.Button, null, "x")), /kit-button--strong/);
  });

  test("a flag with looks only with some variants adds its class only with those", () => {
    assert.match(
      html(h(Kit.Button, { variant: "quiet" }, "x")),
      /class="kit-button kit-button--quiet kit-button--roomy"/,
    );
    assert.match(
      html(h(Kit.Button, { variant: "subtle" }, "x")),
      /class="kit-button kit-button--subtle kit-button--roomy"/,
    );
    assert.doesNotMatch(html(h(Kit.Button, null, "x")), /roomy/);
    assert.doesNotMatch(html(h(Kit.Button, { variant: "quiet", roomy: false }, "x")), /roomy/);
  });
});

describe("parts", () => {
  test("an icon is a prop whose presence adds the look with it", () => {
    assert.equal(
      html(h(Kit.Button, { icon: "*", iconProps: { className: "i" } }, "Save")),
      norm(
        '<button class="kit-button kit-button--primary kit-button--with-icon">' +
          '<span class="kit-button__icon i">*</span><span class="kit-button__label">Save</span></button>',
      ),
    );
  });

  test("a part with position: goes at the side of the content iconPosition picks", () => {
    assert.equal(
      html(h(Kit.Button, { icon: "*", iconPosition: "end" }, "Save")),
      norm(
        '<button class="kit-button kit-button--primary kit-button--with-icon">' +
          '<span class="kit-button__label">Save</span><span class="kit-button__icon">*</span></button>',
      ),
    );
    assert.equal(
      html(h(Kit.Button, { variant: "icon", icon: "*", "aria-label": "Add" })),
      norm(
        '<button aria-label="Add" class="kit-button kit-button--icon kit-button--with-icon">' +
          '<span class="kit-button__icon">*</span></button>',
      ),
    );
  });

  test("the spinner, a part that is another component, is there only while loading", () => {
    assert.doesNotMatch(html(h(Kit.Button, null, "Save")), /kit-spinner/);
    assert.match(
      html(h(Kit.Button, { loading: true }, "Save")),
      // With the variant the part picks.
      /<span class="kit-spinner kit-spinner--16"><\/span><\/button>$/,
    );
  });

  test("parts come in the design's order, the icon at the start: icon, label, spinner", () => {
    assert.match(
      html(h(Kit.Button, { icon: "*", loading: true }, "Save")),
      /kit-button__icon.*kit-button__label.*kit-spinner/,
    );
  });

  test("a field puts its control between its label and its error message", () => {
    assert.equal(
      html(
        h(
          Kit.Field,
          { label: "Name", labelProps: { htmlFor: "name" }, errorMessage: "Required" },
          "CONTROL",
        ),
      ),
      norm(
        '<div class="kit-field"><label for="name" class="kit-field__label">Name</label>CONTROL' +
          '<p class="kit-field__error-message">Required</p></div>',
      ),
    );
  });

  test("a part without content isn't there", () => {
    assert.equal(
      html(h(Kit.Button, { icon: null })),
      norm('<button class="kit-button kit-button--primary"></button>'),
    );
    assert.equal(
      html(h(Kit.Field, { label: false }, "CONTROL")),
      norm('<div class="kit-field">CONTROL</div>'),
    );
  });
});

describe("values", () => {
  const ring = (value) =>
    '<svg viewBox="0 0 100 100" aria-hidden="true">' +
    '<circle class="kit-spinner__track" cx="50" cy="50" r="44"></circle>' +
    '<circle class="kit-spinner__indicator" cx="50" cy="50" r="44" pathLength="100" ' +
    `stroke-dasharray="${value} 100" transform="rotate(-90 50 50)"></circle></svg>`;

  test("with a value, the class, the progressbar's attributes and the ring", () => {
    assert.equal(
      html(h(Kit.Spinner, { progress: 40 })),
      norm(
        '<span role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="40" ' +
          `class="kit-spinner kit-spinner--progress">${ring(40)}</span>`,
      ),
    );
  });

  test("a value out of range clamps to 0 and 100", () => {
    assert.match(
      html(h(Kit.Spinner, { progress: 140 })),
      /aria-valuenow="100".*stroke-dasharray="100 100"/,
    );
  });

  // At 0 the arc's round ends would still draw a dot.
  test("at 0, and below, the track without the arc", () => {
    for (const progress of [0, -5]) {
      const markup = html(h(Kit.Spinner, { progress }));
      assert.match(markup, /aria-valuenow="0"/);
      assert.match(markup, /kit-spinner__track/);
      assert.doesNotMatch(markup, /kit-spinner__indicator/);
    }
  });

  test("without a value, the spinner as it is, with no role", () => {
    assert.equal(
      html(h(Kit.Spinner, { size: 16 })),
      norm('<span class="kit-spinner kit-spinner--16"></span>'),
    );
  });
});

describe("the app's adjustments", () => {
  test("className appends the app's classes, the other props go on the element", () => {
    assert.equal(
      html(h(Kit.Button, { className: "mt-4", id: "save", type: "submit", "data-x": "1" }, "Save")),
      norm(
        '<button id="save" type="submit" data-x="1" class="kit-button kit-button--primary mt-4">' +
          '<span class="kit-button__label">Save</span></button>',
      ),
    );
    assert.equal(
      html(h(Kit.TextField, { name: "email", placeholder: "Email", className: "w-1/2" })),
      norm('<input name="email" placeholder="Email" class="kit-text-field w-1/2"/>'),
    );
    // A radio's other props go on its control, its className on the row.
    assert.equal(
      html(h(Kit.Radio, { name: "pick", value: "1", className: "row" }, "One")),
      norm(
        '<label class="kit-radio row"><input type="radio" name="pick" value="1" class="kit-radio__control"/>' +
          '<span class="kit-radio__label">One</span></label>',
      ),
    );
  });

  test("a button's element is the app's choice, one of a few", () => {
    assert.equal(
      html(h(Kit.Button, { as: "a", href: "/next" }, "Next")),
      norm(
        '<a href="/next" class="kit-button kit-button--primary"><span class="kit-button__label">Next</span></a>',
      ),
    );
    assert.match(html(h(Kit.Button, { as: "div" }, "Face")), /^<div class="kit-button/);
    assert.deepEqual(Kit.buttonElements, ["button", "a", "span", "div"]);
    assert.throws(
      () => html(h(Kit.Button, { as: "script" }, "x")),
      /as: "script" is not one of "button", "a", "span", "div"/,
    );
  });
});

test("every class a component renders is a class of the web target's CSS", () => {
  const markup = [
    h(Kit.Button, { variant: "quiet", tone: "danger", loading: true, icon: "i" }, "x"),
    h(Kit.Button, { variant: "subtle" }, "x"),
    h(Kit.TextField, { variant: "inverse", invalid: true, disabled: true }),
    h(Kit.TextArea, { defaultValue: "x" }),
    h(Kit.Field, { label: "x", errorMessage: "x" }, "x"),
    h(Kit.RadioGroup, null, h(Kit.Radio, { checked: true, disabled: true, onChange }, "x")),
    h(Kit.Select, { icon: "v", options: [{ selected: true, children: "x" }] }, "x"),
    h(Kit.Spinner, { size: 16, variant: "accent" }),
    h(Kit.Spinner, { size: 32, progress: 40 }),
    h(Kit.Checkbox, { checked: true, disabled: true, onChange }),
    h(Kit.Tag, { tone: "accent" }, "x"),
    h(Kit.MessageBar, { tone: "danger" }, "x"),
    h(Kit.StepIndicator, { status: "current" }, "1"),
  ]
    .map(html)
    .join("");

  const rendered = classes(markup);
  assert.ok(rendered.length > 30);

  // Without a look of their own, the button's icon and the field have a class but no
  // rule: a hook for the app.
  assert.deepEqual(
    rendered.filter((name) => !inCss(name)),
    ["kit-button__icon", "kit-field"],
  );
});
