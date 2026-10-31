# 0005: Files for design tools

Status: proposed, 2026-10-31

## Context

Designers work in design tools (Figma, Penpot, pen.dev, Paper), and a visual site builder will take Prism's tokens into its own variables later. Today they copy Prism's values by hand from the CSS, so the values drift, and nothing shows the whole design in one place.

Tools take tokens in different ways. Figma and Penpot import the W3C Design Tokens Community Group (DTCG) format, whose first stable version is 2025.10. pen.dev and Paper document no DTCG import; their agents create variables from a project's CSS custom properties. A picture of the design every tool can open is an SVG.

## Decision

1. **A file target, `design_tools`.** `Prism.Generator.DesignTools` writes three files from `__schema__/0` into the folder the config names (`targets/design-tools/` for Prism): `tokens.json`, `tokens.css` and `overview.svg`. They are committed, carry the `Prism.Generator.Header` line, and `mix prism.gen --check` covers them, as it covers the other targets. JSON has no comments, so the header of `tokens.json` is the root group's `$description`, which DTCG allows. The token files name the tokens' design file, the overview the components' file. The files are attached to each release.

2. **One naming rule for both token files.** A token's DTCG path is a group for its kind and the token's name, with `-` for `_`; its CSS name is `--`, the web prefix, and the path joined by `-`. `color.primary` is `--prism-color-primary`. Style Dictionary names CSS variables the same way, and the checks compare the two. The groups and their DTCG types:

   | Group | `$type` | From the design |
   |---|---|---|
   | `color` | `color` | colors |
   | `font-family` | `fontFamily` | families |
   | `font-weight` | `fontWeight` | fonts |
   | `font-size`, `line-height` | `dimension` | text sizes |
   | `typography` | `typography` | typography tokens |
   | `spacing`, `height` | `dimension` | spacing and height steps, under their web key (`2px`, `15`) |
   | `max-height`, `radius` | `dimension` | maximum heights, radii |
   | `shadow`, `text-shadow` | `shadow` | shadows, text shadows |

   A color, a size and a font family each have one flat value, so a tool maps each to one variable.

