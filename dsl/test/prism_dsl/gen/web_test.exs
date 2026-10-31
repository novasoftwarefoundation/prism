defmodule PrismDsl.Gen.WebTest do
  use ExUnit.Case, async: true

  alias PrismDsl.{FixtureSpec, Gen.Web}

  # The fixture spec's output, reviewed and kept in test/fixtures/web. A change
  # to what the generator writes fails here until the snapshot is updated.
  test "the output for the fixture spec equals the snapshot" do
    for {path, source} <- Web.generate(FixtureSpec.__schema__()) do
      [header, _] = String.split(source, "\n", parts: 2)
      assert header == Web.header(path)

      assert source == File.read!("test/fixtures/web/#{path}"),
             "#{path} differs from the snapshot"
    end
  end

  test "without docs and line clamps the output has no comment blocks or clamp classes" do
    spec = FixtureSpec.__schema__()
    web = %{spec.web | preset_doc: nil, base_doc: nil, font_classes_doc: nil, line_clamps: 0}
    files = Map.new(Web.generate(%{spec | web: web}))

    assert files["tailwind.preset.js"] =~ ~r/\A[^\n]*\nconst plugin/
    assert files["tailwind.preset.js"] =~ "      });\n\n      addComponents({"
    assert files["css/base.css"] =~ ~r/\A[^\n]*\n\/\* =====/
    refute files["css/base.css"] =~ "max-lines"

    assert files["css/base.css"] =~
             "   ========================================================================== */\n\n/* Text shadows */"
  end

  test "a spec without a web declaration can't generate web output" do
    assert_raise ArgumentError, ~r/no `web` declaration/, fn ->
      Web.generate(%{FixtureSpec.__schema__() | web: nil})
    end
  end

  test "a new token reaches the output" do
    %{tokens: tokens} = spec = FixtureSpec.__schema__()

    extra = [
      %{kind: :color, name: :mark, value: "#123456", group: "Extra"},
      %{kind: :text_shadow, name: :xl, value: [y: 12, blur: 24, color: {:ink, 0.3}], group: nil}
    ]

    files = Map.new(Web.generate(%{spec | tokens: tokens ++ extra}))

    assert files["tailwind.preset.js"] =~ ~s(      // Extra\n      mark: "#123456",\n)

    assert files["css/base.css"] =~
             ".acme-text-shadow-xl {\n  text-shadow: 0px 12px 24px rgba(16, 16, 16, 0.3);\n}"
  end

  test "strings are escaped in JS and CSS, and text that can't be a comment fails" do
    %{tokens: tokens} = spec = FixtureSpec.__schema__()

    tokens =
      Enum.map(tokens, fn
        %{kind: :family, name: :display} = family ->
          %{family | web: Keyword.put(family.web, :name, ~S(Ac"me\D))}

        token ->
          token
      end)

    files = Map.new(Web.generate(%{spec | tokens: tokens}))

    assert files["tailwind.preset.js"] =~ ~S(heading: ["Ac\"me\\D", "serif"],)
    assert files["css/base.css"] =~ ~S(font-family: "Ac\"me\\D";)

    group = %{hd(tokens) | group: "Brand\n      pwn: 1,"}

    assert_raise ArgumentError, ~r/can't be written in a comment/, fn ->
      Web.generate(%{spec | tokens: [group | tl(tokens)]})
    end
  end

  test "the web output reads only the web binding of a family" do
    %{tokens: tokens} = spec = FixtureSpec.__schema__()
    brand = [name: "Brand", faces: [[file: "Brand", weights: {400, 700}, style: :normal]]]

    native =
      Enum.map(tokens, fn
        %{kind: :family} = family -> %{family | ios: brand, android: brand}
        token -> token
      end)

    assert Web.generate(%{spec | tokens: native}) == Web.generate(spec)
  end
end
