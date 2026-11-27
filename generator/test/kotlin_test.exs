defmodule Prism.Generator.KotlinTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{ExampleComponents, ExampleDesign, Header, Kotlin}

  # The example designs' libraries, reviewed and kept in test/fixtures/kotlin: one with a
  # component of every kind, one with a token of every kind. CI builds both with Gradle.
  # A change to what the generator writes fails here until they are updated.
  for {name, design} <- [components: ExampleComponents, design: ExampleDesign] do
    test "the files for #{inspect(design)} equal the fixtures in test/fixtures/kotlin/#{name}" do
      dir = "test/fixtures/kotlin/#{unquote(name)}"
      files = Kotlin.files(unquote(design).__schema__())

      for {path, body, from} <- files do
        assert File.read!(Path.join(dir, path)) == Header.put(path, from, body),
               "#{path} differs from #{dir}/#{path}"
      end

      on_disk =
        for path <- Path.wildcard(Path.join(dir, "**/*.{kt,kts}")),
            do: Path.relative_to(path, dir)

      assert Enum.sort(on_disk) == Enum.sort(for {path, _, _} <- files, do: path)
    end
  end

  test "a build, the tokens, the looks and one file per component, each from its design file" do
    files = Kotlin.files(ExampleComponents.__schema__())
    dir = "src/main/kotlin/com/example/kit"

    assert for({path, _, _} <- files, do: path) ==
             ["settings.gradle.kts", "build.gradle.kts"] ++
               for(
                 name <-
                   ~w(Tokens Look Button TextField TextArea Field RadioGroup Radio Select
                            Spinner Checkbox Tag MessageBar StepIndicator ImagePicker InputMetadata),
                 do: "#{dir}/#{name}.kt"
               )

    assert Enum.uniq(for {_, _, from} <- files, do: from) == [
             "test/support/example_components.ex"
           ]
  end

  test "the build: an Android library in the package's namespace, strict, published with sources" do
    files = Kotlin.files(ExampleDesign.__schema__())
    build = body(files, "build.gradle.kts")
    settings = body(files, "settings.gradle.kts")
    v = Kotlin.versions()

    assert settings =~ ~s|rootProject.name = "acme-compose"|
    assert build =~ ~s|id("com.android.library") version "#{v[:android_gradle_plugin]}"|
    assert build =~ ~s|id("org.jetbrains.kotlin.plugin.compose") version "#{v[:kotlin]}"|
    assert build =~ ~s|namespace = "com.example.acme"|
    assert build =~ "version = release(37) { minorApiLevel = 1 }"
    assert build =~ "minSdk = #{v[:min_sdk]}"
    assert build =~ "explicitApi()"
    assert build =~ "allWarningsAsErrors.set(true)"
    assert build =~ ~s|api(platform("androidx.compose:compose-bom:#{v[:compose_bom]}"))|
    assert build =~ "withSourcesJar()"
    assert build =~ "withJavadocJar()"
    assert build =~ ~s|artifactId = "acme-compose"|

    # Nothing of a design's own but its names: the POM comes from gradle.properties.
    for key <- ~w(name description url license.name license.url scm.url scm.connection) do
      assert build =~ ~s|pomValue("#{key}")|
    end

    # The artifact is the name in lower case by default.
    assert body(Kotlin.files(ExampleComponents.__schema__()), "settings.gradle.kts") =~
             ~s|rootProject.name = "kit"|
  end

  test "every line is within 100 columns" do
    for design <- [ExampleComponents, ExampleDesign],
        {path, body, _} <- Kotlin.files(design.__schema__()),
        line <- String.split(body, "\n") do
      assert String.length(line) <= 100, "#{path} has a line of #{String.length(line)}: #{line}"
    end
  end

  describe "tokens" do
    test "names are camelCase in an object of the declaration's name; values are dp and sp" do
      tokens = body(Kotlin.files(ExampleDesign.__schema__()), "Tokens.kt")

      assert tokens =~ "package com.example.acme\n"
      assert tokens =~ "public object Acme {\n"
      assert tokens =~ "public val accent: Color = Color(0xFF1A73E8)\n"
      assert tokens =~ "public val link: Color = accent\n"
      assert tokens =~ "public val step10: Dp = 40.dp\n"
      assert tokens =~ "public val default: AcmeRadius = AcmeRadius.Fixed(4.dp)\n"
      assert tokens =~ "size = 16.sp,\n"
      assert tokens =~ "lineHeight = 24.sp,\n"
    end

    test "a deprecated alias is @Deprecated with its replacement; the library writes its value" do
      tokens = body(Kotlin.files(ExampleDesign.__schema__()), "Tokens.kt")

      assert tokens =~
               ~s|@Deprecated("Use card.", ReplaceWith("card"))\n        public val raised|
    end

    # Each family gives every emphasis the weight of its Android scale, not the web's or iOS's;
    # a named font is the device's font of that name, at each of those weights.
    test "a family is its Android binding, with its Android scale's weight of each emphasis" do
      tokens = body(Kotlin.files(ExampleDesign.__schema__()), "Tokens.kt")
      look = body(Kotlin.files(ExampleDesign.__schema__()), "Look.kt")

      assert look =~ "public enum class AcmeEmphasis { Aside, Reading, Headline }"
      assert tokens =~ "font = FontFamily.Default,\n            aside = 300,"
      assert tokens =~ "headline = 800,"

      assert tokens =~
               ~s|Font(DeviceFontFamilyName("Acme Text"), FontWeight(900), FontStyle.Normal)|

      assert tokens =~ "headline = 900,"
    end

    # A monospaced family bound to the system font is Android's monospaced one.
    test "a monospaced family is FontFamily.Monospace" do
      tokens = body(Kotlin.files(ExampleDesign.__schema__()), "Tokens.kt")

      assert tokens =~
               "public val code: AcmeFontFamily = AcmeFontFamily(\n            font = FontFamily.Monospace,"

      assert length(String.split(tokens, "FontFamily.Monospace")) == 2

      assert tokens =~
               "public val code: AcmeTypography = AcmeTypography(\n            family = Families.code,"
    end

    test "a typography is its family, emphasis, italic, size and line height" do
      tokens = body(Kotlin.files(ExampleDesign.__schema__()), "Tokens.kt")

      assert tokens =~
               "family = Families.text,\n            emphasis = AcmeEmphasis.Aside,\n" <>
                 "            italic = true,"
    end
  end

  describe "components" do
    test "an axis is an enum class in UpperCamelCase; an alias is a companion property" do
      button = body(Kotlin.files(ExampleComponents.__schema__()), "Button.kt")
      spinner = body(Kotlin.files(ExampleComponents.__schema__()), "Spinner.kt")

      assert button =~ "public enum class KitButtonVariant {\n    Primary, Quiet, Icon;"
      assert button =~ "public val Subtle: KitButtonVariant get() = Quiet"
      assert spinner =~ "public enum class KitSpinnerSize {\n    Size24, Size16, Size32\n}"
      assert spinner =~ "size: KitSpinnerSize = KitSpinnerSize.Size24,"
      # An axis without a default is nullable.
      assert spinner =~ "variant: KitSpinnerVariant? = null,"
    end

    test "the looks are laid over each other in the web's order, with the android: binding" do
      tag = body(Kotlin.files(ExampleDesign.__schema__()), "Tag.kt")

      # The tag's ios: radius is iOS's only; Android keeps the shared radius.
      assert tag =~
               "root += AcmeLook(background = Acme.Colors.paper, radius = Acme.Radii.default)"

      refute tag =~ "6.dp"
    end

    test "an app's state outweighs the focus (ADR 0008)" do
      field = body(Kotlin.files(ExampleComponents.__schema__()), "TextField.kt")

      focus = :binary.match(field, "if (variant == KitTextFieldVariant.Inverse && focused)")
      invalid = :binary.match(field, "if (focused && invalid) {")

      assert invalid != :nomatch

      assert field =~
               "if (focused && invalid) {\n            root += KitLook(borderColor = Kit.Colors.alarm)"

      refute focus != :nomatch and elem(focus, 0) > elem(invalid, 0)
    end

    test "pressed, hovered and focused come from the interaction source, disabled from enabled" do
      files = Kotlin.files(ExampleComponents.__schema__())
      button = body(files, "Button.kt")
      field = body(files, "TextField.kt")

      assert button =~ "val pressed by interactions.collectIsPressedAsState()"
      assert button =~ "val hovered by interactions.collectIsHoveredAsState()"
      assert button =~ "disabled = !enabled,"
      assert button =~ "role = Role.Button,"
      assert button =~ "indication = null,"
      assert button =~ ".kitBox(root, interactions, LocalIndication.current)"
      refute button =~ "pressed: Boolean = false,\n    loading"

      assert field =~ "val focused by interactions.collectIsFocusedAsState()"
      assert field =~ "invalid: Boolean = false,"
      assert field =~ "prefix: (@Composable () -> Unit)? = null,"
    end

    test "a part the app fills is a slot; a spinner part has the variants it picks" do
      files = Kotlin.files(ExampleComponents.__schema__())
      button = body(files, "Button.kt")
      picker = body(files, "ImagePicker.kt")

      assert button =~ "icon: (@Composable () -> Unit)? = null,"
      assert button =~ "iconSide: KitSide = KitSide.Start,"
      assert button =~ "KitSpinnerLooks(size = KitSpinnerSize.Size16).root + looks.spinner"
      assert picker =~ "button: @Composable () -> Unit,"
      refute picker =~ "public val button: KitLook"
    end

    test "the spinner takes Compose's progress from 0 to 1, its looks the design's 0 to 100" do
      spinner = body(Kotlin.files(ExampleComponents.__schema__()), "Spinner.kt")

      assert spinner =~ "progress: Float? = null,"
      assert spinner =~ "val value = progress?.coerceIn(0f, 1f)"
      assert spinner =~ "progress = value?.times(100f)"
      assert spinner =~ "Modifier.progressSemantics(it)"
    end

    # Its list's and options' states are the options' own (in `Option`), not the select's, as
    # on iOS: parameters for them would be API that does nothing.
    test "the select takes no state of its list or its options" do
      select = body(Kotlin.files(ExampleComponents.__schema__()), "Select.kt")
      [_, signature] = String.split(select, "public fun KitSelect(\n", parts: 2)
      [signature, _] = String.split(signature, "\n) {", parts: 2)
      [_, scope] = String.split(select, "public class KitSelectScope internal constructor(\n")
      [scope, _] = String.split(scope, "\n) {", parts: 2)

      for part <- [signature, scope], name <- ~w(hovered selected) do
        refute part =~ ~r/\b#{name}: /, "the select takes #{name}:\n#{part}"
      end

      # The option has them, from its pointer and its own parameter.
      assert select =~ "        val hovered by interactions.collectIsHoveredAsState()\n"

      assert select =~
               "            hovered = hovered,\n            selected = selected,\n"
    end

    test "the code is indented by its blocks" do
      files = Kotlin.files(ExampleComponents.__schema__())
      select = body(files, "Select.kt")
      field = body(files, "TextField.kt")

      # In Option's body, 8 deep.
      assert select =~
               "        val hovered by interactions.collectIsHoveredAsState()\n" <>
                 "        val looks = KitSelectLooks(\n            variant = variant,\n"

      # In the decorator's row, 20 deep.
      assert field =~
               "                Row(Modifier.kitBox(root.withoutPadding).height(IntrinsicSize.Min)) {\n" <>
                 "                    if (prefix != null) {\n                        Box(\n"
    end

    test "the build compiles for apps on Kotlin 2.2" do
      build = body(Kotlin.files(ExampleDesign.__schema__()), "build.gradle.kts")

      assert build =~ "import org.jetbrains.kotlin.gradle.dsl.KotlinVersion\n"
      assert build =~ ~s|coreLibrariesVersion = "2.2.20"|
      assert build =~ "languageVersion.set(KotlinVersion.KOTLIN_2_2)"
      assert build =~ "apiVersion.set(KotlinVersion.KOTLIN_2_2)"
    end

    # Gson and Moshi give every JSON number as a Double; a whole one is a whole number.
    test "the input metadata takes any whole number, as parsers give one" do
      metadata = body(Kotlin.files(ExampleComponents.__schema__()), "InputMetadata.kt")

      assert metadata =~ "return (value as? Number)?.let(::whole)"
      assert metadata =~ "is Double, is Float -> number.toDouble().takeIf {"
      assert metadata =~ "it.isFinite() && it % 1.0 == 0.0 &&"
      # Another kind of number, such as Gson's LazilyParsedNumber, by its decimal text.
      assert metadata =~
               "else -> runCatching { java.math.BigDecimal(number.toString()).intValueExact() }"
    end

    test "the input metadata validates its range and reads snake_case keys" do
      metadata = body(Kotlin.files(ExampleComponents.__schema__()), "InputMetadata.kt")

      assert metadata =~ "public data class KitTextFieldInputMetadata("
      assert metadata =~ "public val settleMs: Int? = null,"
      assert metadata =~ "require(settleMs == null || settleMs in 1..1000)"
      assert metadata =~ ~s|settleMs = int(values, "settle_ms")|
    end
  end

  describe "errors" do
    test "without a kotlin declaration" do
      schema = %{ExampleDesign.__schema__() | kotlin: nil}

      assert_raise ArgumentError, ~r/needs the design's kotlin declaration/, fn ->
        Kotlin.files(schema)
      end
    end

    test "a component, a part or a value the target doesn't know" do
      schema = ExampleComponents.__schema__()
      [c | rest] = schema.components

      assert_raise ArgumentError, ~r/has no component :gauge/, fn ->
        Kotlin.files(%{schema | components: [%{c | name: :gauge} | rest]})
      end

      [p | parts] = c.parts

      assert_raise ArgumentError, ~r/has no part :badge of :button/, fn ->
        Kotlin.files(%{schema | components: [%{c | parts: [%{p | name: :badge} | parts]} | rest]})
      end
    end

    test "a length in percent other than a radius from 50% or a stroke" do
      schema = ExampleComponents.__schema__()

      components =
        for c <- schema.components do
          if c.name == :radio_group, do: %{c | style: [gap: {10, :percent}]}, else: c
        end

      assert_raise ArgumentError, ~r/10% has no size on Android/, fn ->
        Kotlin.files(%{schema | components: components})
      end
    end
  end

  defp body(files, name) do
    {_, body, _} = Enum.find(files, fn {path, _, _} -> Path.basename(path) == name end)
    body
  end
end
