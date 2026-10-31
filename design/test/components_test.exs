defmodule Prism.Design.ComponentsTest do
  use ExUnit.Case, async: true

  @design Prism.Design.Components.__schema__()

  test "the design has 0.1.7's eleven components, in its order" do
    assert Enum.map(@design.components, & &1.name) == [
             :btn,
             :input,
             :textarea,
             :label,
             :radio,
             :dropdown,
             :spinner,
             :checkbox,
             :tag,
             :alert,
             :number_icon
           ]
  end

  test "the components are built on Prism's tokens" do
    assert @design.tokens == Prism.Design.Tokens.__schema__().tokens
    assert @design.tokens_file == "lib/tokens.ex"
    assert @design.file == "lib/components.ex"
    assert @design.web.prefix == "prism"
  end

  # The golden test compares the whole file; this names a class that went missing.
  test "every class of 0.1.7's components.css is generated" do
    classes = fn css ->
      ~r/\.(prism-[a-z0-9-]+)/ |> Regex.scan(css) |> MapSet.new(fn [_, class] -> class end)
    end

    {_, generated, _} =
      @design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)

    golden = classes.(File.read!("test/golden/0.1.7/css/components.css"))
    assert MapSet.size(golden) > 50
    assert MapSet.difference(golden, classes.(generated)) == MapSet.new()
  end

  test "the button's variants are two axes: a variant and a color" do
    button = Enum.find(@design.components, &(&1.name == :btn))
    axes = Enum.group_by(button.variants, & &1.axis, & &1.name)

    assert axes == %{
             variant: [
               :primary,
               :primary_icon,
               :secondary,
               :secondary_icon,
               :plain,
               :plain_icon,
               :link,
               :label
             ],
             color: [:success, :warning, :danger]
           }

    assert Enum.find(button.variants, &(&1.name == :danger)).aliases == [:delete]
    assert Enum.map(button.parts, &{&1.name, &1.component}) == [content: nil, spinner: :spinner]
  end
end
