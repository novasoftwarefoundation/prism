# 0001: Prism's spec: 0.1.7's values, fonts per platform

Status: proposed, 2026-10-31

## Context

Prism is a look for scientific software: a Tailwind preset plus component CSS, published as `@novasoftwarefoundation/prism`. Native apps need the same look: iOS now, Android later. Today a native app copies the values by hand, and the web's component CSS doesn't use the preset's own tokens.

The kit in `kit/` provides the spec format and the generators; its [ADR 0001](../../kit/docs/adr/0001-spec-format.md) records how a spec is written and generated. This ADR records Prism's own choices on top of it.

## Decision

1. **The source of truth is prism 0.1.7's styling:** `tailwind.preset.js`, `css/base.css` and `css/components.css`. `Prism.Tokens` (`lib/prism/tokens.ex`) reproduces 0.1.7's tokens as they are, inconsistencies included, so nothing changes for existing consumers. Each later clean-up is its own pull request with a visible golden diff.

2. **This repository is the implementation.** It holds Prism's spec, depends on the kit (`{:prism_kit, path: "kit"}`), names its spec in `config/config.exs`, and keeps the generated files at the root, where npm (and SwiftPM later) publish them from. `css/components.css` stays hand-written until the components are in the spec.

3. **Prism's web naming** comes from the `web` declaration in `Prism.Tokens`: the class prefix `prism`, fonts in `../fonts`, three line-clamp classes, and 0.1.7's comments at the top of the files.

4. **Fonts per platform.** Prism has two roles:
   - `:display` for headings (> 20px): Nunito on the web;
   - `:text` for body text (≤ 20px): Nunito Sans on the web.

   Both are `:system` on iOS and Android. While iOS uses `:system`, the Swift package bundles no fonts, so there is no font generator and no TTF files in it. `font :mono` stays as it is in 0.1.7 for now: the `:text` role at weight 300, not a monospaced font.

5. **Byte-compatibility with 0.1.7.** The kit's web spelling matches 0.1.7 (upper-case hex and two-decimal alphas in the preset, `0px` in text shadows, `0` in box shadows, prettier's 80-column wrap). `test/golden/0.1.7/` holds 0.1.7's files, and a test requires the generated output to differ from them only by the header line and the reviewed diff in `test/golden/0.1.7.diff`.

   Today that diff is one line: the deprecated `floating` shadow is an alias of `prism-card`, so it is written `0 5px 20px 0` instead of `0px 5px 20px 0px`, the same computed value. Any other change to the output fails the test until the diff file is updated, so it shows in review.

6. **Brand-neutrality and theming:** the spec holds Prism's defaults. It keeps 0.1.7's behaviour: the preset is overridable, the component CSS is not. Emitting CSS custom properties for theming is a possible later change, not part of this decision.

7. **One version for Prism.** `mix.exs` has the same version as `package.json`, and a test checks it. A release tag `vX.Y.Z` will be the npm version and the SwiftPM version. 0.x rules apply: a removed token, class or variant is a minor bump. The kit has its own version.

## Consequences

- Prism's look is edited in `lib/prism/tokens.ex` and regenerated with `mix prism.gen.web`; CI fails when the committed files differ.
- The kit can move to its own repository by moving `kit/` out and changing the dependency line; nothing in Prism's spec changes.
- 0.1.7's inconsistencies stay until someone changes them on purpose.
