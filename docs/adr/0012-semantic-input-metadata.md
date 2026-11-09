# 0012: Semantic input metadata, with behavior owned by forms

Status: proposed, 2026-11-06

## Context

A form may save after an input has settled, without a Save button. Its debounce
belongs to the input definition shared across platforms. Visual values describe
looks and are limited to 0..100; they cannot represent this data. Prism's styled
fields do not own the containing form, its values, validation or requests.

## Decision

Declare optional semantic input properties in the component DSL, outside visual
styles, variants and states. This extends the design's data vocabulary without
adding behavior to its rendered controls:

```elixir
input_property :debounce_ms,
  type: :integer,
  unit: :millisecond,
  min: 1,
  max: 2_147_483_647,
  default: nil
```

Prism declares this property on `text_field` and `text_area`. Each component's
`__schema__/0` data exposes `input_properties` descriptors. Designs without
these declarations have an empty list. The initial property kind is optional
integer milliseconds, with explicit inclusive positive bounds within the signed
32-bit millisecond range. Defaults are nil. No visual token or CSS class is added.

Each input instance may carry `debounce_ms` on the wire or in Elixir, or
`debounceMs` in Swift/TypeScript. Values 1..2147483647 are valid integer
milliseconds. Absence or null/nil means the form doesn't submit automatically:
the user submits it. Zero, negatives, fractions, strings, booleans, nonfinite
values and values above the maximum are rejected, never clamped or coerced. The
upper bound fits signed 32-bit millisecond timers; it is not a suggested
debounce.

The generator supplies separate data APIs:

- Elixir: `Prism.Generator.InputMetadata.validate!(schema, component, metadata)`
  validates atom-keyed metadata and normalizes missing values to nil.
- React: `TextFieldInputMetadata` / `TextAreaInputMetadata`, with pure
  `textFieldInputMetadata(...)` / `textAreaInputMetadata(...)` validation helpers.
  They normalize missing values to null. A TypeScript number still needs runtime
  validation to enforce integer bounds. The consumer maps snake_case wire data
  to these camelCase properties; these types are not native DOM props.
- Swift: `PrismTextFieldInputMetadata` / `PrismTextAreaInputMetadata`, immutable
  Codable, Equatable, Sendable structs. Throwing construction and decoding
  enforce the bounds; coding keys use snake_case. A nil value encodes as an
  omitted optional key. Existing styled-field modifier signatures are unchanged.

The Form consumer submits the form once the input has been unchanged for
`debounce_ms`. It owns that timing, replacement/cancellation of pending work,
validation, current-value snapshots, request serialization, stale-result
suppression, errors and accessibility.
Prism creates no timer, callback or implicit submit behavior. Adding the property
to a styled field alone does not save anything. Removing Account's Save button
and testing timing/cancellation belong to separate consumer work.

## Compatibility and verification

Existing rendering, CSS and styled-field calls remain unchanged. No version is
bumped or release made in this change. Feldspar compatibility coordination stays
open; no consumer integration or cross-platform end-to-end success is claimed.

Tests cover the declaration shape and placement, numeric boundaries, invalid
types, disabled defaults, generated exports, Swift decoding/encoding and neutral
design fixtures. Actual scheduling tests must run in the Form implementation.

<sub>Written by an AI agent (Codex · GPT-6, herdr-projects next · t-0332).</sub>
