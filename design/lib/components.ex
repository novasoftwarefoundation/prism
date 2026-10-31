defmodule Prism.Design.Components do
  @moduledoc """
  Prism's components, taken from prism 0.1.7 (`css/components.css`), on
  Prism's tokens (`Prism.Design.Tokens`). This module is Prism's whole design:
  the tokens and the components.

  Only the look is here: colors, sizes, spacing, type, borders, radii,
  shadows, opacity and motion, and how states change them. What a component
  does, and how a platform builds it, is not: each target adds its mechanics
  (`Prism.Generator.Web.Components` for the CSS). ADR 0002 records which values
  are tokens, and the names.

  The names are the ones design systems share (ADR 0002): a component, its
  parts, and separate axes for `variant` (emphasis), `tone` (color meaning),
  `size` and `status`. Tones are `accent`, `neutral`, `highlight`, `info`,
  `success`, `warning` and `danger`. The web target's mechanics are keyed on the
  component and part names too, so a rename changes the generator as well.

  The `web:` bindings hold only the comments of `css/components.css`.
  """
  use Prism.Generator.Schema, tokens: Prism.Design.Tokens

  web components_doc: """
      Prism UI - Component Classes

      Pre-built component classes for common UI elements.
      These classes encapsulate the Tailwind utilities for easy reuse.
      """

  @motion {150, :ease_in_out}

  # The look of a text field: the text field, the text area and the select's field.
  @field [
    typography: :body,
    foreground: :grey1,
    background: :white,
    border: [width: 2, color: :grey3],
    radius: :default
  ]

  component :button, web: [section: "Buttons", doc: "Base button styles"] do
    style typography: :button, radius: :default, transition: @motion
    part :label
    # The app puts the icon at the start (the default) or the end of the label.
    part :icon, position: :start
    part :spinner, component: :spinner

    # With an icon, a button spaces the icon from its label (`--with-icon`).
    variant :primary,
      background: :primary,
      foreground: :white,
      padding: [y: 15, x: 16],
      web: [doc: "Primary button - filled background"] do
      state :pressed, padding: [top: 16, bottom: 14], shadow: :prism_btn_pressed
      state :disabled, opacity: 0.5

      with_part :icon, padding: [y: 4, x: 16], gap: 12, web: [doc: "Primary button with icon"] do
        state :pressed, padding: [top: 5, bottom: 3]
      end
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
      with_part :icon, gap: 12, web: [doc: "Secondary button with icon"]
    end

    # Without padding (`padded` off), a plain or text button fits its text.
    variant :plain,
      background: :transparent,
      foreground: :grey1,
      padding: [y: 4, x: 0],
      web: [doc: "Plain button - text only, no background"] do
      state :pressed, padding: [top: 5, bottom: 3]
      with_part :icon, gap: 8, web: [doc: "Plain button with icon"]
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

    # Was 0.1.7's label button.
    variant :text,
      foreground: :primary,
      padding: [y: 1, x: 0],
      web: [doc: "Text button - brand-colored text, minimal styling"] do
      state :pressed, padding: [top: 2, bottom: 0]
    end

    # The tone's light color behind the tone's color, as a primary button is laid out.
    variant :soft,
      background: :primarylight,
      foreground: :primary,
      padding: [y: 15, x: 16],
      web: [doc: "Soft button - the tone's light color as its background"] do
      state :pressed, padding: [top: 16, bottom: 14], shadow: :prism_btn_pressed
      state :disabled, opacity: 0.5

      with_part :icon, padding: [y: 4, x: 16], gap: 12, web: [doc: "Soft button with icon"] do
        state :pressed, padding: [top: 5, bottom: 3]
      end
    end

    # An icon only: the app gives the icon and a label for assistive technology.
    variant :icon, size: 24, web: [doc: "Icon button - an icon only"] do
      state :pressed, opacity: 0.8
    end

    # While loading, the label is hidden and the spinner shows in its place.
    state :loading, web: [doc: "Button with loading state"] do
      part :label, opacity: 0
    end

    # Combined with a variant above: `prism-button--primary prism-button--danger`.
    # Without a tone, a button is accent, which has no class. A tone colors the
    # background of a primary button, and the text (and the border) of the
    # others; a soft button takes the tone's light color as its background. The
    # neutral and highlight tones have no light color, so no soft look.
    variants :tone, default: :accent, web: [doc: "Tones"] do
      variant :success do
        with_variant(:primary, background: :success, foreground: :white)
        with_variant(:secondary, foreground: :success, border: [color: :success])
        with_variant([:plain, :link, :text], foreground: :success)
        with_variant(:soft, background: :successlight, foreground: :success)
      end

      variant :warning do
        with_variant(:primary, background: :warning, foreground: :white)
        with_variant(:secondary, foreground: :warning, border: [color: :warning])
        with_variant([:plain, :link, :text], foreground: :warning)
        with_variant(:soft, background: :warninglight, foreground: :warning)
      end

      variant :danger do
        with_variant(:primary, background: :error, foreground: :white)
        with_variant(:secondary, foreground: :error, border: [color: :error])
        with_variant([:plain, :link, :text], foreground: :error)
        with_variant(:soft, background: :errorlight, foreground: :error)
      end

      variant :neutral do
        with_variant(:primary, background: :grey1, foreground: :white)
        with_variant(:secondary, foreground: :grey1, border: [color: :grey1])
        with_variant([:plain, :link, :text], foreground: :grey1)
      end

      variant :highlight do
        with_variant(:primary, background: :tertiary, foreground: :grey1)
        with_variant(:secondary, foreground: :tertiary, border: [color: :tertiary])
        with_variant([:plain, :link, :text], foreground: :tertiary)
      end
    end

    # On by default: a plain or text button as tall as a primary or secondary one
    # beside it.
    flag :padded, default: true, web: [doc: "Plain and text buttons with padding"] do
      with_variant [:plain, :text], padding: [y: 15, x: 16] do
        state :pressed, padding: [top: 16, bottom: 14]
      end
    end
  end

  component :text_field, web: [section: "Text fields", doc: "Base text field styles"] do
    style [height: 44, padding: [x: 12]] ++ @field ++ [transition: @motion, placeholder: :grey2]
    state :focused, border: [color: :primary]
    state :disabled, foreground: :grey3, background: :grey5
    state :invalid, border: [color: :warning], web: [doc: "Text field with an invalid value"]

    # On a dark background.
    variant :inverse, web: [doc: "Text field on a dark background"] do
      state :focused, border: [color: :tertiary]
    end
  end

  component :text_area, web: [doc: "Text area"] do
    style [min_height: 256, padding: [y: 8, x: 12]] ++
            @field ++ [transition: @motion, placeholder: :grey2]

    state :focused, border: [color: :primary]
  end

  # A label and an error message around a control.
  component :field, web: [section: "Fields"] do
    part :label, typography: :title6, foreground: :grey1, margin: [bottom: 8]
    part :error_message, typography: :caption, foreground: :warning, margin: [top: 4]
  end

  component :radio_group, web: [section: "Radio Buttons"] do
    style gap: 32, margin: [left: 6]
  end

  # One option: the row with the control and its label.
  component :radio do
    style gap: 18
    state :disabled, opacity: 0.5

    part :control,
      size: 12,
      radius: :full,
      outline: [width: 2, color: :grey3, offset: 4],
      transition: @motion do
      state :checked, background: :primary, outline: [color: :primary]
    end

    part :label, typography: :label, foreground: :grey1, margin: [top: 2]
  end

  component :select, web: [section: "Select"] do
    part :field, [height: 44, padding: [left: 12, right: 40]] ++ @field do
      state :focused, border: [color: :primary]
    end

    part :icon, inset: [right: 12]

    # The list opens 4px below the 44px field.
    part :listbox,
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

  # Drawn in its text color; without a variant, it takes the text color around it.
  component :spinner, web: [section: "Spinner"] do
    style size: 24, rotation: {1000, :linear}

    # Medium has no class.
    variants :size, default: :medium do
      variant :small, size: 16
      variant :large, size: 32
    end

    variant :accent, foreground: :primary, web: [doc: "Spinner colors"]
    # On a colored background.
    variant :inverse, foreground: :white
  end

  component :checkbox, web: [section: "Checkbox (bonus component)"] do
    style size: 20, border: [width: 2, color: :grey3], radius: 4, transition: @motion
    # The foreground is the check mark.
    state :checked, background: :primary, border: [color: :primary], foreground: :white
    state :disabled, opacity: 0.5
  end

  # Tags and message bars pair the subhead font (600) with the 14/16 text size, a
  # pair no typography token has; see ADR 0002.
  component :tag,
    web: [
      section: "Tags",
      doc: "Base tag styles - colored label with background opacity"
    ] do
    style radius: :default, background: :white

    part :label,
      radius: :default,
      padding: [y: 6, x: 12],
      typography: [font: :subhead, text: :tablehead]

    variants :tone, default: :accent do
      variant :accent, web: [doc: "Accent tag (default)"] do
        part :label, background: {:primary, 0.2}, foreground: :primary
      end

      variant :success, web: [doc: "Success tag"] do
        part :label, background: {:success, 0.2}, foreground: :success
      end

      variant :warning, web: [doc: "Warning tag"] do
        part :label, background: {:warning, 0.2}, foreground: :warning
      end

      variant :danger, web: [doc: "Danger tag"] do
        part :label, background: {:error, 0.2}, foreground: :error
      end

      # #666666 is no token.
      variant :neutral, web: [doc: "Neutral tag"] do
        part :label, background: {:grey2, 0.2}, foreground: "#666666"
      end
    end
  end

  component :message_bar, web: [section: "Message bars", doc: "Base message bar styles"] do
    style height: 40,
          padding: [y: 0, x: 16],
          radius: :default,
          typography: [font: :subhead, text: :tablehead]

    variants :tone, default: :info do
      variant :info,
        background: {:primary, 0.15},
        foreground: :primary,
        web: [doc: "Info message bar (default)"]

      variant :success,
        background: {:success, 0.15},
        foreground: :success,
        web: [doc: "Success message bar"]

      variant :warning,
        background: {:warning, 0.15},
        foreground: :warning,
        web: [doc: "Warning message bar"]

      variant :danger,
        background: {:error, 0.15},
        foreground: :error,
        web: [doc: "Danger message bar"]
    end
  end

  # The numbered circle of one step. 12/12 is no text size.
  component :step_indicator,
    web: [
      section: "Step indicators",
      doc: "Base step indicator - circular badge with number"
    ] do
    style size: 24, radius: :full, typography: [font: :label, text: {12, 12}]

    variants :status, default: :incomplete do
      variant :incomplete,
        background: :grey4,
        foreground: :grey2,
        web: [doc: "Incomplete step (default)"]

      variant :current, background: :primary, foreground: :white, web: [doc: "Current step"]

      variant :complete,
        background: :success,
        foreground: :white,
        web: [doc: "Complete step"]
    end
  end
end
