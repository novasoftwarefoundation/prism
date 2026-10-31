defmodule Prism.Generator.SchemaTest do
  use ExUnit.Case, async: true

  @faces ~s([[file: "F", weights: {200, 900}, style: :normal]])

  # A one-line family :f; an option set to nil is left out.
  defp family(opts \\ []) do
    [
      doc: ~s("F"),
      web: ~s([name: "F", fallback: "serif", faces: #{@faces}]),
      ios: ":system",
      android: ":system"
    ]
    |> Keyword.merge(opts)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
    |> then(&"  family :f, #{&1}")
  end

  defp compile(body) do
    module = "Design#{System.unique_integer([:positive])}"

    Code.compile_string(
      "defmodule #{module} do\n  use Prism.Generator.Schema\n#{body}\nend\n",
      "design.ex"
    )
  end

  defp assert_compile_error(body, message, line) do
    error = assert_raise CompileError, fn -> compile(body) end
    assert Exception.message(error) =~ message
    assert error.line == line
  end

  test "the tokens compile into plain data" do
    %{tokens: tokens, web: web, file: file} = Prism.Generator.ExampleDesign.__schema__()
    assert file == "test/support/example_design.ex"
    assert %{kind: :color, name: :accent, value: "#1A73E8", group: "Brand"} in tokens
    assert %{kind: :color, name: :link, value: :accent, group: "Brand"} in tokens
    assert %{prefix: "acme", fonts_url: "../fonts", line_clamps: 2} = web
  end

  test "a name that isn't a snake_case atom fails" do
    assert_compile_error(~s(  color :Primary, "#1A73E8"), "name must be a snake_case atom", 3)
  end

  test "a duplicate fails at the second one" do
    assert_compile_error(
      ~s(  color :primary, "#1A73E8"\n  color :primary, "#1A73E8"),
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
    assert_compile_error(~s(  color :primary, "#1a73e8"), "write colors as #RRGGBB", 3)
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
    assert_compile_error("  font :button, :display, 700", "unknown family :display", 3)
  end

  test "a font weight is one of 100, 200, …, 1000" do
    compile(family() <> ~s(\n  font :b, :f, 100\n  font :c, :f, 1000))

    for weight <- [0, 450, 750, 1100] do
      assert_compile_error(
        family() <> ~s(\n  font :b, :f, #{weight}),
        "weight #{weight} is not one of 100, 200, …, 1000",
        4
      )
    end
  end

  test "a family needs a doc and a web fallback" do
    assert_compile_error(family(doc: nil), "family :f: doc: must be a one-line string", 3)

    assert_compile_error(
      family(web: ~s([name: "F", fallback: 42, faces: #{@faces}])),
      "family :f: web: fallback: must be a CSS family name",
      3
    )
  end

  test "a family names every platform" do
    compile(family())

    for platform <- [:web, :ios, :android] do
      assert_compile_error(
        family([{platform, nil}]),
        "family :f: missing #{platform}: (every family names web, ios, android)",
        3
      )
    end

    assert_compile_error(family(windows: ":system"), "unknown option :windows", 3)
  end

  test "a platform binds :system or a named font with its faces" do
    compile(
      family(
        ios: ~s([name: "Brand", faces: #{@faces}]),
        android: ~s([name: "Brand", faces: #{@faces}])
      )
    )

    assert_compile_error(
      family(ios: ~s("SF Pro")),
      "family :f: ios: is :system or [name:, faces: [...]]",
      3
    )

    assert_compile_error(
      family(android: ~s([name: "Brand"])),
      "family :f: android: is :system or",
      3
    )

    assert_compile_error(
      family(ios: ~s([name: "Brand", fallback: "serif", faces: #{@faces}])),
      "family :f: ios: is :system or",
      3
    )

    assert_compile_error(
      family(ios: ~s([name: "Brand", faces: []])),
      "family :f: ios: a face is",
      3
    )

    assert_compile_error(
      family(web: ":system"),
      "web: :system is not supported on the web yet",
      3
    )
  end

  test "design text can't break out of a JS or CSS string or comment" do
    assert_compile_error(
      family(web: ~s([name: "F\\"oo", fallback: "serif", faces: #{@faces}])),
      "web: name: must be a CSS family name",
      3
    )

    assert_compile_error(family(doc: ~s("F */ x")), "doc: must be a one-line string", 3)

    assert_compile_error(
      family(
        web:
          ~s|[name: "F", fallback: "serif", faces: [[file: "F\\")", weights: {200, 900}, style: :normal]]]|
      ),
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
      family() <> ~s(\n  font :b, :f, 700, weight: 300),
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

  test "font names and fallbacks are plain CSS family names" do
    assert_compile_error(
      family(
        web:
          ~s([name: "F", fallback: "sans-serif; color: red } body { display: none", faces: #{@faces}])
      ),
      "web: fallback: must be a CSS family name",
      3
    )

    assert_compile_error(
      family(web: ~s([name: "F", fallback: "", faces: #{@faces}])),
      "web: fallback: must be a CSS family name",
      3
    )

    assert_compile_error(
      family(ios: ~s([name: "Brand;", faces: #{@faces}])),
      "ios: name: must be a CSS family name",
      3
    )
  end

  test "a trailing newline doesn't pass a name, color or file check" do
    assert_compile_error(~s(  color :primary, "#1A73E8\\n"), "write colors as #RRGGBB", 3)

    assert_compile_error(
      ~s(  color :"primary\\n", "#1A73E8"),
      "name must be a snake_case atom",
      3
    )

    assert_compile_error(
      family(
        web:
          ~s([name: "F", fallback: "serif", faces: [[file: "F\\n", weights: {200, 900}, style: :normal]]])
      ),
      "file in A-Z a-z 0-9 . _ -",
      3
    )
  end

  test "face weights are 1..1000, lowest first" do
    for weights <- ["{0, 900}", "{200, 5000}", "{900, 200}"] do
      assert_compile_error(
        family(
          web:
            ~s([name: "F", fallback: "serif", faces: [[file: "F", weights: #{weights}, style: :normal]]])
        ),
        "web: weights: {from, to} with 1 <= from <= to <= 1000",
        3
      )
    end
  end

  test "the web declaration is checked" do
    compile(~s(  web prefix: "acme", fonts_url: "../fonts"))

    assert_compile_error(
      ~s(  web prefix: "acme", fonts_url: "../fonts"\n  web prefix: "acme", fonts_url: "../fonts"),
      "web is declared more than once",
      3
    )

    assert_compile_error(
      ~s(  web prefix: "acme", fonts_url: "f", colour: 1),
      "unknown option :colour",
      3
    )

    assert_compile_error(
      ~s(  web fonts_url: "../fonts"),
      "prefix must be a lower-case CSS class prefix",
      3
    )

    assert_compile_error(~s(  web prefix: "Acme {", fonts_url: "f"), "prefix must be", 3)

    assert_compile_error(
      ~s|  web prefix: "acme", fonts_url: "f\\"), x"|,
      "fonts_url must be a relative path",
      3
    )

    for url <- ["/fonts", "//fonts.example/x"] do
      assert_compile_error(
        ~s(  web prefix: "acme", fonts_url: "#{url}"),
        "fonts_url must be a relative path (no leading /)",
        3
      )
    end

    assert_compile_error(
      ~s(  web prefix: "acme", fonts_url: "f", base_doc: "a */ b"),
      "base_doc must be text without */",
      3
    )

    assert_compile_error(
      ~s(  web prefix: "acme", fonts_url: "f", font_classes_doc: "a\\nb"),
      "font_classes_doc must be one line",
      3
    )

    assert_compile_error(
      ~s(  web prefix: "acme", fonts_url: "f", line_clamps: -1),
      "line_clamps must be a number >= 0",
      3
    )
  end
end
