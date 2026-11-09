// Prism's tokens as Webflow variables: which tokens of tokens.json (DTCG 2025.10) a
// Webflow variable can hold, under which name, with which value (ADR 0014).

// A DTCG type and the type of Webflow variable that holds it.
const variableTypes = {
  color: "Color",
  dimension: "Size",
  fontFamily: "FontFamily",
  fontWeight: "Number",
};

// The units of a Webflow size variable.
const sizeUnits = new Set("px em rem vh vw dvh dvw lvh lvw svh svw vmax vmin ch".split(" "));

// A color is named by its name, as the site's collection names Prism's colors
// (`primary`, `grey1`); a token of any other group is in a folder of its group
// (`font-size/title0`), which Webflow's Variables panel shows as a group.
export function variableName([group, ...name]) {
  return group === "color" ? name.join("-") : [group, ...name].join("/");
}

// Names that are one variable to Webflow's designers: the same letters and digits per
// folder, whatever the case, spaces or dashes (`Grey 1`, `grey-1` and `grey1`).
export function nameKey(name) {
  return name
    .split("/")
    .map((part) => part.toLowerCase().replace(/[^a-z0-9]/g, ""))
    .join("/");
}

// Every token in a DTCG tree, in the file's order: `[path, token]`.
function tokensOf(tree, path = []) {
  return Object.entries(tree).flatMap(([key, value]) => {
    if (key.startsWith("$") || typeof value !== "object" || value === null) return [];
    return "$value" in value ? [[[...path, key], value]] : tokensOf(value, [...path, key]);
  });
}

// A color in the form Webflow stores: `#RRGGBB`, or `#RRGGBBAA` when it isn't opaque.
function colorValue({ hex, alpha = 1 }) {
  const opacity = alpha === 1 ? "" : Math.round(alpha * 255).toString(16).padStart(2, "0");
  return (hex + opacity).toUpperCase();
}

function valueOf(type, value) {
  switch (type) {
    case "Color":
      return { value: colorValue(value) };
    case "Size":
      return sizeUnits.has(value.unit)
        ? { value: { value: value.value, unit: value.unit } }
        : { reason: `Webflow has no size in ${value.unit}` };
    case "FontFamily":
      return { value: [value].flat().join(", ") };
    case "Number":
      return typeof value === "number" ? { value } : { reason: `the weight ${value} is no number` };
  }
}

// The variables Prism's tokens give, `{token, name, type, value}` or, for a token
// that refers to another one, `{token, name, type, alias}` with the other token's
// path; and the tokens no Webflow variable can hold, `{token, reason}`.
export function prismVariables(tokens) {
  const variables = [];
  const skipped = [];
  for (const [path, { $type, $value }] of tokensOf(tokens)) {
    const token = path.join(".");
    const type = variableTypes[$type];
    if (!type) {
      skipped.push({ token, reason: `Webflow has no ${$type} variable` });
    } else if (typeof $value === "string" && /^\{.+\}$/.test($value)) {
      variables.push({ token, name: variableName(path), type, alias: $value.slice(1, -1) });
    } else {
      const { value, reason } = valueOf(type, $value);
      if (reason) skipped.push({ token, reason });
      else variables.push({ token, name: variableName(path), type, value });
    }
  }
  return { variables, skipped };
}
