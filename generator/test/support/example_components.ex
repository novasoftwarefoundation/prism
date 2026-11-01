defmodule Prism.Generator.ExampleComponents do
  @moduledoc false
  # A small, neutral design with one component of every kind the targets know,
  # for the Phoenix target's tests: every axis has a default of each sort (one of
  # its variants, a name without a class, none), and every part and state of a
  # kind is there.
  use Prism.Generator.Schema

  web prefix: "kit", fonts_url: "../fonts"

  color :accent, "#1A73E8"
  color :ink, "#101010"
  color :paper, "#FDFDFD"
  color :alarm, "#C62828"

  shadow :pressed, inset: true, y: 2, color: {:ink, 0.2}
  radius :default, 4

  family :text,
    doc: "Text",
    web: [
      name: "Kit Sans",
      fallback: "sans-serif",
      faces: [[file: "KitSans", weights: {100, 900}, style: :normal]]
    ],
    ios: :system,
    android: :system

  font :body, :text, 400
  text :body, 16, 24
  typography(:body, font: :body, text: :body)

  # The default of the :variant axis is one of its variants; the tone's default
  # is a name without a class.
  # The app picks the icon's side of the label; a variant has a part's name; the
  # tone's looks are with variants; one flag is on by default and has looks only
  # with a variant, the other has a look of its own. The spinner part picks the
  # spinner's 16.
  component :button, default: :primary do
    style typography: :body, radius: :default
    part :label
    part :icon, position: :start
    part :spinner, component: :spinner, variants: [size: 16]

    variant :primary, background: :accent, foreground: :paper do
      state :pressed, shadow: :pressed
      state :disabled, opacity: 0.5
      with_part :icon, gap: 8
    end

    variant :quiet, foreground: :accent, aliases: [:subtle]

    variant :icon, size: 24 do
      state :pressed, opacity: 0.8
    end

    state :loading do
      part :label, opacity: 0
    end

    variants :tone, default: :accent do
      variant :danger do
        with_variant(:primary, background: :alarm)

        with_variant :quiet, foreground: :alarm do
          state :hovered, foreground: :ink
        end
      end
    end

    flag :roomy, default: true do
      with_variant(:quiet, padding: [y: 8, x: 12])
    end

    flag(:strong, weight: 400)
  end

  component :text_field do
    style height: 40, border: [width: 1, color: :ink]
    state :focused, border: [color: :accent]
    state :disabled, opacity: 0.5
    state :invalid, border: [color: :alarm]
    variant :inverse, foreground: :paper
  end

  component :text_area do
    style min_height: 80
    state :focused, border: [color: :accent]
  end

  component :field do
    part :label, foreground: :ink
    part :error_message, foreground: :alarm
  end

  component :radio_group do
    style gap: 16
  end

  component :radio do
    style gap: 8
    state :disabled, opacity: 0.5

    part :control, size: 12 do
      state :checked, background: :accent
    end

    part :label, foreground: :ink
  end

  component :select do
    part :field, height: 40 do
      state :focused, border: [color: :accent]
    end

    part :icon, inset: [right: 8]
    part :listbox, inset: [top: 44], background: :paper

    part :option, height: 32 do
      state :hovered, background: {:accent, 0.1}
      state :selected, foreground: :accent
    end
  end

  # No default color: it takes the text color around it. Its sizes are named by
  # their px; 24 is its own. With a progress value, a ring with a faint track,
  # which the inverse variant makes light.
  component :spinner do
    style size: 24, rotation: {1000, :linear}

    variants :size, default: 24 do
      variant 16, size: 16
      variant 32, size: 32
    end

    variant :accent, foreground: :accent

    # On a dark background, a light track.
    variant :inverse, foreground: :paper do
      value :progress, track: {:paper, 0.3}
    end

    value :progress, stroke: {12, :percent}, track: {:ink, 0.1}
  end

  component :checkbox do
    style size: 16
    state :checked, background: :accent, foreground: :paper
    state :disabled, opacity: 0.5
  end

  component :tag do
    style radius: :default
    part :label, padding: [y: 2, x: 8]

    variants :tone, default: :neutral do
      variant :neutral do
        part :label, foreground: :ink
      end

      variant :accent do
        part :label, foreground: :accent
      end
    end
  end

  component :message_bar do
    style height: 40

    variants :tone, default: :info do
      variant :info, background: {:accent, 0.15}
      variant :danger, background: {:alarm, 0.15}
    end
  end

  # No default: a step has a status only when the app gives one.
  component :step_indicator do
    style size: 24

    variants :status do
      variant :current, background: :accent
    end
  end
end
