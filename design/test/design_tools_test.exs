defmodule Prism.Design.DesignToolsTest do
  use ExUnit.Case, async: true

  # The generated design-tool files in targets/design-tools; their own checks (`npm
  # test` there) validate them as DTCG 2025.10, CSS and SVG.

  @dir "../targets/design-tools"
  @tokens Prism.Design.Components.__schema__().tokens

  defp read(path), do: File.read!(Path.join(@dir, path))

  test "the committed files start with the header naming the design file they come from" do
    for {path, file} <- [
          {"tokens.json", "design/lib/tokens.ex"},
          {"tokens.css", "design/lib/tokens.ex"},
          {"overview.svg", "design/lib/components.ex"}
        ] do
      assert Prism.Generator.Header.generated?(Path.join(@dir, path))
      assert read(path) =~ Prism.Generator.Header.line(path, file)
    end
  end

  test "tokens.json has every token but the 50% radius, which DTCG can't express" do
    json = JSON.decode!(read("tokens.json"))
    count = fn group -> map_size(json[group]) end
    kinds = Enum.frequencies_by(@tokens, & &1.kind)

    assert count.("color") == kinds.color
    assert count.("font-family") == kinds.family
    assert count.("font-weight") == kinds.font
    assert count.("font-size") == kinds.text
    assert count.("line-height") == kinds.text
    assert count.("typography") == kinds.typography
    assert count.("spacing") == kinds.space
    assert count.("height") == kinds.height
    assert count.("max-height") == kinds.max_height
    assert count.("shadow") == kinds.shadow
    assert count.("text-shadow") == kinds.text_shadow
    assert Map.keys(json["radius"]) == ["default"]
    assert read("tokens.css") =~ "  --prism-radius-full: 50%;\n"
  end

  test "the CSS names are the DTCG paths after --prism-" do
    json = JSON.decode!(read("tokens.json"))

    paths =
      for {group, tokens} <- json,
          is_map(tokens),
          name <- Map.keys(tokens),
          do: "--prism-#{group}-#{name}"

    names = for [_, name] <- Regex.scan(~r/^  (--[\w-]+):/m, read("tokens.css")), do: name
    assert Enum.sort(names) == Enum.sort(["--prism-radius-full" | paths])
    assert "--prism-color-primary" in names
  end

  test "the families are Nunito and Nunito Sans on the web, the system font natively" do
    json = JSON.decode!(read("tokens.json"))

    for {role, name} <- [{"display", "Nunito"}, {"text", "Nunito Sans"}] do
      assert json["font-family"][role]["$value"] == name

      assert json["font-family"][role]["$extensions"]["prism"] == %{
               "fallback" => "sans-serif",
               "ios" => "system",
               "android" => "system"
             }
    end
  end

  test "the overview names only the installed fonts, and shows every component" do
    svg = read("overview.svg")
    families = for [_, f] <- Regex.scan(~r/font-family="([^"]*)"/, svg), uniq: true, do: f
    assert Enum.sort(families) == ["Nunito", "Nunito Sans"]

    for c <- Prism.Design.Components.__schema__().components,
        do: assert(svg =~ ~s(<g id="component/#{String.replace(to_string(c.name), "_", "-")}">))
  end
end