3. **DTCG 2025.10 values, and nothing tool-specific.** Colors are color objects (`srgb` components, alpha and the hex), lengths are dimension objects in `px` or `rem`, weights are numbers. An alias is a reference (`"{color.error}"`), and a deprecated shadow has `$deprecated: true`. Data that no DTCG type has goes under `$extensions`, in one `prism` key.
   - DTCG has no percent unit, so a length in percent (Prism's 50% radius) is only in `tokens.css`.
   - The file is checked against the DTCG 2025.10 JSON Schema and through Terrazzo's and Style Dictionary's parsers (decision 7).

4. **Composites.**
   - A **typography token** (`typography`) refers to its parts: `fontFamily`, `fontWeight` and `fontSize` are references to the family, the font's weight and the text size. `lineHeight` is a number, a multiple of the font size, as the format defines it (68/64 is 1.0625, to four decimals); the line height in px stays in `line-height`. `letterSpacing`, which the format requires, is 0, since the design has none. In CSS a typography token is the `font` shorthand, from the same custom properties: `--prism-typography-title0: var(--prism-font-weight-title0) var(--prism-font-size-title0)/var(--prism-line-height-title0) var(--prism-font-family-display)`. An app sets it with `font: var(--prism-typography-title0)`.
   - A **shadow** is one shadow object, with every field the format requires (a text shadow's spread is 0). Its color has its own alpha, so it is a value, not a reference. In CSS it is the `box-shadow` value, and a text shadow the `text-shadow` value.
   - The shorthand keeps one custom property per token, so the two files have the same tokens. One property per field (`--prism-typography-title0-font-size`, …) would give a typography token names that aren't DTCG paths.

5. **Font roles.** A family token is the role's web font: `$value` is the font's name alone (`"Nunito"`), the form Figma's import takes. The rest of the family is under `$extensions.prism`: the web fallback, and the iOS and Android binding, `"system"` or `{"name": …}`. A font's weight token names its family there (`"family": "{font-family.display}"`) and `italic` when the font is italic; DTCG's typography has no font style, so a typography token with an italic font has `"fontStyle": "italic"` there too. In CSS a family is the name and its fallback (`"Nunito Sans", sans-serif`).

6. **The overview** (`Prism.Generator.DesignTools.Overview`) draws every token and every component as one standalone SVG:
   - Tokens: color swatches with name and value; the families, fonts, text sizes and typography in their own fonts; spacing and heights as bars; radii; shadows on cards; text shadows on text.
   - Components: a sheet per component, a row per variant (each variant of the `:variant` axis, the component without one when that axis has no default, and each variant of another axis with the first variant), a column per state. A cell is drawn from the data `components.css` is made from: the shared look with the `web:` binding's properties, and the markup of `Prism.Generator.Web.Elements`, so a part shows inside its component. It is a sketch: text widths are estimated, and of the web's mechanics it draws only the spinner's ring and the checkbox's check mark.
   - For design tools to import: text is plain `<text>` whose `font-family` is the web font's name alone, so a tool matches the installed Nunito and Nunito Sans; every look is a presentation attribute (no CSS); shadows are SVG filters in the structure Figma writes for its own drop and inner shadows; every group has an `id`, which tools show as the layer's name, by the token's path (`color/primary`; a text size, two tokens, is `font-size/<name>` with `line-height/<name>` inside) or the component's cell (`button/primary/pressed`). It has no external references, so it opens standalone in a browser.

7. **Checks.** In `generator/`, the example design's three files are reviewed fixtures (`generator/test/fixtures/design_tools/`), and Elixir tests cover the names, the values, the extensions, the percent length, name clashes, and the overview's tokens, components and references. `targets/design-tools/` has a small package of its own, not published, whose `npm test` checks the fixtures and Prism's files: `tokens.json` against the DTCG 2025.10 JSON Schema (kept in `test/dtcg-2025.10/`, since designtokens.org serves only its top file) and through Terrazzo and Style Dictionary, which must read every token and resolve every reference; `tokens.css` as CSS whose names are the DTCG paths, as Style Dictionary names them; and `overview.svg` as well-formed SVG without external references, scripts, styles or images, whose text names only the tokens' families. CI runs it.

8. **Release assets, no automation yet.** The repository has no release workflow. The README's Publish steps attach the three files to the GitHub release of the version's tag.

## Alternatives

| Option | Why not |
|---|---|
| DTCG's earlier draft values (`"#4272EF"`, `"16px"`) | Penpot and Tokens Studio read them today, but they fail the 2025.10 schema, and Figma's own import reads 2025.10. |
| A file per tool (Tokens Studio's format, Figma's extensions) | Tool-specific fields in a format meant to be tool-neutral, and a file to keep up per tool. |
| Typography as one custom property per field | More names, and names that aren't DTCG paths, so the two files would not share one rule. |
| Literal values in the typography tokens | A changed text size would have to change in two places; a reference keeps one source, and DTCG parsers resolve it. |
| The radius `full` as a large `px` value | Another value than the design's; DTCG simply can't express it, which the file shows by leaving it out. |
| A browser screenshot (PNG) as the overview | Not editable in a design tool, and it needs a browser to generate. |
| Outlined text in the SVG | Matches without the fonts installed, but tools can't edit it as text. |

## Consequences

- Designers and agents get the design's tokens and a picture of it from the release, in a standard format and as CSS.
- Imports differ per tool, as the README's steps say: Figma's import takes colors, `px` dimensions and font families, not weights, the `rem` radius, typography or shadows; pen.dev and Paper have no variables for typography or shadows; Penpot's current resolver doesn't read DTCG 2025.10 dimension objects yet. Each tool's import is still to be checked by hand.
- A new token kind needs a group in both token files and a place in the overview; a new kind of component needs its markup in `Prism.Generator.Web.Elements`, which the overview already reads.
- The Webflow step reads `tokens.json` (or `tokens.css`) with the names of decision 2.
