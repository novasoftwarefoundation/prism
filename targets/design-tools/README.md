# Design-tool files

`tokens.json` (DTCG 2025.10), `tokens.css` and `overview.svg` are generated from Prism's design by `mix prism.gen` in `design/`, and attached to each GitHub release. Don't edit them by hand. [ADR 0005](../../docs/adr/0005-design-tools.md) describes them.

## Checks

This folder is also a small npm package, not published, whose `npm test` checks these files and the generator's fixtures (`generator/test/fixtures/design_tools/`): `tokens.json` against the DTCG 2025.10 JSON Schema in `test/dtcg-2025.10/` and through Terrazzo and Style Dictionary, `tokens.css` against the DTCG paths, and `overview.svg` as standalone SVG. CI runs it.

### npm audit

The package is installed only to run these checks, on our own files; nothing from it is shipped.

- `overrides` gives Style Dictionary's bundled `glob` version 14.0.3, which fixes the advisories of `glob` and `minimatch` that its `glob` 13 pulled in.
- `npm audit` still reports three low advisories, all one: `deepmerge` allows prototype poisoning ([GHSA-gcqx-w48m-w2h4](https://github.com/advisories/GHSA-gcqx-w48m-w2h4)), through Style Dictionary 5. No `deepmerge` release fixes it, and the fix npm offers is Style Dictionary 3, which reads no DTCG 2025.10. They are accepted: Style Dictionary merges only the token files of this repository here.
