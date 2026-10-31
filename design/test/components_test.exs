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
               tone: [:success, :warning, :danger],
               variant: [:primary, :secondary, :plain, :link, :text]
             ],
             text_field: [variant: [:inverse]],
             text_area: [],
             field: [],
             radio_group: [],
             radio: [],
             select: [],
             spinner: [size: [:small, :large], variant: [:accent, :inverse]],
             checkbox: [],
             tag: [tone: [:accent, :success, :warning, :danger, :neutral]],
             message_bar: [tone: [:info, :success, :warning, :danger]],
             step_indicator: [status: [:incomplete, :current, :complete]]
           }
  end

  test "one tone vocabulary, and no aliases" do
    tones = [:accent, :neutral, :info, :success, :warning, :danger]

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
             [primary: :icon, secondary: :icon, plain: :icon]
  end

  test "the spinner's color is its foreground, a token" do
    spinner = Enum.find(@design.components, &(&1.name == :spinner))

    assert for(%{axis: :variant} = v <- spinner.variants, do: {v.name, {v.style, v.web}}) == [
             accent: {[foreground: :primary], [doc: "Spinner colors"]},
             inverse: {[foreground: :white], []}
           ]
  end
end
