// The extension's panel in the Designer: what applying Prism's tokens will do, the
// button that applies them, and what it did. `PRISM_VERSION` is set by build.mjs.
import tokens from "../../design-tools/tokens.json";
import { apply, preview } from "./collection.js";

const headings = {
  before: { update: "To update", add: "To add", unchanged: "Unchanged", skip: "Skipped" },
  after: { update: "Updated", add: "Added", unchanged: "Unchanged", skip: "Skipped" },
};

const element = (tag, text, attributes = {}) =>
  Object.assign(document.createElement(tag), { textContent: text ?? "" }, attributes);

// A value as the Variables panel shows it; an alias by the other variable's name.
function shown({ alias, type, value }, names) {
  if (alias) return `= ${names.get(alias)}`;
  if (type === "Size") return `${value.value}${value.unit}`;
  return String(value);
}

function render({ collection, changes }, phase) {
  const groups = Map.groupBy(changes, ({ action }) => action);
  const names = new Map(changes.map(({ token, name }) => [token, name]));
  const counts = Object.entries(headings[phase])
    .map(([action, heading]) => `${heading.toLowerCase()} ${groups.get(action)?.length ?? 0}`)
    .join(", ");
  document.getElementById("summary").textContent = `Prism ${PRISM_VERSION}, collection “${collection}”: ${counts}.`;

  const list = document.getElementById("changes");
  list.replaceChildren();
  for (const [action, heading] of Object.entries(headings[phase])) {
    const items = groups.get(action) ?? [];
    if (items.length === 0) continue;
    const section = element("details", "", { open: action !== "unchanged" });
    section.append(element("summary", `${heading} (${items.length})`));
    const rows = element("ul");
    for (const change of items) {
      const row = element("li");
      row.append(element("span", change.name ?? change.token, { className: "name" }));
      row.append(
        element("span", change.reason ?? shown(change, names), { className: change.reason ? "reason" : "value" }),
      );
      row.title = change.token;
      rows.append(row);
    }
    section.append(rows);
    list.append(section);
  }
  return groups;
}

function fail(error) {
  document.getElementById("summary").textContent = error.message;
}

const button = document.getElementById("apply");

async function show() {
  try {
    const groups = render(await preview(webflow, tokens), "before");
    button.disabled = !groups.has("update") && !groups.has("add");
  } catch (error) {
    fail(error);
  }
}

button.addEventListener("click", async () => {
  button.disabled = true;
  try {
    const groups = render(await apply(webflow, tokens), "after");
    const count = (action) => groups.get(action)?.length ?? 0;
    await webflow.notify({
      type: "Success",
      message: `Prism ${PRISM_VERSION}: ${count("update")} updated, ${count("add")} added.`,
    });
  } catch (error) {
    fail(error);
    button.disabled = false;
  }
});

show();
