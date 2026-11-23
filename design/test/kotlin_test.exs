defmodule Prism.Design.KotlinTest do
  use ExUnit.Case, async: true

  # The generated Android library in targets/kotlin; CI builds it with Gradle and
  # publishes it to a local Maven repository to check its files and POM.

  @dir "../targets/kotlin"
  @sources Path.join(@dir, "src/main/kotlin/org/novasoftwarefoundation/prism")
  @design Prism.Design.Components.__schema__()

  defp read(path), do: File.read!(Path.join(@sources, path))

  test "the build, the tokens, the looks and one file per component, each with its header" do
    components =
      for c <- @design.components, do: Macro.camelize(Atom.to_string(c.name)) <> ".kt"

    assert Enum.sort(File.ls!(@sources)) ==
             Enum.sort(components ++ ["Look.kt", "Tokens.kt", "InputMetadata.kt"])

    for file <- components ++ ["InputMetadata.kt"] do
      [header | _] = file |> read() |> String.split("\n")
      assert header == Prism.Generator.Header.line(file, "design/lib/components.ex")
    end

    for path <-
          ["settings.gradle.kts", "build.gradle.kts"] ++
            for(f <- ["Tokens.kt", "Look.kt"], do: Path.relative_to(Path.join(@sources, f), @dir)) do
      [header | _] = @dir |> Path.join(path) |> File.read!() |> String.split("\n")
      assert header == Prism.Generator.Header.line(path, "design/lib/tokens.ex")
    end
  end

  test "org.novasoftwarefoundation:prism-compose, with the POM Maven Central requires" do
    assert File.read!(Path.join(@dir, "settings.gradle.kts")) =~
             ~s|rootProject.name = "prism-compose"|

    properties =
      for line <- @dir |> Path.join("gradle.properties") |> File.read!() |> String.split("\n"),
          [key, value] <- [String.split(line, "=", parts: 2)],
          not String.starts_with?(key, "#"),
          into: %{},
          do: {key, value}

    assert properties["group"] == "org.novasoftwarefoundation"

    for key <- ~w(name description url license.name license.url developer.id developer.name
                  developer.url scm.url scm.connection) do
      assert properties["pom." <> key] not in [nil, ""], "gradle.properties has no pom.#{key}"
    end

    assert properties["pom.scm.url"] == "https://github.com/novasoftwarefoundation/prism"
    refute Map.has_key?(properties, "version")
  end

  test "both families are the system font, at the Android scale's weights" do
    tokens = read("Tokens.kt")

    assert tokens =~
             "public val display: PrismFontFamily = PrismFontFamily(\n            font = FontFamily.Default,"

    assert tokens =~
             "public val text: PrismFontFamily = PrismFontFamily(\n            font = FontFamily.Default,"

    assert tokens =~ "headline = 800,"
  end

  test "a focused invalid text field keeps its warning border (ADR 0008)" do
    field = read("TextField.kt")

    assert field =~
             "if (focused && invalid) {\n            root += PrismLook(borderColor = Prism.Colors.warning)"
  end
end
