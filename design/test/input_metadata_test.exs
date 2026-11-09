defmodule Prism.Design.InputMetadataTest do
  use ExUnit.Case, async: true
  alias Prism.Generator.InputMetadata

  test "text inputs declare the exact debounce contract, disabled by default" do
    design = Prism.Design.Components.__schema__()

    for name <- [:text_field, :text_area] do
      component = Enum.find(design.components, &(&1.name == name))

      assert component.input_properties == [
               %{
                 name: :debounce_ms,
                 type: :integer,
                 unit: :millisecond,
                 min: 1,
                 max: 2_147_483_647,
                 default: nil
               }
             ]

      assert InputMetadata.validate!(design, name, %{}) == %{debounce_ms: nil}

      assert InputMetadata.validate!(design, name, %{debounce_ms: nil}) ==
               %{debounce_ms: nil}

      for value <- [1, 500, 2_147_483_647] do
        assert InputMetadata.validate!(design, name, %{debounce_ms: value}) ==
                 %{debounce_ms: value}
      end

      for value <- [0, -1, 2_147_483_648, 1.5, 1.0, true, false, "500"] do
        assert_raise ArgumentError, fn ->
          InputMetadata.validate!(design, name, %{debounce_ms: value})
        end
      end
    end
  end
end
