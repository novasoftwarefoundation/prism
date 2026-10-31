# Used by "mix format". The design DSL is written without parentheses, here and
# in a design project (`import_deps: [:prism_generator]`).
design_dsl = [
  web: 1,
  color: 2,
  shadow: 2,
  shadow: 3,
  text_shadow: 2,
  radius: 2,
  max_height: 2,
  family: 2,
  font: 3,
  font: 4,
  text: 3,
  space: 1,
  space: 2,
  height_step: 1,
  component: 1,
  component: 2,
  component: 3,
  style: 1,
  variants: 2,
  variant: 1,
  variant: 2,
  variant: 3,
  part: 1,
  part: 2,
  part: 3,
  state: 1,
  state: 2,
  state: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: design_dsl,
  export: [locals_without_parens: design_dsl]
]
