# 0002: Prism's design: 0.1.7's values, fonts per platform

Status: proposed, 2026-10-31

## Context

Prism is a look for scientific software: a Tailwind preset plus component CSS, published as `@novasoftwarefoundation/prism`. Native apps need the same look: iOS now, Android later. Today a native app copies the values by hand, and the web's component CSS doesn't use the preset's own tokens.

[ADR 0001](0001-design-format.md) records the design format and the generator. This ADR records Prism's own choices: the design in `lib/design/`.

## Decision

1. **The source of truth is prism 0.1.7's styling:** `tailwind.preset.js`, `css/base.css` and `css/components.css`. `Prism.Design.Tokens` (`lib/design/tokens.ex`) reproduces 0.1.7's tokens as they are, inconsistencies included, so nothing changes for existing consumers. Each later clean-up is its own pull request with a visible golden diff.

2. **One project, three layers.** The repository is one Mix project: the generator in `lib/generator/`, Prism's design in `lib/design/`, and the generated targets in `targets/`. `config/config.exs` names the design and the output folder (`design: Prism.Design.Tokens, out: "targets/web"`). The npm package is published from `targets/web/`, with the same name, version and files as before. `css/components.css` stays hand-written until the components are in the design.

3. **Prism's web naming** comes from the `web` declaration in `Prism.Design.Tokens`: the class prefix `prism`, fonts in `../fonts`, three line-clamp classes, and 0.1.7's comments at the top of the files.

4. **Fonts per platform.** Prism has two roles:
   - `:display` for headings (> 20px): Nunito on the web;
   - `:text` for body text (≤ 20px): Nunito Sans on the web.

   Both are `:system` on iOS and Android. While iOS uses `:system`, the Swift package bundles no fonts, so there is no font generator and no TTF files in it. `font :mono` stays as it is in 0.1.7 for now: the `:text` role at weight 300, not a monospaced font.

5. **Byte-compatibility with 0.1.7.** The generator's web spelling matches 0.1.7 (upper-case hex and two-decimal alphas in the preset, `0px` in text shadows, `0` in box shadows, prettier's 80-column wrap). `test/design/golden/0.1.7/` holds 0.1.7's files, and a test requires the generated output to differ from them only by the header line and the reviewed diff in `test/design/golden/0.1.7.diff`.

   Today that diff is one line: the deprecated `floating` shadow is an alias of `prism-card`, so it is written `0 5px 20px 0` instead of `0px 5px 20px 0px`, the same computed value. Any other change to the output fails the test until the diff file is updated, so it shows in review.

6. **Brand-neutrality and theming:** the design holds Prism's defaults. It keeps 0.1.7's behaviour: the preset is overridable, the component CSS is not. Emitting CSS custom properties for theming is a possible later change, not part of this decision.

7. **One version.** `mix.exs` has the same version as `targets/web/package.json`, and a test checks it. A release tag `vX.Y.Z` will be the npm version and, later, the Swift package's version. 0.x rules apply: a removed token, class or variant is a minor bump.

## Consequences

- Prism's look is edited in `lib/design/tokens.ex` and regenerated with `mix prism.gen.web`; CI fails when the committed files differ.
- The generator can move to its own repository by moving `lib/generator/` and `test/generator/` out and adding one dependency line; nothing in Prism's design changes.
- Swift comes later in `targets/swift/`, with its own `Package.swift`.
- 0.1.7's inconsistencies stay until someone changes them on purpose.
