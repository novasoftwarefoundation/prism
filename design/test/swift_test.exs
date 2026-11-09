defmodule Prism.Design.SwiftTest do
  use ExUnit.Case, async: true

  # The generated Swift package in targets/swift; CI builds it with xcodebuild for the
  # iOS Simulator.

  @dir "../targets/swift"
  @sources Path.join(@dir, "Sources/Prism")
  @design Prism.Design.Components.__schema__()

  defp read(path), do: File.read!(Path.join(@sources, path))

  test "the package, the tokens, the looks and one file per component, each with its header" do
    components =
      for c <- @design.components, do: Macro.camelize(Atom.to_string(c.name)) <> ".swift"

    assert Enum.sort(File.ls!(@sources)) ==
             Enum.sort(components ++ ["Look.swift", "Tokens.swift", "InputMetadata.swift"])

    for file <- components ++ ["InputMetadata.swift"] do
      [header | _] = file |> read() |> String.split("\n")
      assert header == Prism.Generator.Header.line(file, "design/lib/components.ex")
    end

    for path <- ["Package.swift", "Sources/Prism/Tokens.swift", "Sources/Prism/Look.swift"] do
      [header, second | _] = @dir |> Path.join(path) |> File.read!() |> String.split("\n")
      assert header == Prism.Generator.Header.line(path, "design/lib/tokens.ex")
      if path == "Package.swift", do: assert(second == "// swift-tools-version: 6.2")
    end
  end

  test "one library, Prism, for iOS 26; no fonts while both families are the system font" do
    package = File.read!(Path.join(@dir, "Package.swift"))
    assert package =~ ~s|.library(name: "Prism", targets: ["Prism"])|
    assert package =~ ~s|platforms: [.iOS(.v26)]|
    refute package =~ "resources"
    refute File.exists?(Path.join(@sources, "Fonts"))

    assert read("Tokens.swift") =~
             "public static let display = PrismFontFamily(\n            .system,"
  end

  test "a family is its font with SF Pro's weight of each emphasis; a typography names one" do
    tokens = read("Tokens.swift")

    for family <- ~w(display text) do
      assert tokens =~
               """
                       public static let #{family} = PrismFontFamily(
                           .system, reading: 300, data: 400, supporting: 400, subheading: 500, strong: 600,
                           headline: 700)
               """
    end

    assert tokens =~ "family: Families.display, emphasis: .headline, italic: false, size: 50,"
    assert tokens =~ "family: Families.text, emphasis: .reading, italic: false, size: 20,"
    assert read("Button.swift") =~ "emphasis: .supporting,"
  end

  # The base text styles an iOS app scales Prism's type by today, kept by the rule
  # that picks them: nothing it shows shifts.
  test "Dynamic Type keeps the base text styles of the typography an iOS app uses today" do
    tokens = read("Tokens.swift")

    for {typography, style} <- [
          title4: "title",
          body: "body",
          button: "body",
          caption: "footnote",
          footnote: "callout"
        ] do
      assert tokens =~
               ~r/public static let #{typography} = PrismTypography\([^)]*textStyle: \.#{style}\)/
    end
  end

  test "the spinner: sizes by their points, a progress value, 20 in a loading button" do
    spinner = read("Spinner.swift")
    assert spinner =~ "case size24, size16, size20, size32\n"
    assert spinner =~ "root.apply(PrismLook(stroke: .fraction(0.16), track: Prism.Colors.grey4))"

    assert spinner =~
             "if variant == .inverse && progress != nil {\n            root.apply(PrismLook(track: Prism.Colors.white.opacity(0.2)))"

    assert read("Button.swift") =~ "PrismSpinnerStyle(nil, size: .size20, look: looks.spinner)"
  end

  test "the package's LICENSE is the repository's" do
    assert File.read!(Path.join(@dir, "LICENSE")) == File.read!("../LICENSE")
  end
end
