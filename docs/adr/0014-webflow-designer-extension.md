# 0014: Prism's tokens in Webflow's variables, through a Designer Extension

Status: proposed, 2026-11-09

## Context

eyra.co is a Webflow site. Its developer copied Prism's colors into the site's variables by hand, as `primary`, `secondary`, `tertiary` and grey 1 to 6, and styles are bound to them. The copy drifts from Prism. The other tokens (sizes, families, weights) aren't in the site at all.

Webflow's variables can be written only through the Designer API, which runs inside an open Designer in an extension's iframe. There is no REST endpoint, so CI can't sync them. Webflow has five types of variable: color, size, number, percentage and font family ([Variables overview](https://developers.webflow.com/designer/reference/variables-overview)). It has none for typography or shadows.

The site's developer asked for this delivery (Flux 10462971063, 9 Nov 2026):
- Prism's tokens go in the same collection, under the same names, so bound styles follow.
- No code components.
- A file in each Prism release, applied with one click.

## Decision

1. **A Designer Extension, "Prism tokens", in `targets/webflow/`.** It doesn't generate anything: it reads the design-tool target's `tokens.json` ([ADR 0005](0005-design-tools.md)), and `mix prism.gen` writes nothing into its folder. It is a small npm package of its own, not published:
   - `webflow.json`: `name`, `publicDir`, `size` and `apiVersion: "2"`, as the [configuration guide](https://developers.webflow.com/apps/designer/guides/configuring-your-app) and the CLI's scaffold have it.
   - `public/`: the panel's markup and CSS.
   - `src/`: the mapping (`variables.js`), the Designer API side (`collection.js`) and the panel (`panel.js`).
   - The build (`build.mjs`, esbuild) bundles the panel and `tokens.json` into one classic script, `public/panel.js`. The extension loads no module and fetches no file. Webflow documents neither for an uploaded bundle; it documents the injected `webflow` global.
   - `webflow extension bundle`, from Webflow's CLI ([CLI commands](https://developers.webflow.com/cli/command-reference), [publishing](https://developers.webflow.com/apps/docs/publishing-your-app)), zips `public/` and `webflow.json` into `bundle.zip`. It checks that `index.html` is there, every file's type, and that the zip is under 5 MB. It needs no login.

2. **Names follow one rule:**
   - A color is named by its token name (`color.primary` is `primary`, `color.grey1` is `grey1`), as the site's collection already names Prism's colors.
   - Any other token goes in a folder of its DTCG group: `font-size.title0` is `font-size/title0`. Webflow's Variables panel shows a name with `/` as a group ([Variables](https://help.webflow.com/hc/en-us/articles/33961268146323)).
   - A site variable is Prism's when its name has the same key. The key keeps the letters and digits of each folder, lowercased, so `Grey 1`, `grey-1` and `grey1` are one variable.
   - The site's variable keeps its name. The rule needs no list of the site's names.

3. **Values by type:**

   | DTCG `$type` | Webflow variable | Value |
   |---|---|---|
   | `color` | color | `#RRGGBB`, or `#RRGGBBAA` when not opaque |
   | `dimension` | size | `{value, unit}`; a unit Webflow has no size for is skipped |
   | `fontFamily` | font family | the font's name (`Nunito`) |
   | `fontWeight` | number | the weight |
   | `typography`, `shadow` | none | skipped |

   A reference (`color.delete` is `{color.error}`) is an alias of the other variable, which the Designer API takes as a value of the same type. It is skipped when the other variable is skipped.

4. **The collection:** the one that holds the most variables with Prism's names. If none holds any, the site's default collection. If two hold the same number, nothing is changed.

5. **One run:**
   - The panel first shows what a run will do: to update, to add, unchanged, and skipped with why. One click applies it, and the panel then shows what was done.
   - A run sets the base value of a variable whose value differs and creates the missing variables. It never removes, renames or retypes a variable.
   - A variable with a Prism name but another type is skipped. So are two variables whose names have one key.
   - A run checks `canModifyVariables` ([App modes](https://developers.webflow.com/designer/reference/app-modes)) before it changes anything. A change Webflow refuses is listed as skipped, with Webflow's message.
   - A second run finds every value equal and changes nothing.

6. **Delivery:** the release workflow builds the bundle before anything is published and attaches it to the GitHub release as `prism-tokens-webflow.zip`, next to the design-tool files.
   - The panel shows the version from `design/mix.exs`, which the release checks against the tag.
   - The workspace's admin uploads each release's zip as a new version of the workspace's own app ([Publishing your app](https://developers.webflow.com/apps/docs/publishing-your-app)). An app for its own workspace needs no Marketplace review.
   - `targets/webflow/README.md` is written for the site's developer.

7. **Checks:**
   - `npm test` in `targets/webflow/` runs the mapping and the runs against a fake of the Designer API (`test/designer.js`, after `@webflow/designer-extension-typings` 2.2.2): update by name, add what's missing, skip what Webflow can't hold, an idempotent second run, no removal or rename, the collection's choice, the app mode, Webflow's refusals, and Prism's own `tokens.json`.
   - A CI job runs it, builds the bundle with Webflow's CLI and checks the bundle's file list.
   - The run in a real Designer is the site's test after a merge, not a merge gate.

## Alternatives

| Option | Why not |
|---|---|
| A separate "Prism" collection | The site's styles are bound to the variables in its own collection, and the developer chose to keep that collection. |
| A list of the site's names (`Grey 1` for `grey1`) | A list of one site's names in Prism; a key on the names fits any spelling and needs no update when a token is added. |
| Every token in a folder (`color/primary`) | The site's colors are at the collection's root, and the developer chose to keep their names. |
| Fetch `tokens.json`, or the panel as an ES module | Webflow documents neither for an uploaded bundle; one classic script needs nothing from the host. |
| Webflow's TypeScript or React scaffold | A compiler or a framework for three hundred lines of DOM; the typings are a reference for the fake instead. |
| Code components from the React target (DevLink) | The site's developer builds with Webflow's own elements and asked for variables only. |
| Typography as several variables per token | They exist already: the family, weight, size and line-height variables a typography combines. |

## Consequences

- One click in the Designer brings a Prism release's tokens into the site. Styles bound to `primary` or `Grey 1` follow, and new tokens appear under Prism's names.
- Typography and shadows stay hand-made in Webflow, as text styles and shadow settings built from the variables.
- Each release needs a workspace admin to upload the new zip; Webflow has no CLI upload.
- Webflow's CLI is a development dependency, used only to zip the bundle. Its dependencies have `npm audit` advisories (`zod`, `undici` and others, through `@webflow/cloud-app` and `@module-federation`), and the fix npm offers is an older CLI. They are accepted: the CLI only zips this repository's own files, in CI and on a developer's machine, and nothing from it ships.
- Not verified, since no Designer was opened for this work:
  - that a `/` in a name set through the API shows as a group (documented for names typed in the panel);
  - that Webflow refuses a duplicate name (the fake does, so the second run's equality is what keeps a run from creating one twice);
  - how a name becomes a CSS custom property (Webflow says names in non-base collections will change).
  The site's test checks the first.
