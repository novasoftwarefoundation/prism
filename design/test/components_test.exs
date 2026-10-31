defmodule Prism.Design.ComponentsTest do
  use ExUnit.Case, async: true

  @design Prism.Design.Components.__schema__()

  test "the design has 0.1.7's eleven components, under their new names, in 0.1.7's order" do
    assert Enum.map(@design.components, & &1.name) == [
             :button,
             :text_field,
             :text_area,
             :field,
             :radio_group,
             :radio,
             :select,
             :spinner,
             :checkbox,
             :tag,
             :message_bar,
             :step_indicator
           ]
  end

  test "the components are built on Prism's tokens" do
    assert @design.tokens == Prism.Design.Tokens.__schema__().tokens
    assert @design.tokens_file == "lib/tokens.ex"
    assert @design.file == "lib/components.ex"
    assert @design.web.prefix == "prism"
  end

  test "variants are on separate axes: variant, tone, size and status" do
    axes =
      Map.new(@design.components, fn c ->
        {c.name, c.variants |> Enum.group_by(& &1.axis, & &1.name) |> Enum.sort()}
      end)

    assert axes == %{
             button: [
               tone: [:success, :warning, :danger, :neutral, :highlight],
               variant: [:primary, :secondary, :plain, :link, :text, :soft, :icon]
             ],
             text_field: [variant: [:inverse]],
             text_area: [],
             field: [],
             radio_group: [],
             radio: [],
             select: [],
             spinner: [size: [16, 20, 32], variant: [:accent, :inverse]],
             checkbox: [],
             tag: [tone: [:accent, :success, :warning, :danger, :neutral]],
             message_bar: [tone: [:info, :success, :warning, :danger]],
             step_indicator: [status: [:incomplete, :current, :complete]]
           }
  end

  test "one tone vocabulary, and no aliases" do
    tones = [:accent, :neutral, :highlight, :info, :success, :warning, :danger]

    for c <- @design.components, v <- c.variants do
      if v.axis == :tone, do: assert(v.name in tones, "#{c.name}: tone #{v.name}")
      assert v.aliases == [], "#{c.name}.#{v.name} has aliases"
    end
  end

  test "a button with an icon is the icon part being there, not a variant" do
    button = Enum.find(@design.components, &(&1.name == :button))

    assert Enum.map(button.parts, &{&1.name, &1.component}) ==
             [label: nil, icon: nil, spinner: :spinner]

    assert for(v <- button.variants, w <- v.with_parts, do: {v.name, w.part}) ==
             [primary: :icon, secondary: :icon, plain: :icon, soft: :icon]
  end

  # A tone colors the background of a primary button, and the text (and the
  # border) of the others; a soft button gets the tone's light color behind it.
  test "every tone colors every variant that takes a color, by one rule" do
    button = Enum.find(@design.components, &(&1.name == :button))
    tone = &Enum.find(button.variants, fn v -> v.name == &1 end)

    colors = %{
      success: {:success, :white, :successlight},
      warning: {:warning, :white, :warninglight},
      danger: {:error, :white, :errorlight},
      neutral: {:grey1, :white, nil},
      highlight: {:tertiary, :grey1, nil}
    }

    for {name, {color, on, light}} <- colors do
      looks = Map.new(tone.(name).with_variants, &{&1.name, &1.style})
      assert looks[:primary] == [background: color, foreground: on], "#{name} on primary"

      assert looks[:secondary] == [foreground: color, border: [color: color]],
             "#{name} on secondary"

      for v <- [:plain, :link, :text],
          do: assert(looks[v] == [foreground: color], "#{name} on #{v}")

      if light,
        do: assert(looks[:soft] == [background: light, foreground: color], "#{name} on soft"),
        else: refute(Map.has_key?(looks, :soft), "#{name} has no light color")

      refute Map.has_key?(looks, :icon), "an icon button takes no tone"
    end
  end

  test "padded is on by default and lines a plain or text button up with a primary one" do
    button = Enum.find(@design.components, &(&1.name == :button))
    assert [%{name: :padded, default: true, style: [], with_variants: withs}] = button.flags
    assert Enum.map(withs, & &1.name) == [:plain, :text]
    primary = Enum.find(button.variants, &(&1.name == :primary))

    for w <- withs, do: assert(w.style == Keyword.take(primary.style, [:padding]))

    # Without padding, each keeps its 0.1.7 height and fits its text at the sides.
    unpadded =
      for v <- button.variants, v.name in [:plain, :text], do: {v.name, v.style[:padding]}

    assert unpadded == [plain: [y: 4, x: 0], text: [y: 1, x: 0]]
  end

  test "the icon is at the start of the label unless the app puts it at the end" do
    button = Enum.find(@design.components, &(&1.name == :button))
    assert Enum.find(button.parts, &(&1.name == :icon)).position == :start
  end

  # ADR 0007: sizes by their px, a progress value, and 20px in the button.
  test "the spinner's sizes are 16, 20, 24 and 32, its own 24" do
    spinner = Enum.find(@design.components, &(&1.name == :spinner))

    assert spinner.style[:size] == 24
    assert [%{name: :size, default: 24}] = spinner.axes

    assert for(%{axis: :size} = v <- spinner.variants, do: {v.name, v.style}) ==
             [{16, [size: 16]}, {20, [size: 20]}, {32, [size: 32]}]
  end

  test "with a progress value, a grey4 track and a 16% stroke; the button's spinner is 20px" do
    spinner = Enum.find(@design.components, &(&1.name == :spinner))

    assert [%{name: :progress, style: [stroke: {16, :percent}, track: :grey4]}] =
             spinner.values

    button = Enum.find(@design.components, &(&1.name == :button))
    assert Enum.find(button.parts, &(&1.name == :spinner)).variants == [size: 20]
  end

  test "the spinner's color is its foreground, a token" do
    spinner = Enum.find(@design.components, &(&1.name == :spinner))

    assert for(%{axis: :variant} = v <- spinner.variants, do: {v.name, {v.style, v.web}}) == [
             accent: {[foreground: :primary], [doc: "Spinner colors"]},
             inverse: {[foreground: :white], []}
           ]
  end

  # Apps import components.css into their own stylesheet, so a relative URL would
  # point into the app: every image is inline.
  test "the component CSS has no relative URL" do
    {_, css, _} =
      @design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)

    urls = Regex.scan(~r/url\(([^)]*)\)/, css, capture: :all_but_first)
    assert urls != []
    assert Enum.all?(urls, fn [url] -> String.starts_with?(url, ~s("data:)) end)
  end
end
