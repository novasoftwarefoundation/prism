defmodule Prism.Generator.Kotlin do
  @moduledoc """
  Generates an Android library from a design: Jetpack Compose code with the
  design's tokens and one composable per component. The design's `kotlin`
  declaration names it: `package:` is its Kotlin package and Android namespace,
  `name:` the prefix of its types and the object of its tokens (`kotlin package:
  "com.example.acme", name: "Acme"` gives `Acme.Colors.accent` and
  `AcmeButton`), and `artifact:` its Maven artifact id.

  The files, under the target's folder:

  - `settings.gradle.kts` and `build.gradle.kts`: one Android library of the
    artifact's name, built with the Android Gradle plugin, Kotlin and Compose
    at the versions this module pins (`versions/0`), in Kotlin's explicit API
    mode, a warning failing the build, and a Maven publication of the release
    variant with its sources and javadoc jars. Its group, version and POM
    come from the Gradle properties (`group`, `version`, `pom.*`) of a
    hand-written `gradle.properties` beside them;
  - `src/main/kotlin/<package>/Tokens.kt`: the tokens in an object of the
    declaration's name: `Colors` (`Color`), `Shadows` and `TextShadows`,
    `Spacing`, `Heights` and `MaxHeights` (`Dp`), `Radii`, `Families` and
    `Typography`. Names are camelCase (`Shadows.btnPressed`), with Kotlin's
    keywords in backquotes;
  - `src/main/kotlin/<package>/Look.kt`: the types the tokens and components
    are made of, among them `<name>Look`, a look as data, and the modifier and
    composables that draw one (`Modifier.<lower>Box`, `<name>Text`,
    `<name>LookBox`);
  - `src/main/kotlin/<package>/<Component>.kt`: one file per component, see
    `Prism.Generator.Kotlin.Components`;
  - `src/main/kotlin/<package>/InputMetadata.kt`, for a design with input
    properties ([ADR 0012](../docs/adr/0012-semantic-input-metadata.md)).

  ## Values

  Lengths are dp: px as they are, rem times 16. A length in percent is only a
  radius of 50% or more (a capsule, a circle on a square) or a stroke (a
  fraction of the box it is drawn in); anything else fails generation. Colors
  are sRGB. A shadow is CSS's box shadow, with its blur and spread, drawn with
  `Modifier.dropShadow` or, inset, `Modifier.innerShadow`. Sides are start and
  end for the design's left and right, so they follow the text's direction.

  ## Type

  Type comes only from the typography tokens and the components' typography
  pairs. A typography is its font's family as `android:` binds it (the system
  font, `FontFamily.Default`, or `FontFamily.Monospace` for a monospaced family,
  or a named font on the device), its emphasis
  (`<name>Emphasis`, drawn at the Android scale's weight for it) and italic,
  and its size and line height in sp, so both follow the user's font size,
  Android's nonlinear curve included; Compose keeps an sp line height in
  proportion to its text. A look with a typography has its height as the least
  it takes, so a box grows with its text instead of cutting it off.

  ## Deprecated tokens

  A deprecated token is `@Deprecated` in Kotlin, with a `ReplaceWith` for an
  alias, so an app that uses it gets a warning; the library's own code writes
  its value instead, so it builds without warnings.
  """

  alias Prism.Generator.Kotlin.Components
  alias Prism.Generator.Schema
  alias Prism.Generator.Web

  require EEx

  EEx.function_from_file(:defp, :look_kt, Path.join(__DIR__, "kotlin/look.kt.eex"), [:assigns])

  # The toolchain the library is built with, and the Android versions it targets:
  # Compose 1.13 (BOM 2026.11.01) needs compileSdk 37.1 and the Android Gradle plugin 9.
  # It is compiled for Kotlin 2.2 (its language, API and standard library), so an app on
  # Kotlin 2.2 or later reads it, as it reads Compose 1.13, whose own floor that is.
  @versions [
    android_gradle_plugin: "9.5.2",
    kotlin: "2.4.21",
    kotlin_api: {2, 2},
    kotlin_stdlib: "2.2.20",
    compose_bom: "2026.11.01",
    compile_sdk: {37, 1},
    min_sdk: 23,
    jvm: 17
  ]

  # Kotlin's hard keywords, which a name can be only in backquotes.
  @keywords ~w(as break class continue do else false for fun if in interface is null object
               package return super this throw true try typealias typeof val var when while)

  @doc "The versions the generated build pins."
  def versions, do: @versions

  @doc """
  The files of the Kotlin target for a design's `__schema__/0`, as
  `[{path, body, design_file}]`.
  """
  def files(design) do
    kotlin =
      design.kotlin ||
        raise ArgumentError,
              "the Kotlin target needs the design's kotlin declaration (package:, name:)"

    ctx = context(design, kotlin)
    dir = "src/main/kotlin/" <> String.replace(kotlin.package, ".", "/")

    [
      {"settings.gradle.kts", settings(ctx), design.tokens_file},
      {"build.gradle.kts", build(ctx), design.tokens_file},
      {"#{dir}/Tokens.kt", tokens(ctx), design.tokens_file},
      {"#{dir}/Look.kt", look(ctx), design.tokens_file}
    ] ++
      for(
        {name, body} <- Components.files(design, ctx),
        do: {"#{dir}/#{name}.kt", body, design.file}
      ) ++
      for {path, body} <-
            Prism.Generator.InputMetadata.kotlin_files(design, ctx.m, kotlin.package),
          do: {"#{dir}/#{path}", body, design.file}
  end

  @doc """
  The folder Gradle compiles every Kotlin source below, so `mix prism.gen` takes out a
  generated source below it that no target writes now, such as a renamed package's.
  """
  def source_folders(_design), do: ["src/main/kotlin"]

  defp context(design, kotlin) do
    tokens = Map.new(design.tokens, &{{&1.kind, &1.name}, &1})

    %{
      m: kotlin.name,
      lower: lower_first(kotlin.name),
      package: kotlin.package,
      artifact: kotlin.artifact,
      tokens: tokens,
      design: design
    }
  end

  # ------------------------------------------------------------ the build

  defp settings(ctx) do
    """
    pluginManagement {
        repositories {
            google()
            mavenCentral()
            gradlePluginPortal()
        }
    }

    dependencyResolutionManagement {
        repositories {
            google()
            mavenCentral()
        }
    }

    rootProject.name = "#{ctx.artifact}"
    """
  end

  defp build(ctx) do
    v = @versions
    {sdk, minor} = v[:compile_sdk]
    {api_major, api_minor} = v[:kotlin_api]
    api = "KotlinVersion.KOTLIN_#{api_major}_#{api_minor}"

    """
    // The library's group, version and POM are Gradle properties: `group` and the `pom.*`
    // keys in gradle.properties, the version from the release (-Pversion=X.Y.Z).
    import org.jetbrains.kotlin.gradle.dsl.KotlinVersion

    plugins {
        id("com.android.library") version "#{v[:android_gradle_plugin]}"
        id("org.jetbrains.kotlin.plugin.compose") version "#{v[:kotlin]}"
        `maven-publish`
    }

    android {
        namespace = "#{ctx.package}"
        compileSdk {
            version = release(#{sdk}) { minorApiLevel = #{minor} }
        }
        defaultConfig {
            minSdk = #{v[:min_sdk]}
        }
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_#{v[:jvm]}
            targetCompatibility = JavaVersion.VERSION_#{v[:jvm]}
        }
        publishing {
            singleVariant("release") {
                withSourcesJar()
                withJavadocJar()
            }
        }
    }

    // Compiled for Kotlin #{api_major}.#{api_minor}, so an app on Kotlin #{api_major}.#{api_minor} or later reads it.
    kotlin {
        explicitApi()
        jvmToolchain(#{v[:jvm]})
        coreLibrariesVersion = "#{v[:kotlin_stdlib]}"
        compilerOptions {
            languageVersion.set(#{api})
            apiVersion.set(#{api})
            allWarningsAsErrors.set(true)
        }
    }

    dependencies {
        api(platform("androidx.compose:compose-bom:#{v[:compose_bom]}"))
        api("androidx.compose.material3:material3")
        api("androidx.compose.foundation:foundation")
        api("androidx.compose.ui:ui")
    }

    fun pomValue(key: String): Provider<String> = providers.gradleProperty("pom.$key")

    publishing {
        publications {
            register<MavenPublication>("release") {
                artifactId = "#{ctx.artifact}"
                afterEvaluate { from(components["release"]) }
                pom {
                    name.set(pomValue("name"))
                    description.set(pomValue("description"))
                    url.set(pomValue("url"))
                    licenses {
                        license {
                            name.set(pomValue("license.name"))
                            url.set(pomValue("license.url"))
                        }
                    }
                    developers {
                        developer {
                            id.set(pomValue("developer.id"))
                            name.set(pomValue("developer.name"))
                            url.set(pomValue("developer.url"))
                        }
                    }
                    scm {
                        url.set(pomValue("scm.url"))
                        connection.set(pomValue("scm.connection"))
                        developerConnection.set(pomValue("scm.connection"))
                    }
                }
            }
        }
    }
    """
  end

  defp look(ctx) do
    emphases = for %{kind: :emphasis, name: name} <- ctx.design.tokens, do: name

    look_kt(%{
      m: ctx.m,
      lower: ctx.lower,
      package: ctx.package,
      emphases: Enum.map(emphases, &ident/1),
      emphases_cases: Enum.map(emphases, &pascal/1)
    })
  end

  # ------------------------------------------------------------ the tokens

  defp tokens(ctx) do
    groups = [
      {"Colors", "The colors.", :color, &color_token/2},
      {"Shadows", "The shadows.", :shadow, &shadow_token/2},
      {"TextShadows", "The text shadows.", :text_shadow, &shadow_token/2},
      {"Spacing", "The spacing steps, in dp.", :space, &length_token/2},
      {"Heights", "The height steps, in dp.", :height, &length_token/2},
      {"MaxHeights", "The maximum heights, in dp.", :max_height, &length_token/2},
      {"Radii", "The corner radii.", :radius, &radius_token/2},
      {"Families", "The font families, as Android binds them.", :family, &family_token/2},
      {"Typography", "The typography tokens.", :typography, &typography_token/2}
    ]

    objects =
      for {name, doc, kind, write} <- groups,
          tokens = Enum.filter(ctx.design.tokens, &(&1.kind == kind)),
          tokens != [] do
        lines =
          tokens
          |> Enum.chunk_by(& &1.group)
          |> Enum.map_join("\n", fn [first | _] = chunk ->
            comment = if first.group, do: "        // #{first.group}\n", else: ""
            comment <> Enum.map_join(chunk, "", &write.(ctx, &1))
          end)

        "    /** #{doc} */\n    public object #{name} {\n#{lines}    }\n"
      end

    body = Enum.join(objects, "\n")

    imports =
      [
        {"Color", "androidx.compose.ui.graphics.Color"},
        {"Dp", "androidx.compose.ui.unit.Dp"},
        {".dp", "androidx.compose.ui.unit.dp"},
        {".sp", "androidx.compose.ui.unit.sp"},
        {"FontFamily", "androidx.compose.ui.text.font.FontFamily"},
        {"Font(", "androidx.compose.ui.text.font.Font"},
        {"FontWeight", "androidx.compose.ui.text.font.FontWeight"},
        {"FontStyle", "androidx.compose.ui.text.font.FontStyle"},
        {"DeviceFontFamilyName", "androidx.compose.ui.text.font.DeviceFontFamilyName"}
      ]
      |> Enum.filter(fn {use, _} -> String.contains?(body, use) end)
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map_join("", &"import #{&1}\n")

    """
    package #{ctx.package}

    #{imports}
    /** The design's tokens. Lengths are dp, type sizes sp. */
    public object #{ctx.m} {
    #{body}}
    """
  end

  defp val(name, type, value, doc \\ nil) do
    doc = if doc, do: "        /** #{doc} */\n", else: ""
    "#{doc}        public val #{ident(name)}: #{type} = #{value}\n"
  end

  defp color_token(ctx, %{name: name, value: value}),
    do: val(name, "Color", if(is_atom(value), do: ident(value), else: color(ctx, value)))

  # A deprecated shadow is deprecated in Kotlin too, so an app that uses it gets a
  # warning; an alias names the shadow to use instead.
  defp shadow_token(ctx, %{value: ref} = t) when is_atom(ref) do
    value = if deprecated?(ctx, ref), do: shadow_literal(ctx, ref), else: ident(ref)
    deprecated(t, ref) <> val(t.name, "#{ctx.m}Shadow", value)
  end

  defp shadow_token(ctx, t) do
    {head, args} = shadow_args(ctx, t)

    deprecated(t, nil) <>
      fill("        ", "public val #{ident(t.name)}: #{ctx.m}Shadow = #{head}", args, ")") <>
      "\n"
  end

  defp deprecated(t, alias) do
    cond do
      not Map.get(t, :deprecated, false) ->
        ""

      alias ->
        ~s|        @Deprecated("Use #{camel(alias)}.", ReplaceWith("#{camel(alias)}"))\n|

      true ->
        ~s|        @Deprecated("A deprecated shadow of the design.")\n|
    end
  end

  defp shadow_args(ctx, %{value: value}) do
    fields =
      [color: color(ctx, value[:color])] ++
        for(
          key <- [:x, :y, :blur, :spread],
          (n = Keyword.get(value, key, 0)) != 0,
          do: {key, dp(n)}
        ) ++ if(value[:inset], do: [inset: "true"], else: [])

    {"#{ctx.m}Shadow(", Enum.map(fields, fn {k, v} -> "#{k} = #{v}" end)}
  end

  # The shadow `name` in code: its token, or for a deprecated one its value, so the
  # library itself uses no deprecated token.
  defp shadow(ctx, name) do
    if deprecated?(ctx, name),
      do: shadow_literal(ctx, name),
      else: "#{ctx.m}.Shadows.#{ident(name)}"
  end

  defp shadow_literal(ctx, name) do
    case ctx.tokens[{:shadow, name}] do
      %{value: ref} when is_atom(ref) ->
        shadow(ctx, ref)

      t ->
        {head, args} = shadow_args(ctx, t)
        head <> Enum.join(args, ", ") <> ")"
    end
  end

  defp deprecated?(ctx, name), do: Map.get(ctx.tokens[{:shadow, name}], :deprecated, false)

  defp length_token(_ctx, t), do: val(t.name, "Dp", dp(t.value))

  defp radius_token(ctx, t),
    do: val(t.name, "#{ctx.m}Radius", radius(ctx, t.value, "radius #{inspect(t.name)}"))

  # The family's Android font, with the weight of each emphasis in it: the system font (its
  # monospaced one for a monospaced family), or a named font the device has, at each weight
  # of its scale.
  defp family_token(ctx, t) do
    emphases = for %{kind: :emphasis, name: e} <- ctx.design.tokens, do: e
    weights = for e <- emphases, do: Schema.weight(t, :android, e)

    font =
      case t.android do
        {:system, _} ->
          if t[:monospaced], do: "FontFamily.Monospace", else: "FontFamily.Default"

        font ->
          italic? = Enum.any?(font[:faces], &(&1[:style] == :italic))
          styles = if italic?, do: ["Normal", "Italic"], else: ["Normal"]

          faces =
            for w <- Enum.uniq(weights), style <- styles do
              ~s|Font(DeviceFontFamilyName("#{font[:name]}"), FontWeight(#{w}), FontStyle.#{style})|
            end

          {"FontFamily(", faces}
      end

    scale = for {e, w} <- Enum.zip(emphases, weights), do: "#{ident(e)} = #{w}"

    args =
      case font do
        {head, faces} -> [{"font = ", head, faces} | scale]
        font -> ["font = #{font}" | scale]
      end

    "        /** #{t.doc} */\n" <>
      fill(
        "        ",
        "public val #{ident(t.name)}: #{ctx.m}FontFamily = #{ctx.m}FontFamily(",
        args,
        ")"
      ) <>
      "\n"
  end

  defp typography_token(ctx, t) do
    {head, args} = typography_args(ctx, [font: t.font, text: t.text], "Families.")

    fill("        ", "public val #{ident(t.name)}: #{ctx.m}Typography = #{head}", args, ")") <>
      "\n"
  end

  # ------------------------------------------------------------ values

  @doc false
  # The Kotlin code of a property's value, for `<name>Look(…)`: `[{field, code}]`.
  def fields(ctx, key, value, where) do
    case key do
      k when k in [:background, :foreground, :placeholder, :track] ->
        [{camel(k), color(ctx, value)}]

      :border ->
        border(ctx, "border", value, where)

      :outline ->
        border(ctx, "outline", value, where)

      :radius ->
        [{"radius", radius_value(ctx, value, where)}]

      k when k in [:padding, :margin, :inset] ->
        [{Atom.to_string(k), insets(ctx, value, where)}]

      k when k in [:gap, :size, :width, :height, :min_height] ->
        [{camel(k), length(value, "#{where}: #{k}")}]

      :max_height ->
        [
          {"maxHeight",
           if(is_atom(value),
             do: "#{ctx.m}.MaxHeights.#{ident(value)}",
             else: length(value, where)
           )}
        ]

      :typography when is_atom(value) ->
        [{"typography", "#{ctx.m}.Typography.#{ident(value)}"}]

      :typography ->
        {head, args} = typography_args(ctx, value, "#{ctx.m}.Families.")
        [{"typography", {:call, head, args}}]

      :emphasis ->
        [{"emphasis", "#{ctx.m}Emphasis.#{pascal(value)}"}]

      :decoration ->
        [{"decoration", "#{ctx.m}Decoration.#{pascal(value)}"}]

      :shadow ->
        if deprecated?(ctx, value) and not is_atom(ctx.tokens[{:shadow, value}].value) do
          {head, args} = shadow_args(ctx, ctx.tokens[{:shadow, value}])
          [{"shadow", {:call, head, args}}]
        else
          [{"shadow", shadow(ctx, value)}]
        end

      :opacity ->
        [{"opacity", float(value)}]

      k when k in [:transition, :rotation] ->
        {ms, easing} = value
        [{Atom.to_string(k), "#{ctx.m}Motion(#{round(ms)}, #{ctx.m}Easing.#{pascal(easing)})"}]

      :stroke ->
        [{"stroke", stroke(ctx, value, where)}]
    end
  end

  defp border(ctx, name, value, where) do
    for {k, v} <- value do
      case k do
        :color -> {"#{name}Color", color(ctx, v)}
        :width -> {"#{name}Width", length(v, "#{where}: #{name}")}
        :offset -> {"#{name}Offset", length(v, "#{where}: #{name}")}
        :sides -> {"#{name}Sides", sides(ctx, v)}
      end
    end
  end

  # Sides as `MSides`: left and right are start and end, as for insets.
  defp sides(ctx, sides) do
    names = %{top: ["top"], bottom: ["bottom"], left: ["start"], right: ["end"]}
    names = Map.merge(names, %{x: names.left ++ names.right, y: names.top ++ names.bottom})
    on = sides |> Enum.flat_map(&names[&1]) |> Enum.uniq()
    "#{ctx.m}Sides(#{Enum.map_join(on, ", ", &"#{&1} = true")})"
  end

  defp insets(ctx, value, where) do
    sides =
      Enum.reduce(value, %{}, fn
        {:x, n}, acc -> Map.merge(acc, %{left: n, right: n})
        {:y, n}, acc -> Map.merge(acc, %{top: n, bottom: n})
        {side, n}, acc -> Map.put(acc, side, n)
      end)

    args =
      for {side, kotlin} <- [top: "top", left: "start", bottom: "bottom", right: "end"],
          Map.has_key?(sides, side),
          do: "#{kotlin} = #{length(sides[side], where)}"

    "#{ctx.m}Insets(#{Enum.join(args, ", ")})"
  end

  @doc false
  def color(_ctx, :transparent), do: "Color.Transparent"
  def color(_ctx, "#" <> hex), do: "Color(0xFF#{String.upcase(hex)})"
  def color(ctx, {ref, alpha}), do: "#{color(ctx, ref)}.copy(alpha = #{float(alpha)})"
  def color(ctx, name) when is_atom(name), do: "#{ctx.m}.Colors.#{ident(name)}"

  defp radius_value(ctx, name, _) when is_atom(name), do: "#{ctx.m}.Radii.#{ident(name)}"
  defp radius_value(ctx, value, where), do: radius(ctx, value, where)

  defp radius(ctx, {n, :percent}, where) do
    if n >= 50,
      do: "#{ctx.m}Radius.Full",
      else:
        raise(
          ArgumentError,
          "#{where}: a radius of #{number(n)}% depends on the box's sides; the Kotlin target writes a radius in percent only from 50% (a capsule)"
        )
  end

  defp radius(ctx, value, where), do: "#{ctx.m}Radius.Fixed(#{length(value, where)})"

  defp stroke(ctx, {n, :percent}, _), do: "#{ctx.m}Stroke.Fraction(#{float(n / 100)})"
  defp stroke(ctx, value, where), do: "#{ctx.m}Stroke.Fixed(#{length(value, where)})"

  defp length(n, _) when is_number(n), do: dp(n)
  defp length({n, :rem}, _), do: dp(n * 16)

  defp length({n, :percent}, where),
    do:
      raise(
        ArgumentError,
        "#{where}: #{number(n)}% has no size on Android; the Kotlin target writes percent only for a radius or a stroke"
      )

  defp typography_args(ctx, pair, families) do
    font = ctx.tokens[{:font, pair[:font]}]

    {size, line_height} =
      case pair[:text] do
        {size, line_height} -> {size, line_height}
        name -> {ctx.tokens[{:text, name}].size, ctx.tokens[{:text, name}].line_height}
      end

    {"#{ctx.m}Typography(",
     [
       "family = #{families}#{ident(font.family)}",
       "emphasis = #{ctx.m}Emphasis.#{pascal(font.emphasis)}",
       "italic = #{Map.get(font, :italic, false)}",
       "size = #{sp(size)}",
       "lineHeight = #{sp(line_height)}"
     ]}
  end

  # ------------------------------------------------------------ numbers

  @doc false
  def number(n) when is_float(n), do: n |> Float.round(4) |> Web.number()
  def number(n), do: Web.number(n)

  @doc false
  def dp(n), do: "#{number(n)}.dp"

  defp sp(n), do: "#{number(n)}.sp"

  @doc false
  # A Float literal: `0.5f`, `1f`.
  def float(n), do: "#{number(n)}f"

  # ------------------------------------------------------------ names

  @doc false
  # A design name in camelCase, with a keyword in backquotes.
  def ident(name) do
    name = camel(name)
    if name in @keywords, do: "`#{name}`", else: name
  end

  @doc false
  def camel(name) do
    [first | rest] = name |> to_string() |> String.split("_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end

  @doc false
  # A design name as a type or an enum's case: `rich_text` is `RichText`.
  def pascal(name), do: name |> to_string() |> Macro.camelize()

  defp lower_first(<<first::utf8, rest::binary>>), do: String.downcase(<<first::utf8>>) <> rest

  @doc false
  # A call on one line of `indent` and at most 100 columns, or its arguments one per
  # line, 4 deeper, each with a trailing comma, `tail` on a line of its own. An
  # argument may be a call itself, `{label, head, args}`, filled the same way when it
  # doesn't fit.
  def fill(indent, head, args, tail) do
    flat = Enum.map(args, &flat/1)
    one = indent <> head <> Enum.join(flat, ", ") <> tail

    if String.length(one) <= 100 or args == [] do
      one
    else
      inner = indent <> "    "

      lines =
        Enum.zip_with(args, flat, fn arg, text ->
          if String.length(inner <> text) + 1 > 100 and is_tuple(arg) do
            {label, head, args} = arg
            fill(inner, label <> head, args, ")") <> ","
          else
            inner <> text <> ","
          end
        end)

      indent <> head <> "\n" <> Enum.join(lines, "\n") <> "\n" <> indent <> tail
    end
  end

  defp flat({label, head, args}), do: label <> head <> Enum.map_join(args, ", ", &flat/1) <> ")"
  defp flat(text), do: text
end
