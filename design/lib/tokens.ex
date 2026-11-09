defmodule Prism.Design.Tokens do
  @moduledoc """
  Prism's design tokens, taken from prism 0.1.7 (`tailwind.preset.js`,
  `css/base.css`, `css/components.css`). Brand-neutral: these are Prism's
  defaults; a consumer that brands them overrides them in its own build.
  """
  use Prism.Generator.Schema

  web prefix: "prism",
      fonts_url: "../fonts",
      line_clamps: 3,
      preset_doc: """
      Prism UI - Tailwind CSS Preset

      A playful but professional design system for scientific software.
      Uses Nunito (>20px) and Nunito Sans (≤20px) variable fonts.
      """,
      base_doc: """
      Prism UI - Base Styles

      This file contains:
      - @font-face declarations for Nunito variable fonts
      - Base reset/normalization
      - Utility classes
      """,
      font_classes_doc: "Font weight overrides for Nunito/Nunito Sans variable fonts"

  # The Swift package: `Prism`, its types `PrismButtonStyle`, `Prism.Colors`, ….
  swift module: "Prism"

  group "Brand colors" do
    color :primary, "#4272EF"
    color :primarylight, "#E3EAFD"
    color :secondary, "#FF5E5E"
    color :tertiary, "#FFCF60"
  end

  group "Status colors" do
    color :success, "#52BA12"
    color :successlight, "#EBFFDF"
    color :warning, "#F28D15"
    color :warninglight, "#FFEFDC"
    color :error, "#DB1E1E"
    color :errorlight, "#FFECEC"
    color :delete, :error
    color :deletelight, :errorlight
  end

  group "Neutral colors" do
    color :black, "#000000"
    color :grey1, "#222222"
    color :grey2, "#999999"
    color :grey3, "#CCCCCC"
    color :grey4, "#EEEEEE"
    color :grey5, "#F6F6F6"
    color :grey6, "#FAFAFA"
    color :white, "#FFFFFF"
  end

  group "Nova effect styles" do
    shadow :prism_btn_pressed, inset: true, y: 4, color: {:black, 0.15}
    shadow :prism_container, y: 10, blur: 30, color: {:black, 0.05}
    shadow :prism_card, y: 5, blur: 20, color: {:black, 0.1}
    shadow :prism_text_overlay, y: 8, blur: 16, color: {:black, 0.3}
  end

  group "Deprecated — use btn-pressed / card instead" do
    shadow :top4px, :prism_btn_pressed, deprecated: true
    # No replacement yet: the secondary button's pressed state uses it.
    shadow :top2px, [inset: true, y: 2, color: {:black, 0.15}], deprecated: true
    shadow :floating, :prism_card, deprecated: true
  end

  text_shadow :default, y: 2, blur: 4, color: {:black, 0.3}
  text_shadow :md, y: 4, blur: 8, color: {:black, 0.3}
  text_shadow :lg, y: 8, blur: 16, color: {:black, 0.3}

  space [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17, 18, 19, 22, 30, 44, 48, 60, 64]
  space 15, 60
  space 30, 120

  height_step 44

  max_height :dropdown, 317

  # Radii are not in the preset: 0.1.7's components write 0.25rem (Tailwind's
  # `rounded`) and 50% as literals. They are tokens for the components and
  # the native targets; the web target doesn't read them yet.
  radius :default, {0.25, :rem}
  radius :full, {50, :percent}

  # Weights: what a font names, lightest first, after Nunito's own instances. Each
  # family's binding gives every weight a number of its font (`scale:`), so a title
  # looks as heavy in SF Pro on iOS as in Nunito on the web (ADR 0013).
  weights [:light, :regular, :medium, :semibold, :bold, :extrabold]

  # 0.1.7's numbers, which Nunito and Nunito Sans keep.
  @nunito [light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, extrabold: 800]
  # SF Pro as heavy as Nunito and Nunito Sans: the stem of each weight, measured at
  # each Typography's size and at a large Dynamic Type size (ADR 0013).
  @sf_pro [light: 300, regular: 400, medium: 400, semibold: 500, bold: 600, extrabold: 700]
  # No Android target reads these yet: today's numbers until one does.
  @android @nunito

  # Families are roles; each platform binds them to a font. The web keeps 0.1.7's
  # Nunito and Nunito Sans; iOS and Android use their system fonts.
  family :display,
    doc: "Headings (> 20px)",
    web: [
      name: "Nunito",
      fallback: "sans-serif",
      faces: [[file: "Nunito-VariableFont_wght", weights: {200, 900}, style: :normal]],
      scale: @nunito
    ],
    ios: {:system, scale: @sf_pro},
    android: {:system, scale: @android}

  family :text,
    doc: "Body text (≤ 20px)",
    web: [
      name: "Nunito Sans",
      fallback: "sans-serif",
      faces: [
        [file: "NunitoSans-VariableFont_wght", weights: {200, 1000}, style: :normal],
        [file: "NunitoSans-Italic-VariableFont_wght", weights: {200, 1000}, style: :italic]
      ],
      scale: @nunito
    ],
    ios: {:system, scale: @sf_pro},
    android: {:system, scale: @android}

  # Fonts: family and weight (`font-…`). Sizes are separate (`text-…`).
  font :title0, :display, :extrabold
  font :title1, :display, :extrabold
  font :title2, :display, :extrabold
  font :title3, :display, :extrabold
  font :title4, :display, :extrabold
  font :title5, :display, :bold
  font :bodylarge, :display, :light
  font :introdesktop, :display, :medium
  font :quote, :display, :bold
  font :title6, :text, :bold
  font :title7, :text, :bold
  font :caption, :text, :medium
  font :link, :text, :medium
  font :subhead, :text, :semibold
  font :button, :text, :bold
  font :footnote, :text, :medium
  font :intro, :text, :medium
  font :label, :text, :bold
  font :body, :text, :light
  font :hint, :text, :light, italic: true
  font :tablehead, :text, :bold
  font :tablerow, :text, :regular
  font :bold, :text, :bold
  font :mono, :text, :light

  # Text sizes: size and line height in px (`text-…`).
  text :title0, 64, 68
  text :title1, 50, 55
  text :title2, 40, 44
  text :title3, 32, 38
  text :title4, 28, 32
  text :title5, 24, 26
  text :title6, 20, 22
  text :title7, 16, 20
  text :caption, 14, 18
  text :captionsmall, 12, 14
  text :subhead, 20, 20
  text :label, 16, 16
  text :labelsmall, 14, 14
  text :button, 18, 18
  text :buttonsmall, 16, 16
  text :footnote, 16, 30
  text :intro, 20, 30
  text :introdesktop, 24, 36
  text :bodylarge, 24, 36
  text :bodymedium, 20, 30
  text :bodysmall, 16, 24
  text :bodylinklarge, 24, 36
  text :bodylinkmedium, 30, 30
  text :link, 16, 24
  text :hint, 20, 24
  text :tablehead, 14, 16
  text :tablerow, 14, 16
  text :mono, 20, 24
  text :quote, 24, 30

  # Typography: one font and one text size. Native targets read type only from
  # these; the web keeps the two lists above. See ADR 0002 for the pairings.
  # A role in both lists pairs with itself.
  typography(:title0, font: :title0, text: :title0)
  typography(:title1, font: :title1, text: :title1)
  typography(:title2, font: :title2, text: :title2)
  typography(:title3, font: :title3, text: :title3)
  typography(:title4, font: :title4, text: :title4)
  typography(:title5, font: :title5, text: :title5)
  typography(:title6, font: :title6, text: :title6)
  typography(:title7, font: :title7, text: :title7)
  typography(:caption, font: :caption, text: :caption)
  typography(:subhead, font: :subhead, text: :subhead)
  typography(:label, font: :label, text: :label)
  typography(:button, font: :button, text: :button)
  typography(:footnote, font: :footnote, text: :footnote)
  typography(:intro, font: :intro, text: :intro)
  typography(:introdesktop, font: :introdesktop, text: :introdesktop)
  typography(:bodylarge, font: :bodylarge, text: :bodylarge)
  typography(:link, font: :link, text: :link)
  typography(:hint, font: :hint, text: :hint)
  typography(:tablehead, font: :tablehead, text: :tablehead)
  typography(:tablerow, font: :tablerow, text: :tablerow)
  typography(:mono, font: :mono, text: :mono)
  typography(:quote, font: :quote, text: :quote)

  # Roles in only one list, paired as the main consumer app combines them.
  typography(:body, font: :body, text: :bodymedium)
  typography(:bold, font: :bold, text: :bodymedium)
  typography(:bodymedium, font: :body, text: :bodymedium)
  typography(:bodysmall, font: :body, text: :bodysmall)
  typography(:captionsmall, font: :caption, text: :captionsmall)
  typography(:labelsmall, font: :label, text: :labelsmall)
  typography(:buttonsmall, font: :button, text: :buttonsmall)
  # No screen uses these two sizes: paired like their sibling, `link`.
  typography(:bodylinklarge, font: :link, text: :bodylinklarge)
  typography(:bodylinkmedium, font: :link, text: :bodylinkmedium)
end
