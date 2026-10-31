defmodule Prism.SchemaTest do
  use ExUnit.Case, async: true

  @family ~s(  family :f, "F", doc: "F", fallback: "serif", faces: [[file: "F", weights: {200, 900}, style: :normal]])

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
      @family <> ~s(\n  font :b, :f, 750),
      "weight 750 is not 100..1000",
      4
    )
  end

  test "a family needs a doc and a fallback" do
    assert_compile_error(
      ~s(  family :f, "F", fallback: "serif", faces: [[file: "F", weights: {200, 900}, style: :normal]]),
      "family :f: doc: must be a one-line string",
      3
    )

    assert_compile_error(
      ~s(  family :f, "F", doc: "F", fallback: 42, faces: [[file: "F", weights: {200, 900}, style: :normal]]),
      "family :f: fallback: must be a one-line string",
      3
    )
  end

  test "spec text can't break out of a JS or CSS string or comment" do
    assert_compile_error(
      ~s(  family :f, "F\\"oo", doc: "F", fallback: "serif", faces: [[file: "F", weights: {200, 900}, style: :normal]]),
      "the CSS name: must be a one-line string",
      3
    )

    assert_compile_error(
      ~s(  family :f, "F", doc: "F */ x", fallback: "serif", faces: [[file: "F", weights: {200, 900}, style: :normal]]),
      "doc: must be a one-line string",
      3
    )

    assert_compile_error(
      ~s|  family :f, "F", doc: "F", fallback: "serif", faces: [[file: "F\\")", weights: {200, 900}, style: :normal]]|,
      "file in A-Z a-z 0-9 . _ -",
      3
    )

    assert_compile_error(
      ~s|  group "Brand colors\\n  pwn: require(\\"child_process\\")," do\n    color :a, "#111111"\n  end|,
      "must be a one-line string",
      3
    )
  end

  test "groups don't nest" do
    assert_compile_error(
      ~s(  group "Outer" do\n    group "Inner" do\n      color :a, "#111111"\n    end\n  end),
      ~s(group "Inner" inside group "Outer": groups don't nest),
      4
    )
  end

  test "deprecated is a boolean" do
    assert_compile_error(
      ~s(  shadow :card, [y: 5, color: {:black, 0.1}], deprecated: "yes"),
      "deprecated is a boolean",
      3
    )
  end

  test "an option can't replace an argument or be given twice" do
    assert_compile_error(
      ~s(  shadow :card, [y: 5, color: {:black, 0.1}], value: [y: 9, color: {:black, 0.1}]),
      ":value is an argument, not an option",
      3
    )

    assert_compile_error(
      ~s(  shadow :card, [y: 5, color: {:black, 0.1}], deprecated: true, deprecated: false),
      "option :deprecated is given twice",
      3
    )

    assert_compile_error(
      @family <> ~s(\n  font :b, :f, 700, weight: 300),
      ":weight is an argument, not an option",
      4
    )
  end

  test "lengths that can't be negative" do
    assert_compile_error("  text :t, -16, 20", "greater than 0", 3)
    assert_compile_error("  radius :r, -4", "is not a length", 3)

    assert_compile_error(
      "  shadow :s, y: 5, blur: -20, color: {:black, 0.1}",
      "blur is not negative",
      3
    )
  end

  test "offsets and spread may be negative" do
    compile(
      ~s(  color :black, "#000000"\n  shadow :s, x: -2, y: -5, spread: -3, color: {:black, 0.1})
    )
  end
end
