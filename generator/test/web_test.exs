defmodule Prism.Generator.WebTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{ExampleDesign, Web}

  defp bodies(files), do: Map.new(files, fn {path, body, _from} -> {path, body} end)

  # The example design's files, reviewed and kept in test/fixtures/web (as
  # `mix prism.gen` writes them, header included). A change to what the
  # generator writes fails here until the fixtures are updated.
  test "the files for the example design equal the fixtures" do
    for {path, body, _from} <- Web.files(ExampleDesign.__schema__()) do
      [_header, fixture] = String.split(File.read!("test/fixtures/web/#{path}"), "\n", parts: 2)
      assert body == fixture, "#{path} differs from test/fixtures/web/#{path}"
    end
  end

  test "without docs and line clamps the files have no comment blocks or clamp classes" do
    design = ExampleDesign.__schema__()
    web = %{design.web | preset_doc: nil, base_doc: nil, font_classes_doc: nil, line_clamps: 0}
    files = bodies(Web.files(%{design | web: web}))

    assert files["tailwind.preset.js"] =~ ~r/\Aconst plugin/
    assert files["tailwind.preset.js"] =~ "      });\n\n      addComponents({"
    assert files["css/base.css"] =~ ~r/\A\/\* =====/
    refute files["css/base.css"] =~ "max-lines"

    assert files["css/base.css"] =~
             "   ========================================================================== */\n\n/* Text shadows */"
  end

  test "each file names the design file it is made from" do
    design = %{ExampleDesign.__schema__() | tokens_file: "lib/tokens.ex"}

    assert for({path, _, from} <- Web.files(design), do: {path, from}) == [
             {"tailwind.preset.js", "lib/tokens.ex"},
             {"css/base.css", "lib/tokens.ex"},
             {"css/components.css", "test/support/example_design.ex"}
           ]
  end

  test "a design without components has no components.css" do
    design = %{ExampleDesign.__schema__() | components: []}
    assert Enum.map(Web.files(design), &elem(&1, 0)) == ["tailwind.preset.js", "css/base.css"]
  end

  test "a design without a web declaration can't generate web files" do
    assert_raise ArgumentError, ~r/no `web` declaration/, fn ->
      Web.files(%{ExampleDesign.__schema__() | web: nil})
    end
  end

  # The preset and base CSS keep their font and text classes; type styles reach the
  # web only through the components that use them.
  test "typography tokens don't change the preset or the base CSS" do
    %{tokens: tokens} = design = %{ExampleDesign.__schema__() | components: []}
    assert Enum.any?(tokens, &(&1.kind == :typography))
    without = Enum.reject(tokens, &(&1.kind == :typography))
    assert Web.files(design) == Web.files(%{design | tokens: without})
  end

  test "a new token reaches the files" do
    %{tokens: tokens} = design = ExampleDesign.__schema__()

    extra = [
      %{kind: :color, name: :mark, value: "#123456", group: "Extra"},
      %{kind: :text_shadow, name: :xl, value: [y: 12, blur: 24, color: {:ink, 0.3}], group: nil}
    ]

    files = bodies(Web.files(%{design | tokens: tokens ++ extra}))

    assert files["tailwind.preset.js"] =~ ~s(      // Extra\n      mark: "#123456",\n)

    assert files["css/base.css"] =~
             ".acme-text-shadow-xl {\n  text-shadow: 0px 12px 24px rgba(16, 16, 16, 0.3);\n}"
  end

  test "strings are escaped in JS and CSS, and text that can't be a comment fails" do
    %{tokens: tokens} = design = ExampleDesign.__schema__()

    tokens =
      Enum.map(tokens, fn
        %{kind: :family, name: :display} = family ->
          %{family | web: Keyword.put(family.web, :name, ~S(Ac"me\D))}

        token ->
          token
      end)

    files = bodies(Web.files(%{design | tokens: tokens}))

    assert files["tailwind.preset.js"] =~ ~S(heading: ["Ac\"me\\D", "serif"],)
    assert files["css/base.css"] =~ ~S(font-family: "Ac\"me\\D";)

    group = %{hd(tokens) | group: "Brand\n      pwn: 1,"}

    assert_raise ArgumentError, ~r/can't be written in a comment/, fn ->
      Web.files(%{design | tokens: [group | tl(tokens)]})
    end
  end

  test "the web target reads only the web binding of a family" do
    %{tokens: tokens} = design = ExampleDesign.__schema__()
    brand = [name: "Brand", faces: [[file: "Brand", weights: {400, 700}, style: :normal]]]

    native =
      Enum.map(tokens, fn
        %{kind: :family} = family -> %{family | ios: brand, android: brand}
        token -> token
      end)

    assert Web.files(%{design | tokens: native}) == Web.files(design)
  end
end
