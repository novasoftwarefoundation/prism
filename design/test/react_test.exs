defmodule Prism.Design.ReactTest do
  use ExUnit.Case, async: true

  # The generated React package in targets/react; its own tests (`npm test` there)
  # build it and render every component against the CSS.

  @dir "../targets/react/src"
  @css File.read!(Path.join(__DIR__, "../../targets/web/css/components.css"))
  @design Prism.Design.Components.__schema__()

  defp in_css?(class), do: @css =~ ~r/\.#{Regex.escape(class)}(?![\w-])/

  test "one committed file per component, each with the header naming the design file" do
    components = for c <- @design.components, do: Macro.camelize(Atom.to_string(c.name)) <> ".tsx"

    assert Enum.sort(File.ls!(@dir)) == Enum.sort(components ++ ["helpers.ts", "index.ts"])

    for file <- File.ls!(@dir) do
      [header | _] = @dir |> Path.join(file) |> File.read!() |> String.split("\n")
      assert header == Prism.Generator.Header.line(file, "design/lib/components.ex")
    end
  end

  test "the button's classes are classes of the generated components.css" do
    button = File.read!(Path.join(@dir, "Button.tsx"))
    classes = for [_, class] <- Regex.scan(~r/"(prism-[a-z_-]+)"/, button), uniq: true, do: class

    assert "prism-button" in classes
    assert "prism-button--danger" in classes
    assert "prism-button--with-icon" in classes
    assert "prism-spinner" in classes

    # The icon part has no look of its own, so no rule: its class is a hook for the app.
    assert Enum.reject(classes, &in_css?/1) == ["prism-button__icon"]
  end
end
