defmodule Prism.Design.Components do
  @moduledoc """
  Prism's components, taken from prism 0.1.7 (`css/components.css`), on
  Prism's tokens (`Prism.Design.Tokens`). This module is Prism's whole design:
  the tokens and the components.

  Only the look is here: colors, sizes, spacing, type, borders, radii,
  shadows, opacity and motion, and how states change them. What a component
  does, and how a platform builds it, is not: each target adds its mechanics
  (`Prism.Generator.Web.Components` for the CSS). ADR 0002 records which values
  are tokens.

  The `web:` bindings hold only what is the web's own: the comments of
  `css/components.css`, and the CSS filter that tints the spinner. The names are
  0.1.7's class names for now, each written once here, so renaming them later
  is a small change.
  """
  use Prism.Generator.Schema, tokens: Prism.Design.Tokens

  web components_doc: """
      Prism UI - Component Classes

      Pre-built component classes for common UI elements.
      These classes encapsulate the Tailwind utilities for easy reuse.
      """

  @motion {150, :ease_in_out}

  # The look of a text field: the input, the textarea and the dropdown's input.
  @field [
    typography: :body,
    foreground: :grey1,
    background: :white,
    border: [width: 2, color: :grey3],
    radius: :default
  ]

  component :btn, web: [section: "Buttons", doc: "Base button styles"] do
    style typography: :button, radius: :default, transition: @motion
    part :content
    part :spinner, component: :spinner

    variant :primary,
      background: :primary,
      foreground: :white,
      padding: [y: 15, x: 16],
      web: [doc: "Primary button - filled background"] do
      state :pressed, padding: [top: 16, bottom: 14], shadow: :prism_btn_pressed
      state :disabled, opacity: 0.5
    end

    variant :primary_icon,
      background: :primary,
      foreground: :white,
      padding: [y: 4, x: 16],
      gap: 12,
      web: [doc: "Primary button with icon"] do
      state :pressed, padding: [top: 5, bottom: 3], shadow: :prism_btn_pressed
    end

    variant :secondary,
      background: :transparent,
      foreground: :primary,
      border: [width: 2, color: :primary],
      padding: [y: 13, x: 16],
      web: [doc: "Secondary button - outlined"] do
      # The deprecated top2px: it has no replacement yet.
      state :pressed, padding: [top: 14, bottom: 12], shadow: :top2px
      state :disabled, opacity: 0.5
    end

    variant :secondary_icon,
      background: :transparent,
      foreground: :primary,
      border: [width: 2, color: :primary],
      padding: [y: 13, x: 16],
      gap: 12,
      web: [doc: "Secondary button with icon"] do
      state :pressed, padding: [top: 14, bottom: 12], shadow: :top2px
    end

    variant :plain,
      background: :transparent,
      foreground: :grey1,
      padding: [y: 4, x: 0],
      web: [doc: "Plain button - text only, no background"] do
      state :pressed, padding: [top: 5, bottom: 3]
    end

    variant :plain_icon,
      background: :transparent,
      foreground: :grey1,
      padding: [y: 4, x: 0],
      gap: 8,
      web: [doc: "Plain button with icon"] do
      state :pressed, padding: [top: 5, bottom: 3]
    end

    variant :link,
      background: :transparent,
      foreground: :primary,
      decoration: :underline,
      padding: [y: 0, x: 0],
      weight: 500,
      web: [doc: "Link button - looks like a text link"] do
      state :hovered, decoration: :none
    end

    variant :label,
      foreground: :primary,
      padding: [y: 1, x: 16],
      web: [doc: "Label button - for wrapping labels, minimal styling"] do
      state :pressed, padding: [top: 2, bottom: 0]
    end

    # While loading, the content is hidden and the spinner shows in its place.
    state :loading, web: [doc: "Button with loading state"] do
      part :content, opacity: 0
    end

    # Combined with a variant above: `prism-btn-primary prism-btn-danger`.
    variants :color, web: [doc: "Color variants"] do
      variant :success, background: :success, foreground: :white
      variant :warning, background: :warning, foreground: :white
      variant :danger, background: :error, foreground: :white, aliases: [:delete]
    end
  end

  component :input, web: [section: "Inputs", doc: "Base input styles"] do
    style [height: 44, padding: [x: 12]] ++ @field ++ [transition: @motion, placeholder: :grey2]
    state :focused, border: [color: :primary]
    state :disabled, foreground: :grey3, background: :grey5
    state :error, border: [color: :warning], web: [doc: "Input with error state"]

    # On a dark background.
    variant :dark, web: [doc: "Input with dark background"] do
      state :focused, border: [color: :tertiary]
    end
  end

  component :textarea, web: [doc: "Textarea"] do
    style [min_height: 256, padding: [y: 8, x: 12]] ++
            @field ++ [transition: @motion, placeholder: :grey2]

    state :focused, border: [color: :primary]
  end

  component :label, web: [section: "Form Labels"] do
    style typography: :title6, foreground: :grey1, margin: [bottom: 8]
    variant :error, typography: :caption, foreground: :warning, margin: [top: 4]
  end

  # The component is the radio control itself; the group holds the options, and
  # each option is a label with the control and its text.
  component :radio, web: [section: "Radio Buttons"] do
    style size: 12,
          radius: :full,
          outline: [width: 2, color: :grey3, offset: 4],
          transition: @motion

    state :checked, background: :primary, outline: [color: :primary]
    part :group, gap: 32, margin: [left: 6]

    part :label, gap: 18 do
      state :disabled, opacity: 0.5
    end

    part :text, typography: :label, foreground: :grey1, margin: [top: 2]
  end

  component :dropdown, web: [section: "Dropdown / Select"] do
    part :input, [height: 44, padding: [left: 12, right: 40]] ++ @field do
      state :focused, border: [color: :primary]
    end

    part :icon, inset: [right: 12]

    # The list opens 4px below the 44px input.
    part :options,
      inset: [left: 0, top: 48],
      background: :white,
      radius: :default,
      shadow: :prism_card,
      max_height: :dropdown,
      padding: [y: 16, x: 0]

    part :option,
      height: 40,
      padding: [y: 0, x: 32],
      typography: :button,
      foreground: :grey1,
      transition: {100, :ease_in_out} do
      state :hovered, background: :grey5
      state :selected, foreground: :primary
    end
  end

  component :spinner, web: [section: "Spinner"] do
    style size: 24, rotation: {1000, :linear}

    variants :size do
      variant :sm, size: 16
      variant :lg, size: 32
    end

    variants :color, web: [doc: "Spinner colors - use with filter for different colors"] do
      variant :white, foreground: :white

      # The filter that tints the black spinner image #4272EF, approximately.
      variant :primary,
        foreground: :primary,
        web: [
          filter: [
            color: "#4272EF",
            value:
              "brightness(0) saturate(100%) invert(39%) sepia(70%) saturate(2238%) hue-rotate(209deg) brightness(97%) contrast(91%)"
          ]
        ]
    end
  end

  component :checkbox, web: [section: "Checkbox (bonus component)"] do
    style size: 20, border: [width: 2, color: :grey3], radius: 4, transition: @motion
    # The foreground is the check mark.
    state :checked, background: :primary, border: [color: :primary], foreground: :white
    state :disabled, opacity: 0.5
  end

  # Tags and alerts pair the subhead font (600) with the 14/16 text size, a pair
  # no type style has; see ADR 0002.
  component :tag,
    web: [
      section: "Tags / Badges",
      doc: "Base tag styles - colored label with background opacity"
    ] do
    style radius: :default, background: :white

    part :inner,
      radius: :default,
      padding: [y: 6, x: 12],
      typography: [font: :subhead, text: :tablehead]

    variant :primary, web: [doc: "Primary tag (default)"] do
      part :inner, background: {:primary, 0.2}, foreground: :primary
    end

    variant :success, web: [doc: "Success tag"] do
      part :inner, background: {:success, 0.2}, foreground: :success
    end

    variant :warning, web: [doc: "Warning tag"] do
      part :inner, background: {:warning, 0.2}, foreground: :warning
    end

    variant :error, aliases: [:danger], web: [doc: "Error/Danger tag"] do
      part :inner, background: {:error, 0.2}, foreground: :error
    end

    # #666666 is no token.
    variant :secondary, web: [doc: "Secondary tag"] do
      part :inner, background: {:grey2, 0.2}, foreground: "#666666"
    end
  end

  component :alert, web: [section: "Alert Banners", doc: "Base alert styles"] do
    style height: 40,
          padding: [y: 0, x: 16],
          radius: :default,
          typography: [font: :subhead, text: :tablehead]

    variant :info,
      background: {:primary, 0.15},
      foreground: :primary,
      web: [doc: "Info alert (default)"]

    variant :success,
      background: {:success, 0.15},
      foreground: :success,
      web: [doc: "Success alert"]

    variant :warning,
      background: {:warning, 0.15},
      foreground: :warning,
      web: [doc: "Warning alert"]

    variant :error, background: {:error, 0.15}, foreground: :error, web: [doc: "Error alert"]
  end

  # 12/12 is no text size.
  component :number_icon,
    web: [
      section: "Number Icons (Step Indicators)",
      doc: "Base number icon - circular badge with number"
    ] do
    style size: 24, radius: :full, typography: [font: :label, text: {12, 12}]

    variant :inactive,
      background: :grey4,
      foreground: :grey2,
      web: [doc: "Inactive state (default)"]

    variant :active, background: :primary, foreground: :white, web: [doc: "Active state"]

    variant :completed,
      background: :success,
      foreground: :white,
      web: [doc: "Completed state"]
  end
end
