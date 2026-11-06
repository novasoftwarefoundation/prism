defmodule Prism.Generator.InputMetadataTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{ExampleComponents, InputMetadata}

  test "Swift keyword property names remain valid identifiers" do
    design = ExampleComponents.__schema__()
    [component] = InputMetadata.components(design)
    property = %{hd(component.input_properties) | name: :default}
    component = %{component | input_properties: [property]}
    [{_, source}] = InputMetadata.swift_files(%{design | components: [component]}, "Kit")
    assert source =~ "public let `default`: Int?"
    assert source =~ "public init(`default`: Int? = nil)"
    assert source =~ "case `default` = \"default\""
    assert source =~ "forKey: .`default`"
  end

  test "missing and nil disable; integer boundaries are inclusive" do
    design = ExampleComponents.__schema__()
    assert InputMetadata.validate!(design, :text_field, %{}) == %{settle_ms: nil}
    assert InputMetadata.validate!(design, :text_field, %{settle_ms: nil}) == %{settle_ms: nil}

    for value <- [1, 500, 1000] do
      assert InputMetadata.validate!(design, :text_field, %{settle_ms: value}) ==
               %{settle_ms: value}
    end
  end

  test "invalid values fail rather than coercing or clamping" do
    for value <- [0, -1, 1001, 1.5, 1.0, true, false, "500", [], %{}] do
      assert_raise ArgumentError, ~r/settle_ms/, fn ->
        InputMetadata.validate!(ExampleComponents.__schema__(), :text_field, %{settle_ms: value})
      end
    end
  end

  test "unknown properties, components and non-map metadata fail" do
    for {component, metadata} <- [text_field: %{typo: 10}, typo: %{}, text_field: nil] do
      assert_raise ArgumentError, fn ->
        InputMetadata.validate!(ExampleComponents.__schema__(), component, metadata)
      end
    end
  end
end
