defmodule Prism.Generator.Swift do
  @moduledoc """
  Generates a Swift package from a design: SwiftUI code for iOS with the
  design's tokens and one SwiftUI form per component. The design's `swift`
  declaration names the package (`module:`), which is also the prefix of its
  types: `swift module: "Acme"` gives `Acme.Colors.accent` and
  `AcmeButtonStyle`.

  The files, under the target's folder:

  - `Package.swift`: one library of the module's name, for iOS 26, Swift tools
    6.2;
  - `Sources/<module>/Tokens.swift`: the tokens in an enum of the module's
    name: `Colors` (`Color`), `Shadows` and `TextShadows`, `Spacing`,
    `Heights` and `MaxHeights` (`CGFloat`, points), `Radii`, `Families` and
    `Typography`. Names are camelCase (`Shadows.btnPressed`), with Swift's
    keywords in backquotes;
  - `Sources/<module>/Look.swift`: the types the tokens and components are
    made of, among them `<module>Look`, a look as data, and the modifiers
    that draw one (`<lower>Text`, `<lower>Box`, `<lower>Look`);
  - `Sources/<module>/<Component>.swift`: one file per component, see
    `Prism.Generator.Swift.Components`;
  - for a design whose families bind iOS to named fonts:
    `Sources/<module>/Fonts.swift`, which registers them, and their files in
    `Sources/<module>/Fonts/`, copied from the `swift` declaration's
    `fonts:` folder, with its `font_files:`.

  ## Values

  Lengths are points: px as they are, rem times 16. A length in percent is
  only a radius of 50% or more (a capsule, a circle on a square) or a stroke
  (a fraction of the box it is drawn in); anything else fails generation.
  Colors are sRGB. A shadow's blur is CSS's, half of it SwiftUI's radius; a
  shadow with a spread fails generation, since SwiftUI's shadows have none.
  Sides are leading and trailing for the design's left and right, so they
  follow the text's direction.

  ## Type

  Type comes only from the typography tokens and the components' typography
  pairs. A typography is its font's family as `ios:` binds it (`:system` is
  the system font), its weight and italic, and its size and line height in
  points. Dynamic Type scales the size and the line height as the text style
  whose default size is the closest below it: text up to 20 pt as body text
  (body 17, callout 16, subheadline 15, footnote 13, caption 12, caption 2
  11), larger text as a title (title 3 20, title 2 22, title 28, large title
  34). So 18 and 20 pt scale as body, 14 as footnote, 24 as title 2.
  """

  alias Prism.Generator.Swift.Components
  alias Prism.Generator.Web

  require EEx

  EEx.function_from_file(:defp, :look_swift, Path.join(__DIR__, "swift/look.swift.eex"), [
    :assigns
  ])

  @font_types ~w(.ttf .otf .woff2)

  @keywords ~w(associatedtype class deinit enum extension fileprivate func import init inout
               internal let open operator private precedencegroup protocol public rethrows static
               struct subscript typealias var break case catch continue default defer do else
               fallthrough for guard if in repeat return throw switch where while Any as await
               false is nil self Self super throws true try none)

  # The text styles Dynamic Type scales by, with their default sizes: body text up to
  # 20 pt, titles above.
  @body_styles [body: 17, callout: 16, subheadline: 15, footnote: 13, caption: 12, caption2: 11]
  @title_styles [largeTitle: 34, title: 28, title2: 22, title3: 20]

  @doc """
  The files of the Swift target for a design's `__schema__/0`, as
  `[{path, body, design_file}]`; a copied font's body is `{:copy, source}`.
  """
  def files(design) do
    swift =
      design.swift ||
        raise ArgumentError, "the Swift target needs the design's swift declaration (module:)"

    ctx = context(design, swift)
    fonts = fonts(ctx)
    dir = "Sources/#{ctx.m}"

    generated =
      [
        {"Package.swift", package(ctx, fonts != []), design.tokens_file},
        {"#{dir}/Tokens.swift", tokens(ctx), design.tokens_file},
        {"#{dir}/Look.swift", look(ctx, fonts != []), design.tokens_file}
      ] ++
        if(fonts == [],
          do: [],
          else: [{"#{dir}/Fonts.swift", fonts_swift(ctx, fonts), design.tokens_file}]
        ) ++
        for {name, body} <- Components.files(design, ctx),
            do: {"#{dir}/#{name}.swift", body, design.file}

    copies =
      for file <- fonts ++ swift.font_files,
          do: {"#{dir}/Fonts/#{file}", {:copy, Path.join(swift.fonts, file)}, design.tokens_file}

    generated ++ copies
  end

  defp context(design, swift) do
    tokens = Map.new(design.tokens, &{{&1.kind, &1.name}, &1})
    %{m: swift.module, lower: lower_first(swift.module), tokens: tokens, design: design}
  end

  # ------------------------------------------------------------ the package

  defp package(ctx, fonts?) do
    target =
      if fonts?,
        do: ~s|.target(name: "#{ctx.m}", resources: [.copy("Fonts")])|,
        else: ~s|.target(name: "#{ctx.m}")|

    """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "#{ctx.m}",
        platforms: [.iOS(.v26)],
        products: [
            .library(name: "#{ctx.m}", targets: ["#{ctx.m}"])
        ],
        targets: [
            #{target}
        ]
    )
    """
  end

  defp look(ctx, fonts?), do: look_swift(%{m: ctx.m, lower: ctx.lower, fonts: fonts?})

  # The font files a family's iOS binding names, in the design's order.
  defp fonts(ctx) do
    files =
      for %{kind: :family, ios: ios} = f <- ctx.design.tokens,
          is_list(ios),
          face <- ios[:faces] do
        unless Path.extname(face[:file]) in @font_types,
          do:
            raise(
              ArgumentError,
              "family #{inspect(f.name)}: ios: the face #{inspect(face[:file])} needs its file's extension, one of #{Enum.join(@font_types, ", ")}"
            )

        face[:file]
      end

    if files != [] and ctx.design.swift.fonts == nil,
      do:
        raise(
          ArgumentError,
          "a family binds iOS to a named font: the swift declaration needs fonts:, the folder its files are in"
        )

    Enum.uniq(files)
  end

  defp fonts_swift(ctx, files) do
    list = Enum.map_join(files, ",\n", &~s(        "#{&1}"))

    """
    import CoreText
    import Foundation

    /// The fonts the package bundles, registered for the app's process the first time a
    /// typography needs one, so the app lists none in its Info.plist.
    enum #{ctx.m}Fonts {
        static let files = [
    #{list},
        ]

        private static let registered: Bool = {
            for file in files {
                if let url = Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Fonts") {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
            return true
        }()

        static func register() {
            _ = registered
        }
    }
    """
  end

  # ------------------------------------------------------------ the tokens

  defp tokens(ctx) do
    groups = [
      {"Colors", "The colors.", :color, &color_token/2},
      {"Shadows", "The shadows.", :shadow, &shadow_token/2},
      {"TextShadows", "The text shadows.", :text_shadow, &shadow_token/2},
      {"Spacing", "The spacing steps, in points.", :space, &length_token/2},
      {"Heights", "The height steps, in points.", :height, &length_token/2},
      {"MaxHeights", "The maximum heights, in points.", :max_height, &length_token/2},
      {"Radii", "The corner radii.", :radius, &radius_token/2},
      {"Families", "The font families, as iOS binds them.", :family, &family_token/2},
      {"Typography", "The typography tokens.", :typography, &typography_token/2}
    ]

    enums =
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

        "    /// #{doc}\n    public enum #{name} {\n#{lines}    }\n"
      end

    """
    import SwiftUI

    /// The design's tokens. Lengths are points.
    public enum #{ctx.m} {
    #{Enum.join(enums, "\n")}}
    """
  end

  defp static(name, value, doc \\ nil) do
    doc = if doc, do: "        /// #{doc}\n", else: ""
    "#{doc}        public static let #{ident(name)} = #{value}\n"
  end

  defp color_token(ctx, %{name: name, value: value}),
    do: static(name, if(is_atom(value), do: ident(value), else: color(ctx, value)))

  defp shadow_token(_ctx, %{value: ref} = t) when is_atom(ref),
    do: static(t.name, ident(ref), deprecated(t))

  defp shadow_token(ctx, %{value: value} = t) do
    if Keyword.get(value, :spread, 0) != 0,
      do:
        raise(
          ArgumentError,
          "#{t.kind} #{inspect(t.name)}: SwiftUI's shadows have no spread, so the Swift target can't write it"
        )

    fields =
      [color: color(ctx, value[:color])] ++
        for(
          key <- [:x, :y, :blur],
          (n = Keyword.get(value, key, 0)) != 0,
          do: {key, number(n)}
        ) ++ if(value[:inset], do: [inset: "true"], else: [])

    args = Enum.map(fields, fn {k, v} -> "#{k}: #{v}" end)
    doc = if deprecated(t), do: "        /// #{deprecated(t)}\n", else: ""

    doc <>
      fill("        ", "public static let #{ident(t.name)} = #{ctx.m}Shadow(", args, ")") <> "\n"
  end

  defp deprecated(t), do: if(Map.get(t, :deprecated), do: "Deprecated.")

  defp length_token(_ctx, t),
    do: "        public static let #{ident(t.name)}: CGFloat = #{number(t.value)}\n"

  defp radius_token(ctx, t),
    do: static(t.name, "#{ctx.m}Radius" <> radius(ctx, t.value, "radius #{inspect(t.name)}"))

  defp family_token(ctx, t) do
    value =
      case t.ios do
        :system -> "#{ctx.m}FontFamily.system"
        font -> "#{ctx.m}FontFamily.named(\"#{font[:name]}\")"
      end

    static(t.name, value, t.doc)
  end

  defp typography_token(ctx, t) do
    {head, args} = typography_args(ctx, [font: t.font, text: t.text], "Families.")
    fill("        ", "public static let #{ident(t.name)} = #{head}", args, ")") <> "\n"
  end

  # ------------------------------------------------------------ values

  @doc false
  # The Swift code of a property's value, for `<module>Look(…)`: `[{field, code}]`.
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

      k when k in [:gap, :size, :height, :min_height] ->
        [{camel(k), length(value, "#{where}: #{k}")}]

      :max_height ->
        [
          {"maxHeight",
           if(is_atom(value),
             do: "#{ctx.m}.MaxHeights.#{member(value)}",
             else: length(value, where)
           )}
        ]

      :typography when is_atom(value) ->
        [{"typography", typography(ctx, value, "#{ctx.m}.Families.")}]

      :typography ->
        {head, args} = typography_args(ctx, value, "#{ctx.m}.Families.")
        [{"typography", {:call, head, args}}]

      :weight ->
        [{"weight", Integer.to_string(value)}]

      :decoration ->
        [{"decoration", "#{ctx.m}Decoration.#{value}"}]

      :shadow ->
        [{"shadow", "#{ctx.m}.Shadows.#{member(value)}"}]

      :opacity ->
        [{"opacity", number(value)}]

      k when k in [:transition, :rotation] ->
        {ms, easing} = value

        [
          {Atom.to_string(k),
           "#{ctx.m}Motion(duration: #{number(ms / 1000)}, easing: .#{camel(easing)})"}
        ]

      :stroke ->
        [{"stroke", stroke(value, where)}]
    end
  end

  defp border(ctx, name, value, where) do
    for {k, v} <- value do
      case k do
        :color -> {"#{name}Color", color(ctx, v)}
        :width -> {"#{name}Width", length(v, "#{where}: #{name}")}
        :offset -> {"#{name}Offset", length(v, "#{where}: #{name}")}
      end
    end
  end

  defp insets(_ctx, value, where) do
    sides =
      Enum.reduce(value, %{}, fn
        {:x, n}, acc -> Map.merge(acc, %{left: n, right: n})
        {:y, n}, acc -> Map.merge(acc, %{top: n, bottom: n})
        {side, n}, acc -> Map.put(acc, side, n)
      end)

    args =
      for {side, swift} <- [top: "top", left: "leading", bottom: "bottom", right: "trailing"],
          Map.has_key?(sides, side),
          do: "#{swift}: #{length(sides[side], where)}"

    ".init(#{Enum.join(args, ", ")})"
  end

  @doc false
  def color(_ctx, :transparent), do: "Color.clear"
  def color(ctx, "#" <> hex), do: "Color(#{ctx.lower}Hex: 0x#{hex})"
  def color(ctx, {ref, alpha}), do: "#{color(ctx, ref)}.opacity(#{number(alpha)})"
  def color(ctx, name) when is_atom(name), do: "#{ctx.m}.Colors.#{member(name)}"

  defp radius_value(ctx, name, _) when is_atom(name), do: "#{ctx.m}.Radii.#{member(name)}"
  defp radius_value(ctx, value, where), do: radius(ctx, value, where)

  defp radius(_ctx, {n, :percent}, where) do
    if n >= 50,
      do: ".capsule",
      else:
        raise(
          ArgumentError,
          "#{where}: a radius of #{number(n)}% depends on the box's sides; the Swift target writes a radius in percent only from 50% (a capsule)"
        )
  end

  defp radius(_ctx, value, where), do: ".points(#{length(value, where)})"

  defp stroke({n, :percent}, _), do: ".fraction(#{number(n / 100)})"
  defp stroke(value, where), do: ".points(#{length(value, where)})"

  defp length(n, _) when is_number(n), do: number(n)
  defp length({n, :rem}, _), do: number(n * 16)

  defp length({n, :percent}, where),
    do:
      raise(
        ArgumentError,
        "#{where}: #{number(n)}% has no size on iOS; the Swift target writes percent only for a radius or a stroke"
      )

  # A typography: a token's name, or a font and a text size (a token's name or
  # `{size, line_height}`).
  defp typography(ctx, name, _families) when is_atom(name),
    do: "#{ctx.m}.Typography.#{member(name)}"

  defp typography(ctx, pair, families) do
    {head, args} = typography_args(ctx, pair, families)
    head <> Enum.join(args, ", ") <> ")"
  end

  defp typography_args(ctx, pair, families) do
    font = ctx.tokens[{:font, pair[:font]}]

    {size, line_height} =
      case pair[:text] do
        {size, line_height} -> {size, line_height}
        name -> {ctx.tokens[{:text, name}].size, ctx.tokens[{:text, name}].line_height}
      end

    {"#{ctx.m}Typography(",
     [
       "family: #{families}#{member(font.family)}",
       "weight: #{font.weight}",
       "italic: #{Map.get(font, :italic, false)}",
       "size: #{number(size)}",
       "lineHeight: #{number(line_height)}",
       "textStyle: .#{text_style(size)}"
     ]}
  end

  @doc """
  The text style Dynamic Type scales a size by: the one whose default size is the
  closest below it, a body style up to 20 pt and a title above.
  """
  def text_style(size) do
    styles = if size <= 20, do: @body_styles, else: @title_styles
    smallest = styles |> Enum.min_by(&elem(&1, 1)) |> elem(0)

    styles
    |> Enum.filter(fn {_, default} -> default <= size end)
    |> Enum.max_by(&elem(&1, 1), fn -> {smallest, 0} end)
    |> elem(0)
  end

  # ------------------------------------------------------------ names

  @doc false
  def number(n) when is_float(n), do: n |> Float.round(4) |> Web.number()
  def number(n), do: Web.number(n)

  @doc false
  # A design name in camelCase, with a keyword in backquotes.
  def ident(name), do: name |> camel() |> escape()

  @doc false
  # A call on one line of `indent` and at most 100 columns, or its arguments filled
  # into lines of their own, 4 deeper, `tail` after the last. An argument may be a
  # call itself, `{label, head, args}`, filled the same way when it doesn't fit.
  def fill(indent, head, args, tail) do
    flat = Enum.map(args, &flat/1)
    one = indent <> head <> Enum.join(flat, ", ") <> tail

    if String.length(one) <= 100 or args == [] do
      one
    else
      inner = indent <> "    "

      lines =
        args
        |> Enum.zip(flat)
        |> Enum.reduce([], fn {arg, text}, lines ->
          text =
            if String.length(inner <> text) + 1 > 100 and is_tuple(arg) do
              {label, head, args} = arg
              inner |> fill(label <> head, args, ")") |> String.trim_leading()
            else
              text
            end

          case lines do
            [] ->
              [inner <> text]

            [line | rest] ->
              if not String.contains?(line <> text, "\n") and
                   String.length(line) + 2 + String.length(text) + 1 <= 100,
                 do: [line <> ", " <> text | rest],
                 else: [inner <> text, line <> "," | rest]
          end
        end)

      indent <> head <> "\n" <> Enum.join(Enum.reverse(lines), "\n") <> tail
    end
  end

  defp flat({label, head, args}), do: label <> head <> Enum.map_join(args, ", ", &flat/1) <> ")"
  defp flat(text), do: text

  @doc false
  # A design name after a dot, where Swift takes a keyword as it is.
  def member(name) do
    name = camel(name)
    if name in ~w(self Self Type Protocol init), do: "`#{name}`", else: name
  end

  @doc false
  def camel(name) do
    [first | rest] = name |> to_string() |> String.split("_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end

  @doc false
  def pascal(name), do: name |> to_string() |> Macro.camelize()

  @doc false
  def escape(name), do: if(name in @keywords, do: "`#{name}`", else: name)

  defp lower_first(<<first::utf8, rest::binary>>), do: String.downcase(<<first::utf8>>) <> rest
end
