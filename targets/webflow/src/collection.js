// Prism's variables in a site's variable collection, through the Designer API: what
// applying Prism's tokens changes, and applying it (ADR 0014). A variable of the site
// is Prism's when its name has the same key (`nameKey`); it keeps its own name, and
// nothing is ever removed or renamed.
import { nameKey, prismVariables } from "./variables.js";

const create = {
  Color: "createColorVariable",
  Size: "createSizeVariable",
  FontFamily: "createFontFamilyVariable",
  Number: "createNumberVariable",
};

// The site's variables of a collection, each with its name and its base value. A
// custom value (`calc(…)`) comes back as `{type: "custom"}`, an alias as a variable.
async function siteVariables(collection) {
  return Promise.all(
    (await collection.getAllVariables()).map(async (variable) => ({
      variable,
      name: await variable.getName(),
      type: variable.type,
      value: await variable.get({ customValues: true }),
    })),
  );
}

// The collection that holds Prism's variables: the one with the most variables
// named as Prism's, or the site's default collection when none has any.
async function prismCollection(webflow, keys) {
  const counted = await Promise.all(
    (await webflow.getAllVariableCollections()).map(async (collection) => {
      const variables = await siteVariables(collection);
      const matches = variables.filter(({ name }) => keys.has(nameKey(name))).length;
      return { collection, variables, matches };
    }),
  );
  const most = Math.max(0, ...counted.map(({ matches }) => matches));
  const holding = counted.filter(({ matches }) => matches === most);
  if (most === 0) {
    const collection = await webflow.getDefaultVariableCollection();
    if (!collection) throw new Error("The site has no variable collection.");
    return { collection, variables: await siteVariables(collection) };
  }
  if (holding.length > 1) {
    const names = await Promise.all(holding.map(({ collection }) => collection.getName()));
    throw new Error(
      `Collections ${names.join(" and ")} hold as many of Prism's variables each, so it is unclear which one is Prism's. Nothing was changed.`,
    );
  }
  return holding[0];
}

function sameValue(type, site, prism) {
  if (typeof site !== typeof prism) return false;
  switch (type) {
    case "Color":
      return typeof site === "string" && site.toUpperCase() === prism;
    case "Size":
      return site.value === prism.value && site.unit === prism.unit;
    default:
      return site === prism;
  }
}

// What applying Prism's variables to a collection's variables does, per token, in
// the token file's order: `{token, name, type, action, value | alias, variable,
// reason}`, `action` being "update", "add", "unchanged" or "skip", `name` the site's
// name of the variable when it has one, and `variable` the site's variable.
export function changes({ variables, skipped }, site) {
  const byKey = Map.groupBy(site, ({ name }) => nameKey(name));
  const planned = new Map();
  const plan = (prism) => {
    const matches = byKey.get(nameKey(prism.name)) ?? [];
    const [match] = matches;
    if (matches.length > 1)
      return {
        action: "skip",
        reason: `the collection has ${matches.length} variables with this name: ${matches.map(({ name }) => `"${name}"`).join(", ")}`,
      };
    if (match && match.type !== prism.type)
      return {
        action: "skip",
        name: match.name,
        reason: `the site's "${match.name}" is a ${match.type} variable, Prism's ${prism.token} a ${prism.type}`,
      };
    if (prism.alias) {
      const target = planned.get(prism.alias);
      if (!target) return { action: "skip", reason: `it refers to ${prism.alias}, which Webflow can't hold` };
      if (target.action === "skip") return { action: "skip", reason: `it refers to ${prism.alias}, which is skipped` };
      if (target.type !== prism.type)
        return { action: "skip", reason: `it refers to ${prism.alias}, which isn't a ${prism.type}` };
    }
    if (!match) return { action: "add" };
    const same = prism.alias
      ? planned.get(prism.alias).variable?.id !== undefined && match.value?.id === planned.get(prism.alias).variable.id
      : sameValue(prism.type, match.value, prism.value);
    return { action: same ? "unchanged" : "update", name: match.name, variable: match.variable };
  };
  // Aliases last, so the variables they refer to are planned first.
  for (const prism of [...variables.filter((v) => !v.alias), ...variables.filter((v) => v.alias)])
    planned.set(prism.token, { ...prism, ...plan(prism) });
  return [...variables.map(({ token }) => planned.get(token)), ...skipped.map((skip) => ({ ...skip, action: "skip" }))];
}

async function planFor(webflow, tokens) {
  const prism = prismVariables(tokens);
  const keys = new Set(prism.variables.map(({ name }) => nameKey(name)));
  const { collection, variables } = await prismCollection(webflow, keys);
  return { collection, changes: changes(prism, variables) };
}

// What applying the tokens to the site would do, without changing anything:
// `{collection, changes}`, the collection's name and `changes/2`.
export async function preview(webflow, tokens) {
  const { collection, changes } = await planFor(webflow, tokens);
  return { collection: await collection.getName(), changes };
}

// Applies the tokens to the site's variables, and returns what it did, as `preview/2`
// does; a change Webflow refuses is skipped with Webflow's reason.
export async function apply(webflow, tokens) {
  const { canModifyVariables } = webflow.appModes;
  if (!(await webflow.canForAppMode([canModifyVariables]))[canModifyVariables])
    throw new Error(
      "Webflow doesn't let this extension change variables here: open the site's main branch in Design mode, with a role that may modify variables. Nothing was changed.",
    );

  const { collection, changes: planned } = await planFor(webflow, tokens);
  const variables = new Map(planned.filter((c) => c.variable).map((c) => [c.token, c.variable]));
  const done = new Map(planned.map((c) => [c.token, c]));
  const writes = planned.filter(({ action }) => action === "update" || action === "add");
  for (const change of [...writes.filter((c) => !c.alias), ...writes.filter((c) => c.alias)]) {
    const value = change.alias ? variables.get(change.alias) : change.value;
    try {
      if (value === undefined) throw new Error(`${change.alias} wasn't written`);
      if (change.action === "update") await change.variable.set(value);
      else variables.set(change.token, await collection[create[change.type]](change.name, value));
    } catch (error) {
      done.set(change.token, { ...change, action: "skip", reason: `Webflow refused it: ${error.message}` });
    }
  }
  return { collection: await collection.getName(), changes: planned.map(({ token }) => done.get(token)) };
}
