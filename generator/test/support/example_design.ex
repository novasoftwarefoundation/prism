defmodule Prism.Generator.ExampleDesign do
  @moduledoc false
  # A small, neutral design that uses every kind of token, for the generator's tests.
  use Prism.Generator.Schema

  web prefix: "acme",
      fonts_url: "../fonts",
      line_clamps: 2,
      preset_doc: """
      Acme - Tailwind preset

      A fixture for the DSL's tests.
      """,
      base_doc: "Acme - Base styles",
      font_classes_doc: "Font styles",
      components_doc: "Acme - Components"

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

  typography(:heading, font: :heading, text: :heading)
  typography(:body, font: :body, text: :body)
  typography(:note, font: :hint, text: :body)

  # A shared look, a web binding that replaces the radius on the web only, and an
  # iOS binding the web never reads.
  component :tag, web: [section: "Tags", radius: 2], ios: [radius: 6] do
    style radius: :default, background: :paper
    part :inner, padding: [y: 2, x: 8], typography: :body

    variant :accent, web: [doc: "An accent tag"] do
      part :inner, background: {:accent, 0.2}, foreground: :link
    end

    variant :muted, aliases: [:quiet] do
      part :inner, foreground: {:ink, 0.6}
    end

    variants :size, web: [doc: "Sizes"] do
      variant :large, padding: [x: 4]
    end

    state :disabled, opacity: 0.4 do
      part :inner, decoration: :none
    end
  end
end
