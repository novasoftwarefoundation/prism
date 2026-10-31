defmodule Prism.Generator.Web do
  @moduledoc """
  Generates a web package from a design: a Tailwind preset (`tailwind.preset.js`),
  base CSS (`css/base.css`: font faces and utilities) and, for a design with
  components, component CSS (`css/components.css`; the web mechanics of each
  component are in `Prism.Generator.Web.Components`).

  The templates in `web/` hold the web mechanics (the Tailwind plugin, the
  viewport, safe-area and scrollbar utilities, line clamps); every design value
  comes from the design's tokens, and names and comments from its `web` declaration.
  Fonts come from each family's `web:` binding only.

  The spelling is fixed, so regenerating gives the same bytes:
  upper-case hex and two-decimal alphas in the preset, `0` in box shadows and
  `0px` in text shadows, and `@font-face` sources wrapped at 80 columns.
  """

  require EEx

  alias Prism.Generator.Web.Components

  @dir Path.join(__DIR__, "web")
  @external_resource Path.join(@dir, "tailwind.preset.js.eex")
  @external_resource Path.join(@dir, "base.css.eex")

  EEx.function_from_file(:defp, :preset_js, Path.join(@dir, "tailwind.preset.js.eex"), [
    :design,
    :web
  ])

  EEx.function_from_file(:defp, :base_css, Path.join(@dir, "base.css.eex"), [:design, :web])

  @doc """
  The files of the web target for a design's `__schema__/0`, as
  `[{path, body, design_file}]`: paths relative to the target's folder, and the
  design file each body is made from (the tokens' file for the preset and base
  CSS, the design's own file for the component CSS). `mix prism.gen` puts a
  `Prism.Generator.Header` line naming that file above each body.
  """
  def files(%{tokens: tokens, web: web} = design) do
    unless web, do: raise(ArgumentError, "the design has no `web` declaration")

    components =
      case design.components do
        [] -> []
        _ -> [{"css/components.css", Components.css(design), design.file}]
      end

    [
      {"tailwind.preset.js", preset_js(tokens, web), design.tokens_file},
      {"css/base.css", base_css(tokens, web), design.tokens_file}
    ] ++ components
  end

  # ------------------------------------------------------------- tokens

  defp tokens(design, kind), do: for(%{kind: ^kind} = t <- design, do: t)

  defp token(design, kind, name),
    do: Enum.find(tokens(design, kind), &(&1.name == name)) || raise("no #{kind} #{name}")

  # Follows aliases to the value.
  defp resolve(design, kind, name) do
    case token(design, kind, name).value do
      ref when is_atom(ref) -> resolve(design, kind, ref)
      value -> value
    end
  end

  # JS object keys: bare when they're identifiers, quoted otherwise.
  defp key(name) when is_integer(name), do: Integer.to_string(name)

  defp key(name) do
    key = name |> to_string() |> String.replace("_", "-")
    if key =~ ~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, do: key, else: js_str(key)
  end

  # Groups as `// comment` blocks; `blank` puts an empty line between groups.
  defp js_groups(design, kind, indent, blank, line_fun) do
    pad = String.duplicate(" ", indent)

    tokens(design, kind)
    |> Enum.chunk_by(& &1.group)
    |> Enum.map(fn [first | _] = group ->
      comment = if first.group, do: ["#{pad}// #{comment!(first.group)}\n"], else: []
      [comment | Enum.map(group, &"#{pad}#{line_fun.(&1)}\n")]
    end)
    |> Enum.intersperse(if(blank, do: "\n", else: []))
    |> IO.iodata_to_binary()
    |> String.trim_trailing("\n")
  end

  defp preset_colors(design),
    do:
      js_groups(
        design,
        :color,
        6,
        true,
        &"#{key(&1.name)}: #{js_str(resolve(design, :color, &1.name))},"
      )

  defp preset_shadows(design) do
    js_groups(design, :shadow, 8, false, fn t ->
      css = shadow_css(design, resolve(design, :shadow, t.name), zero: "0", alpha: 2)
      "#{key(t.name)}: #{js_str(css)},"
    end)
  end

  defp px_lines(design, kind, key_fun),
    do:
      Enum.map_join(
        tokens(design, kind),
        "\n",
        &"        #{key(key_fun.(&1))}: #{js_str("#{&1.value}px")},"
      )

  defp preset_spacing(design), do: px_lines(design, :space, & &1.key)
  defp preset_heights(design), do: px_lines(design, :height, & &1.key)
  defp preset_max_heights(design), do: px_lines(design, :max_height, & &1.name)

  defp preset_text_sizes(design) do
    Enum.map_join(
      tokens(design, :text),
      "\n",
      &"        #{key(&1.name)}: [#{js_str("#{&1.size}px")}, #{js_str("#{&1.line_height}px")}],"
    )
  end

  # Fonts in runs of the same family, each run under the family's comment.
  defp by_family(design, fun) do
    tokens(design, :font)
    |> Enum.chunk_by(& &1.family)
    |> Enum.map_join("\n", fn [first | _] = fonts ->
      family = token(design, :family, first.family).web

      "        // #{comment!(family_note(family, first.family, design))}\n" <>
        Enum.map_join(fonts, "\n", &fun.(&1, family))
    end)
  end

  defp preset_font_families(design) do
    by_family(design, fn font, family ->
      "        #{key(font.name)}: [#{js_str(family[:name])}, #{js_str(family[:fallback])}],"
    end)
  end

  defp preset_font_classes(design) do
    by_family(design, fn font, family ->
      italic = if font[:italic], do: ~s(\n          "font-style": "italic",), else: ""

      """
              #{js_str(".font-#{key_name(font.name)}")}: {
                "font-family": #{js_str("#{family[:name]}, #{family[:fallback]}")},
                "font-weight": #{js_str("#{font.weight}")},#{italic}
              },\
      """
    end)
  end

  defp key_name(name), do: name |> to_string() |> String.replace("_", "-")

  defp font_faces(design) do
    for family <- tokens(design, :family), web = family.web, face <- web[:faces] do
      {from, to} = face[:weights]

      %{
        family: web[:name],
        sizes: sizes(family.doc),
        file: face[:file],
        weights: "#{from} #{to}",
        style: face[:style],
        first: face == hd(web[:faces])
      }
    end
  end

  # A family's size range: "Headings (> 20px)" → "> 20px", or nil.
  defp sizes(doc) do
    case Regex.run(~r/\(([^()]+)\)$/, doc) do
      [_, sizes] -> sizes
      nil -> nil
    end
  end

  # The preset's comment above a family's fonts: "Acme Sans (> 20px sizes)".
  defp family_note(web, name, design) do
    case sizes(token(design, :family, name).doc) do
      nil -> web[:name]
      sizes -> "#{web[:name]} (#{sizes} sizes)"
    end
  end

  # base.css's comment above a family's faces: "Acme Sans - Variable font for sizes > 20px".
  defp face_note(%{family: family, sizes: nil}), do: "#{family} - Variable font"

  defp face_note(%{family: family, sizes: sizes}),
    do: "#{family} - Variable font for sizes #{sizes}"

  # Wrapped like prettier does at 80 columns.
  defp font_src(face, web) do
    url = "url(#{css_str("#{web.fonts_url}/#{face.file}.woff2")})"
    line = ~s{  src: #{url} format("woff2-variations");}

    if String.length(line) > 81,
      do: ~s{  src: #{url}\n    format("woff2-variations");},
      else: line
  end

  # `.<prefix>-text-shadow` for :default, `.<prefix>-text-shadow-<name>` for the others.
  defp text_shadows(design, web) do
    for t <- tokens(design, :text_shadow) do
      class =
        if t.name == :default,
          do: "#{web.prefix}-text-shadow",
          else: "#{web.prefix}-text-shadow-#{key_name(t.name)}"

      {class, shadow_css(design, t.value, zero: "0px", spread: false)}
    end
  end

  # ------------------------------------------------------------ values

  # A shadow: [inset:, x:, y:, blur:, spread:, color: {color, alpha}]. `zero` is how 0 is
  # written; `alpha: 2` writes the alpha with two decimals (the preset's style).
  @doc false
  def shadow_css(design, shadow, opts) do
    zero = Keyword.fetch!(opts, :zero)
    length = fn n -> if n == 0, do: zero, else: "#{n}px" end
    {color, alpha} = shadow[:color]
    {r, g, b} = rgb(resolve(design, :color, color))

    alpha =
      if opts[:alpha],
        do: :erlang.float_to_binary(alpha / 1, decimals: opts[:alpha]),
        else: number(alpha)

    lengths =
      [shadow[:x] || 0, shadow[:y] || 0, shadow[:blur] || 0] ++
        if(opts[:spread] == false, do: [], else: [shadow[:spread] || 0])

    inset = if shadow[:inset], do: "inset ", else: ""
    "#{inset}#{Enum.map_join(lengths, " ", length)} rgba(#{r}, #{g}, #{b}, #{alpha})"
  end

  # Design text is checked by the schema; these keep the generated files well-formed for
  # any data a generator is given.
  defp js_str(text) do
    escaped =
      for <<c::utf8 <- text>>, into: "" do
        case c do
          ?" -> ~S(\")
          ?\\ -> ~S(\\)
          c when c < 0x20 or c in [0x7F, 0x2028, 0x2029] -> "\\u" <> hex4(c)
          c -> <<c::utf8>>
        end
      end

    ~s("#{escaped}")
  end

  @doc false
  def css_str(text) do
    escaped =
      for <<c::utf8 <- text>>, into: "" do
        case c do
          ?" -> ~S(\")
          ?\\ -> ~S(\\)
          c when c < 0x20 or c == 0x7F -> "\\" <> Integer.to_string(c, 16) <> " "
          c -> <<c::utf8>>
        end
      end

    ~s("#{escaped}")
  end

  defp hex4(c), do: c |> Integer.to_string(16) |> String.pad_leading(4, "0")

  # A `/** … */` block, then an empty line; nothing without a doc.
  @doc false
  def doc_block(nil), do: ""

  def doc_block(doc) do
    if String.contains?(doc, "*/"), do: raise(ArgumentError, "#{inspect(doc)} contains */")

    lines =
      doc
      |> String.trim_trailing("\n")
      |> String.split("\n")
      |> Enum.map_join(fn
        "" -> " *\n"
        line -> " * #{line}\n"
      end)

    "/**\n#{lines} */\n\n"
  end

  # A `// comment` line in the preset's plugin; nothing without a doc.
  defp line_comment(nil, _indent), do: ""
  defp line_comment(doc, indent), do: "#{String.duplicate(" ", indent)}// #{comment!(doc)}\n"

  # Text in a `//` or `/* */` comment: it can't be escaped, so it must be one line.
  defp comment!(text) do
    if String.contains?(text, "*/") or Regex.match?(~r/[\x{0}-\x{1F}\x{2028}\x{2029}]/u, text),
      do: raise(ArgumentError, "#{inspect(text)} can't be written in a comment")

    text
  end

  @doc false
  def rgb("#" <> hex) do
    <<r::8, g::8, b::8>> = Base.decode16!(hex, case: :mixed)
    {r, g, b}
  end

  @doc false
  def number(n) when is_integer(n), do: Integer.to_string(n)
  def number(n) when n == trunc(n), do: Integer.to_string(trunc(n))
  def number(n), do: Float.to_string(n)
end
