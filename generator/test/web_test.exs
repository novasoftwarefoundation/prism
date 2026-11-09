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

  # An app that gets the preset from a Mix dependency or a copy has no tailwindcss
  # next to it, and Node tools that load the app's Tailwind config (Prettier's
  # Tailwind plugin) require the preset from there: it needs nothing installed. Its
  # plugin is a bare function, which Tailwind calls with its API.
  test "the preset loads in plain Node with nothing installed next to it" do
    node =
      System.find_executable("node") || flunk("This test needs Node (.tool-versions: nodejs)")

    # Outside the project, so no node_modules in its parents. A random name that
    # mkdir! creates itself, so no folder planted there in advance is used.
    random = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
    dir = Path.join(System.tmp_dir!(), "prism-preset-#{random}")
    File.mkdir!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    # The preset is CommonJS, so a package.json in the temporary folder's parents
    # (one with "type": "module") doesn't decide how Node reads it.
    File.write!(Path.join(dir, "package.json"), "{}\n")
    preset = Path.join(dir, "tailwind.preset.js")
    File.write!(preset, bodies(Web.files(ExampleDesign.__schema__()))["tailwind.preset.js"])

    script = """
    const preset = require(process.argv[1]);
    const added = [];
    const add = (rules) => added.push(...Object.keys(rules));
    for (const plugin of preset.plugins) plugin({ addUtilities: add, addComponents: add });
    console.log(JSON.stringify(added));
    """

    {out, status} =
      System.cmd(node, ["-e", script, preset],
        env: [{"NODE_PATH", nil}],
        stderr_to_stdout: true
      )

    assert status == 0, out
    added = JSON.decode!(out)
    assert ".h-viewport" in added
    assert ".font-heading" in added
  end

  test "without docs and line clamps the files have no comment blocks or clamp classes" do
    design = ExampleDesign.__schema__()
    web = %{design.web | preset_doc: nil, base_doc: nil, font_classes_doc: nil, line_clamps: 0}
    files = bodies(Web.files(%{design | web: web}))

    assert files["tailwind.preset.js"] =~ ~r/\Amodule\.exports = \{/
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

  # The preset and base CSS keep their font and text classes; typography tokens reach
  # the web only through the components that use them.
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

  # A font names a weight, and the web writes the number of its family's web scale.
  test "a font's weight is its family's number on the web" do
    %{tokens: tokens} = design = ExampleDesign.__schema__()
    scale = [light: 200, regular: 500, heavy: 900]

    other =
      Enum.map(tokens, fn
        %{kind: :family, name: :text} = f -> %{f | web: Keyword.put(f.web, :scale, scale)}
        token -> token
      end)

    files = bodies(Web.files(%{design | tokens: other}))
    preset = files["tailwind.preset.js"]

    # The display family keeps its scale; the text family's fonts take the new one.
    assert preset =~
             ~s(".font-heading": {\n          "font-family": "Acme Display, serif",\n          "font-weight": "800",)

    assert preset =~
             ~s(".font-hint": {\n          "font-family": "Acme Text, sans-serif",\n          "font-weight": "200",)

    assert files["css/components.css"] =~
             ~s(font-family: "Acme Text", sans-serif;\n  font-weight: 500;)
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
