defmodule Prism.Design.TokensTest do
  use ExUnit.Case, async: true

  test "the families are roles: Nunito and Nunito Sans on the web, the system font natively" do
    families = for %{kind: :family} = f <- Prism.Design.Tokens.__schema__().tokens, do: f

    assert [{:display, "Nunito"}, {:text, "Nunito Sans"}] ==
             Enum.map(families, &{&1.name, &1.web[:name]})

    assert Enum.all?(families, &(&1.ios == :system and &1.android == :system))
  end

  # Native targets read type only from the typography tokens, so every role in either
  # list has one, and every font and text size is used by one.
  test "every font and text size role has a type style" do
    tokens = Prism.Design.Tokens.__schema__().tokens
    names = fn kind -> for %{kind: ^kind, name: name} <- tokens, into: MapSet.new(), do: name end
    styles = for %{kind: :typography} = t <- tokens, do: t

    assert MapSet.new(styles, & &1.name) == MapSet.union(names.(:font), names.(:text))
    assert MapSet.new(styles, & &1.font) == names.(:font)
    assert MapSet.new(styles, & &1.text) == names.(:text)
  end

  test "mix prism.gen generates Prism's whole design into targets/web, react and design-tools" do
    assert Application.get_env(:prism_generator, :design) == Prism.Design.Components

    assert Application.get_env(:prism_generator, :targets) == [
             web: "../targets/web",
             react: "../targets/react",
             design_tools: "../targets/design-tools"
           ]

    assert File.exists?("../targets/web/package.json")
    assert File.exists?("../targets/react/package.json")
  end

  test "the committed web files start with the header naming the design file they come from" do
    for {path, file} <- [
          {"tailwind.preset.js", "design/lib/tokens.ex"},
          {"css/base.css", "design/lib/tokens.ex"},
          {"css/components.css", "design/lib/components.ex"}
        ] do
      [header | _] = "../targets/web" |> Path.join(path) |> File.read!() |> String.split("\n")
      assert header == Prism.Generator.Header.line(path, file)
    end
  end

  test "mix.exs, both npm packages and the React package's lockfile have the same version" do
    version = Mix.Project.config()[:version]
    web = JSON.decode!(File.read!("../targets/web/package.json"))
    react = JSON.decode!(File.read!("../targets/react/package.json"))

    assert web["version"] == version
    assert react["version"] == version
    # The React package's CSS is the web package's, at the same version.
    assert react["peerDependencies"][web["name"]] == version

    # Its lockfile records the version, the peer and the linked web package too.
    lock = JSON.decode!(File.read!("../targets/react/package-lock.json"))
    assert lock["version"] == version
    assert lock["packages"][""]["version"] == version
    assert lock["packages"][""]["peerDependencies"][web["name"]] == version
    assert lock["packages"]["../web"]["version"] == version
  end
end
