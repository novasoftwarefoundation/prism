# Used by "mix format". The spec DSL is exported, so a spec project formats it
# without parentheses with `import_deps: [:prism_kit]`.
spec_dsl = [
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
  height_step: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spec_dsl,
  export: [locals_without_parens: spec_dsl]
]
