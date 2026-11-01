import Config

# The design that `mix prism.gen` generates from, and the folder of each target.
config :prism_generator,
  design: Prism.Design.Components,
  targets: [
    web: "../targets/web",
    react: "../targets/react",
    design_tools: "../targets/design-tools",
    swift: "../targets/swift"
  ]
