defmodule Prism.Design.TokensTest do
  use ExUnit.Case, async: true

  test "the families are roles: Nunito and Nunito Sans on the web, the system font natively" do
    families = for %{kind: :family} = f <- Prism.Design.Tokens.__schema__().tokens, do: f

    assert [{:display, "Nunito"}, {:text, "Nunito Sans"}] ==
             Enum.map(families, &{&1.name, &1.web[:name]})

    assert Enum.all?(
             families,
             &(match?({:system, _}, &1.ios) and match?({:system, _}, &1.android))
           )
  end

  # The fonts' weights before they named an emphasis (prism 0.3.0): the web keeps them.
  @numbers [
    title0: 800,
    title1: 800,
    title2: 800,
    title3: 800,
    title4: 800,
    title5: 700,
    bodylarge: 300,
    introdesktop: 500,
    quote: 700,
    title6: 700,
    title7: 700,
    caption: 500,
    link: 500,
    subhead: 600,
    button: 700,
    footnote: 500,
    intro: 500,
    label: 700,
    body: 300,
    hint: 300,
    tablehead: 700,
    tablerow: 400,
    bold: 700,
    mono: 300
  ]

  test "a font names an emphasis: Nunito and Nunito Sans keep its weight, SF Pro has its own" do
    tokens = Prism.Design.Tokens.__schema__().tokens
    family = fn name -> Enum.find(tokens, &(&1.kind == :family and &1.name == name)) end

    weigh = fn font, platform ->
      Prism.Generator.Schema.weight(family.(font.family), platform, font.emphasis)
    end

    fonts = for %{kind: :font} = f <- tokens, do: f
    assert Enum.map(fonts, &{&1.name, weigh.(&1, :web)}) == @numbers

    sf_pro = [
      reading: 300,
      data: 400,
      supporting: 400,
      subheading: 500,
      strong: 600,
      headline: 700
    ]

    for font <- fonts, do: assert(weigh.(font, :ios) == sf_pro[font.emphasis], "#{font.name}")
  end

  # Native targets read type only from the typography tokens, so every role in either
  # list has one, and every font and text size is used by one.
  test "every font and text size role has a typography token" do
    tokens = Prism.Design.Tokens.__schema__().tokens
    names = fn kind -> for %{kind: ^kind, name: name} <- tokens, into: MapSet.new(), do: name end
    typographies = for %{kind: :typography} = t <- tokens, do: t

    assert MapSet.new(typographies, & &1.name) == MapSet.union(names.(:font), names.(:text))
    assert MapSet.new(typographies, & &1.font) == names.(:font)
    assert MapSet.new(typographies, & &1.text) == names.(:text)
  end

  test "mix prism.gen generates Prism's whole design into targets/web, react, design-tools and swift" do
    assert Application.get_env(:prism_generator, :design) == Prism.Design.Components

    assert Application.get_env(:prism_generator, :targets) == [
             web: "../targets/web",
             react: "../targets/react",
             design_tools: "../targets/design-tools",
             swift: "../targets/swift"
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

  test "mix.exs, both npm packages and the React package's lockfiles have the same version" do
    version = Mix.Project.config()[:version]
    web = JSON.decode!(File.read!("../targets/web/package.json"))
    react = JSON.decode!(File.read!("../targets/react/package.json"))

    assert web["version"] == version
    assert react["version"] == version
    # The React package's CSS is the web package's, at the same version.
    assert react["peerDependencies"][web["name"]] == version

    # Its lockfiles (React 19's, and CI's for React 18) record the version, the peer
    # and the linked web package too.
    for path <- ["package-lock.json", "test/react18/package-lock.json"] do
      lock = JSON.decode!(File.read!("../targets/react/#{path}"))
      assert lock["version"] == version, path
      assert lock["packages"][""]["version"] == version, path
      assert lock["packages"][""]["peerDependencies"][web["name"]] == version, path
      assert lock["packages"]["../web"]["version"] == version, path
    end
  end
end
