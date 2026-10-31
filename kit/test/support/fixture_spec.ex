defmodule PrismKit.FixtureSpec do
  @moduledoc false
  # A small spec that uses every kind of token, for the kit's own tests.
  use PrismKit.Schema

  web prefix: "acme",
      fonts_url: "../fonts",
      line_clamps: 2,
      preset_doc: """
      Acme - Tailwind preset

      A fixture for the kit's tests.
      """,
      base_doc: "Acme - Base styles",
      font_classes_doc: "Font styles"

  group "Brand" do
    color :accent, "#1A73E8"
    color :link, :accent
  end

  color :ink, "#101010"
  color :paper, "#FDFDFD"

  group "Effects" do
    shadow :pressed, inset: true, y: 3, color: {:ink, 0.2}
    shadow :card, y: 6, blur: 24, color: {:ink, 0.08}
  end

  group "Deprecated" do
    shadow :raised, :card, deprecated: true
  end

  text_shadow :default, y: 1, blur: 2, color: {:ink, 0.25}
  text_shadow :strong, y: 3, blur: 6, color: {:ink, 0.5}

  space [2, 4, 8]
  space 10, 40

  height_step 36

  max_height :menu, 240

  radius :default, 4

  family :display,
    doc: "Headings (> 24px)",
    web: [
      name: "Acme Display",
      fallback: "serif",
      faces: [[file: "AcmeDisplay", weights: {300, 900}, style: :normal]]
    ],
    ios: :system,
    android: :system

  family :text,
    doc: "Body text",
    web: [
      name: "Acme Text",
      fallback: "sans-serif",
      faces: [
        [file: "AcmeText-VariableFont_wght", weights: {100, 1000}, style: :normal],
        [file: "AcmeText-Italic-VariableFont_wght", weights: {100, 1000}, style: :italic]
      ]
    ],
    ios: :system,
    android: [
      name: "Acme Text",
      faces: [[file: "AcmeText", weights: {100, 1000}, style: :normal]]
    ]

  font :heading, :display, 800
  font :body, :text, 400
  font :hint, :text, 300, italic: true

  text :heading, 32, 40
  text :body, 16, 24
end
