defmodule Prism.SchemaTest do
  use ExUnit.Case, async: true

  defp compile(body) do
    module = "Spec#{System.unique_integer([:positive])}"
    Code.compile_string("defmodule #{module} do\n  use Prism.Schema\n#{body}\nend\n", "spec.ex")
  end

  defp assert_compile_error(body, message, line) do
    error = assert_raise CompileError, fn -> compile(body) end
    assert Exception.message(error) =~ message
    assert error.line == line
  end

  test "the tokens compile into plain data" do
    tokens = Prism.Tokens.__schema__().tokens
    assert %{kind: :color, name: :primary, value: "#4272EF", group: "Brand colors"} in tokens
    assert %{kind: :color, name: :delete, value: :error, group: "Status colors"} in tokens
  end

  test "a name that isn't a snake_case atom fails" do
    assert_compile_error(~s(  color :Primary, "#4272EF"), "name must be a snake_case atom", 3)
  end

  test "a duplicate fails at the second one" do
    assert_compile_error(
      ~s(  color :primary, "#4272EF"\n  color :primary, "#4272EF"),
      "color :primary is defined twice",
      4
    )
  end

  test "an unknown option fails and names it" do
    assert_compile_error(
      ~s(  shadow :card, [y: 5, color: {:black, 0.1}], deprecatd: true),
      "unknown option :deprecatd",
      3
    )
  end

  test "colors are upper-case #RRGGBB" do
    assert_compile_error(~s(  color :primary, "#4272ef"), "write colors as #RRGGBB", 3)
  end

  test "an alias of an unknown color fails" do
    assert_compile_error("  color :x, :nope", "alias of unknown color :nope", 3)
  end

  test "a shadow color must be a color" do
    assert_compile_error(
      "  shadow :card, y: 5, color: {:ink, 0.1}",
      "shadow color :ink is not a color",
      3
    )
  end

  test "a font of an unknown family fails" do
    assert_compile_error("  font :button, :nunito, 700", "unknown family :nunito", 3)
  end

  test "a weight must be 100..1000" do
    assert_compile_error(
      ~s(  family :f, "F", faces: [[file: "F", weights: {200, 900}, style: :normal]]\n  font :b, :f, 750),
      "weight 750 is not 100..1000",
      4
    )
  end
end
