defmodule Prism.Generator.DesignToolsTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{DesignTools, ExampleComponents, ExampleDesign, Header}

  defp bodies(design), do: Map.new(DesignTools.files(design), fn {p, b, _} -> {p, b} end)

  # The example design's files, reviewed and kept in test/fixtures/design_tools as
  # `mix prism.gen` writes them, header included. Their own checks (`npm test` in
  # targets/design-tools) validate the fixtures as DTCG, CSS and SVG too.
  test "the files for the example design equal the fixtures" do
    for {path, body, from} <- DesignTools.files(ExampleDesign.__schema__()) do
      assert Header.put(path, from, body) == File.read!("test/fixtures/design_tools/#{path}"),
             "#{path} differs from test/fixtures/design_tools/#{path}"
    end
  end

  test "the token files come from the tokens' file, the overview from the design's" do
    design = %{ExampleDesign.__schema__() | tokens_file: "lib/tokens.ex"}

    assert for({path, _, from} <- DesignTools.files(design), do: {path, from}) == [
             {"tokens.json", "lib/tokens.ex"},
             {"tokens.css", "lib/tokens.ex"},
             {"overview.svg", "test/support/example_design.ex"}
           ]
  end

  # The paths of tokens.json, as `group.name`, and the custom properties of tokens.css.
  defp json_paths(json) do
    for {group, tokens} <- JSON.decode!(json),
        is_map(tokens),
        name <- Map.keys(tokens),
        do: "#{group}.#{name}"
  end

  defp css_names(css), do: for([_, name] <- Regex.scan(~r/^  (--[\w-]+):/m, css), do: name)

  test "both token files name every token by one rule: the path, joined by - after the prefix" do
    files = bodies(ExampleDesign.__schema__())

    names =
      Enum.map(json_paths(files["tokens.json"]), &("--acme-" <> String.replace(&1, ".", "-")))

    assert Enum.sort(names) == Enum.sort(css_names(files["tokens.css"]))

    for kind <- [:color, :shadow, :text_shadow, :space, :height, :max_height, :radius, :family],
        do: assert(Enum.any?(ExampleDesign.__schema__().tokens, &(&1.kind == kind)))

    assert Enum.sort(json_paths(files["tokens.json"])) ==
             Enum.sort(~w(
               color.accent color.link color.ink color.paper
               font-family.display font-family.text
               font-weight.heading font-weight.body font-weight.hint
               font-size.heading font-size.body line-height.heading line-height.body
               typography.heading typography.body typography.note
               spacing.2px spacing.4px spacing.8px spacing.10 height.36px max-height.menu
               radius.default
               shadow.pressed shadow.card shadow.raised text-shadow.default text-shadow.strong
             ))
  end

  test "values are DTCG 2025.10 objects; an alias is a reference" do
    json = JSON.decode!(bodies(ExampleDesign.__schema__())["tokens.json"])

    assert json["color"]["accent"] == %{
             "$type" => "color",
             "$value" => %{
               "colorSpace" => "srgb",
               "components" => [0.102, 0.451, 0.9098],
               "alpha" => 1,
               "hex" => "#1A73E8"
             }
           }

    assert json["color"]["link"] == %{"$type" => "color", "$value" => "{color.accent}"}

    assert json["spacing"]["10"]["$value"] == %{"value" => 40, "unit" => "px"}

    assert json["shadow"]["pressed"]["$value"] == %{
             "color" => %{
               "colorSpace" => "srgb",
               "components" => [0.0627, 0.0627, 0.0627],
               "alpha" => 0.2,
               "hex" => "#101010"
             },
             "offsetX" => %{"value" => 0, "unit" => "px"},
             "offsetY" => %{"value" => 3, "unit" => "px"},
             "blur" => %{"value" => 0, "unit" => "px"},
             "spread" => %{"value" => 0, "unit" => "px"},
             "inset" => true
           }

    assert json["shadow"]["raised"] == %{
             "$type" => "shadow",
             "$value" => "{shadow.card}",
             "$deprecated" => true
           }

    # A text shadow is a shadow without a spread.
    assert json["text-shadow"]["default"]["$value"]["spread"] == %{"value" => 0, "unit" => "px"}
  end

  test "a typography token refers to its family, weight and size; its line height is a multiple" do
    json = JSON.decode!(bodies(ExampleDesign.__schema__())["tokens.json"])

    assert json["typography"]["heading"]["$value"] == %{
             "fontFamily" => "{font-family.display}",
             "fontSize" => "{font-size.heading}",
             "fontWeight" => "{font-weight.heading}",
             "letterSpacing" => %{"value" => 0, "unit" => "px"},
             "lineHeight" => 1.25
           }

    # DTCG's typography has no font style: an italic font says so under $extensions.
    assert json["typography"]["note"]["$extensions"] == %{"prism" => %{"fontStyle" => "italic"}}

    assert json["font-weight"]["hint"]["$extensions"] == %{
             "prism" => %{"family" => "{font-family.text}", "italic" => true}
           }

    css = bodies(ExampleDesign.__schema__())["tokens.css"]

    assert css =~
             "  --acme-typography-note: italic var(--acme-font-weight-hint) var(--acme-font-size-body)/var(--acme-line-height-body) var(--acme-font-family-text);\n"
  end

  test "a family is the web font, with its fallback and native bindings under $extensions" do
    json = JSON.decode!(bodies(ExampleDesign.__schema__())["tokens.json"])

    assert json["font-family"]["text"] == %{
             "$type" => "fontFamily",
             "$value" => "Acme Text",
             "$description" => "Body text",
             "$extensions" => %{
               "prism" => %{
                 "fallback" => "sans-serif",
                 "ios" => "system",
                 "android" => %{"name" => "Acme Text"}
               }
             }
           }

    assert bodies(ExampleDesign.__schema__())["tokens.css"] =~
             ~s(  --acme-font-family-text: "Acme Text", sans-serif;\n)
  end

  test "a length in percent or rem: rem in both files, percent only in the CSS" do
    %{tokens: tokens} = design = ExampleDesign.__schema__()

    extra = [
      %{kind: :radius, name: :round, value: {50, :percent}, group: nil},
      %{kind: :radius, name: :soft, value: {0.5, :rem}, group: nil}
    ]

    files = bodies(%{design | tokens: tokens ++ extra})
    json = JSON.decode!(files["tokens.json"])

    assert json["radius"]["soft"]["$value"] == %{"value" => 0.5, "unit" => "rem"}
    refute Map.has_key?(json["radius"], "round")
    assert files["tokens.css"] =~ "  --acme-radius-round: 50%;\n  --acme-radius-soft: 0.5rem;\n"
  end

  test "two tokens with one CSS name fail" do
    tokens = ExampleDesign.__schema__().tokens
    same = %{kind: :height, key: "36px", name: :again, value: 36, group: nil}

    assert_raise ArgumentError,
                 ~r/height.36px and height.36px have one CSS name, height-36px/,
                 fn ->
                   DesignTools.tokens(tokens ++ [same])
                 end
  end

  test "a design without a web declaration can't name its tokens" do
    assert_raise ArgumentError, ~r/no `web` declaration/, fn ->
      DesignTools.files(%{ExampleDesign.__schema__() | web: nil})
    end
  end

  test "a design without tokens writes valid files, the JSON an object of its header" do
    [{mod, _}] =
      Code.compile_string(~s"""
      defmodule NoTokens#{System.unique_integer([:positive])} do
        use Prism.Generator.Schema
        web prefix: "none", fonts_url: "../fonts"
      end
      """)

    files =
      for {path, body, _} <- DesignTools.files(mod.__schema__()),
          into: %{},
          do: {path, Header.put(path, "a.ex", body)}

    assert %{"$description" => "Generated by prism" <> _} =
             json = JSON.decode!(files["tokens.json"])

    assert map_size(json) == 1
    assert files["tokens.css"] =~ ":root {\n}\n"
    assert files["overview.svg"] =~ "</svg>\n"
  end

  describe "overview.svg" do
    defp svg(design), do: bodies(design)["overview.svg"]

    test "is standalone: no external references, no scripts, styles or images" do
      for svg <- [svg(ExampleDesign.__schema__()), svg(ExampleComponents.__schema__())] do
        refute svg =~ ~r/href|<image|<style|<script|<foreignObject|@import/
        urls = for [_, url] <- Regex.scan(~r/url\(([^)]*)\)/, svg), uniq: true, do: url
        assert Enum.all?(urls, &String.starts_with?(&1, "#"))

        for "#" <> id <- urls, do: assert(svg =~ ~s(<filter id="#{id}"))
      end
    end

    test "text is plain <text> in the web fonts' names, without fallbacks" do
      svg = svg(ExampleDesign.__schema__())
      families = for [_, f] <- Regex.scan(~r/font-family="([^"]*)"/, svg), uniq: true, do: f

      assert Enum.sort(families) == ["Acme Display", "Acme Text"]
      assert svg =~ ~s(font-family="Acme Display" font-size="32" font-weight="800")
      assert svg =~ ~s(font-style="italic")
      refute svg =~ "<path"
    end

    test "shows every token" do
      svg = svg(ExampleDesign.__schema__())

      for id <- ~w(color/accent color/link font-family/display font-weight/hint font-size/heading
                 line-height/heading
                 typography/note spacing/2px spacing/10 height/36px max-height/menu radius/default
                 shadow/raised text-shadow/strong),
          do: assert(svg =~ ~s(<g id="#{id}">), id)

      # Every layer of a token is named by its DTCG path.
      refute svg =~ "text-size/"

      # An alias's shadow is its target's filter.
      assert svg =~ ~s(<filter id="shadow-card")
      refute svg =~ ~s(<filter id="shadow-raised")
    end

    test "shows each component's variants and states, from the same looks as the CSS" do
      svg = svg(ExampleDesign.__schema__())

      # The tag: a row per variant, a column per state; the web binding's radius (2)
      # in place of the shared one (4), never the iOS binding's (6).
      for id <- ~w(tag/no-variant/enabled tag/accent/enabled tag/muted/enabled
                 tag/accent+large/enabled tag/accent/disabled tag/muted/disabled),
          do: assert(svg =~ ~s(<g id="#{id}">), id)

      assert svg =~ ~s(<g opacity="0.4">)
      assert svg =~ ~r/<rect [^>]*rx="2"[^>]*fill="#FDFDFD"/
      refute svg =~ ~r/<rect [^>]*rx="6"/
    end

    test "draws every kind of component the targets know" do
      svg = svg(ExampleComponents.__schema__())

      for c <- ExampleComponents.__schema__().components,
          do: assert(svg =~ ~s(<g id="component/#{String.replace(to_string(c.name), "_", "-")}">))

      # The button's spinner shows while it is loading, in the button's color.
      assert svg =~ ~s(<g id="button/primary/loading">)
      assert svg =~ ~r/<g id="checkbox\/default\/checked">(?:(?!<\/g>).)*<polyline/s
    end

    test "a spinner's sizes by their numbers, and its progress as a ring at 40" do
      svg = svg(ExampleComponents.__schema__())

      for id <- ~w(spinner/no-variant/enabled spinner/accent/enabled spinner/accent+16/enabled
                 spinner/accent+32/enabled spinner/accent+progress-40/enabled),
          do: assert(svg =~ ~s(<g id="#{id}">), id)

      [_, ring] = Regex.run(~r/<g id="spinner\/accent\+progress-40\/enabled">(.*?)<\/g>/s, svg)

      # 24px, a stroke of 12%: the track in its color, then the arc, 40 of 100, from the top.
      assert ring =~
               ~r/r="10.56" fill="none" stroke-width="2.88" stroke="#101010" stroke-opacity="0.1"\/>/

      assert ring =~
               ~r/stroke="#1A73E8" stroke-linecap="round" stroke-dasharray="26.54 66.35" transform="rotate\(-90 /

      # With a variant that changes it: the variant's track, on a dark backdrop.
      [_, inverse] =
        Regex.run(~r/<g id="spinner\/inverse\+progress-40\/enabled">(.*?)<\/g>/s, svg)

      assert inverse =~ ~r/<rect [^>]*fill="#222222"/
      assert inverse =~ ~r/stroke-width="2.88" stroke="#FDFDFD" stroke-opacity="0.3"\/>/
      assert inverse =~ ~r/stroke="#FDFDFD" stroke-linecap="round"/

      # The button's spinner is the size its part picks.
      assert svg =~ ~r/<g id="button\/primary\/loading">(?:(?!<g id=).)*<circle [^>]* r="7"/s
    end
  end
end
