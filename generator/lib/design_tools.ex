defmodule Prism.Generator.DesignTools do
  @moduledoc """
  Generates files for design tools from a design: the tokens in the W3C
  Design Tokens (DTCG) format 2025.10 (`tokens.json`), the same tokens as CSS
  custom properties (`tokens.css`), and an overview of the tokens and the
  components as an SVG (`overview.svg`, `Prism.Generator.DesignTools.Overview`).

  ## Names

  Both token files name a token by one rule: a DTCG path of a group per kind
  and the token's name, with `-` for `_` (`color.primary`), and as a custom
  property the path joined by `-` after the web prefix
  (`--acme-color-primary`). The groups, in the files' order:

  | Group | DTCG `$type` | From | CSS value |
  |---|---|---|---|
  | `color` | `color` | colors; an alias is a reference | `#RRGGBB`, or `var(…)` for an alias |
  | `font-family` | `fontFamily` | families: the web font's name | the name and its fallback |
  | `font-weight` | `fontWeight` | fonts: their weight, with the family | the weight |
  | `font-size`, `line-height` | `dimension` | text sizes | px |
  | `typography` | `typography` | typography tokens, referring to the four groups above | the `font` shorthand, of `var(…)`s |
  | `spacing`, `height` | `dimension` | spacing and height steps, under their web key (`2px`, `15`) | px |
  | `max-height`, `radius` | `dimension` | maximum heights and radii | px or rem, or % for a radius |
  | `shadow` | `shadow` | shadows; an alias is a reference | the `box-shadow` value |
  | `text-shadow` | `shadow` | text shadows, with a spread of 0 | the `text-shadow` value |

  Each value is one flat value but a typography's or a shadow's, so a tool
  maps a color, a size or a family to one of its variables.

  ## What the DTCG file holds besides values

  - Data no DTCG type has goes under `$extensions`, in a `prism` key: a
    family's fallback and its iOS and Android binding (`"system"` or
    `{"name": …}`), a font's family (a reference) and `italic`, and a
    typography token's `fontStyle` when its font is italic.
  - A deprecated shadow has `$deprecated: true`.
  - A length in percent has no DTCG unit, so such a radius is only in
    `tokens.css`.
  - A typography's `lineHeight` is a number, a multiple of its font size, as
    the format has it; `letterSpacing`, which the format requires, is 0.
  """

  alias Prism.Generator.DesignTools.Overview
  alias Prism.Generator.Web

  @extension "prism"

  # The groups of the token files, in their order.
  @groups ~w(color font-family font-weight font-size line-height typography spacing height
             max-height radius shadow text-shadow)

  @doc """
  The files of the design-tools target for a design's `__schema__/0`, as
  `[{path, body, design_file}]`: the token files are made from the tokens'
  file, the overview from the design's own file.
  """
  def files(%{web: web} = design) do
    unless web,
      do: raise(ArgumentError, "the design has no `web` declaration, which names its tokens")

    tokens = tokens(design.tokens)

    [
      {"tokens.json", json(tokens), design.tokens_file},
      {"tokens.css", css(tokens, web.prefix), design.tokens_file},
      {"overview.svg", Overview.svg(design), design.file}
    ]
  end

  # ------------------------------------------------------------ the tokens

  @doc false
  # The design's tokens in the files' order, each as
  # `%{path, type, value, group, description, deprecated, extensions}`, `value` being
  # `{:ref, path}` or the kind's own data. Paths must be unique once joined by `-`.
  def tokens(tokens) do
    by_kind = Enum.group_by(tokens, & &1.kind)
    of = &Map.get(by_kind, &1, [])
    colors = Map.new(of.(:color), &{&1.name, &1.value})

    list =
      Enum.map(of.(:color), &color/1) ++
        Enum.map(of.(:family), &family/1) ++
        Enum.map(of.(:font), &font/1) ++
        Enum.map(of.(:text), &token(["font-size", &1.name], "dimension", {:px, &1.size}, &1)) ++
        Enum.map(
          of.(:text),
          &token(["line-height", &1.name], "dimension", {:px, &1.line_height}, &1)
        ) ++
        Enum.map(of.(:typography), &typography(&1, tokens)) ++
        Enum.map(of.(:space), &token(["spacing", &1.key], "dimension", {:px, &1.value}, &1)) ++
        Enum.map(of.(:height), &token(["height", &1.key], "dimension", {:px, &1.value}, &1)) ++
        Enum.map(
          of.(:max_height),
          &token(["max-height", &1.name], "dimension", {:px, &1.value}, &1)
        ) ++
        Enum.map(
          of.(:radius),
          &token(["radius", &1.name], "dimension", dtcg_length(&1.value), &1)
        ) ++
        Enum.map(of.(:shadow), &shadow("shadow", &1, colors)) ++
        Enum.map(of.(:text_shadow), &shadow("text-shadow", &1, colors))

    list = Enum.map(list, fn t -> %{t | path: Enum.map(t.path, &segment/1)} end)

    list
    |> Enum.group_by(&Enum.join(&1.path, "-"))
    |> Enum.each(fn
      {_, [_]} ->
        :ok

      {name, same} ->
        raise ArgumentError,
              "#{Enum.map_join(same, " and ", &Enum.join(&1.path, "."))} have one CSS name, #{name}"
    end)

    list
  end

  defp token(path, type, value, t, extra \\ %{}) do
    Map.merge(
      %{
        path: path,
        type: type,
        value: value,
        group: t.group,
        description: nil,
        deprecated: false,
        extensions: []
      },
      extra
    )
  end

  defp color(%{value: ref} = t) when is_atom(ref),
    do: token(["color", t.name], "color", {:ref, ["color", ref]}, t)

  defp color(t), do: token(["color", t.name], "color", {:color, t.value, 1}, t)

  defp family(t) do
    web = t.web

    token(["font-family", t.name], "fontFamily", {:family, web[:name], web[:fallback]}, t, %{
      description: t.doc,
      extensions: [fallback: web[:fallback], ios: native(t.ios), android: native(t.android)]
    })
  end

  defp native(:system), do: "system"
  defp native(font), do: [name: font[:name]]

  defp font(t) do
    italic = if t[:italic], do: [italic: true], else: []

    token(["font-weight", t.name], "fontWeight", {:number, t.weight}, t, %{
      extensions: [family: {:ref, ["font-family", t.family]}] ++ italic
    })
  end

  defp typography(t, tokens) do
    font = Enum.find(tokens, &(&1.kind == :font and &1.name == t.font))
    text = Enum.find(tokens, &(&1.kind == :text and &1.name == t.text))

    value =
      {:typography,
       [
         family: ["font-family", font.family],
         weight: ["font-weight", font.name],
         size: ["font-size", text.name],
         line_height: ["line-height", text.name],
         ratio: text.line_height / text.size,
         italic: font[:italic] == true
       ]}

    style = if font[:italic], do: [fontStyle: "italic"], else: []
    token(["typography", t.name], "typography", value, t, %{extensions: style})
  end

  defp shadow(group, %{value: ref} = t, _colors) when is_atom(ref),
    do: token([group, t.name], "shadow", {:ref, [group, ref]}, t, deprecated(t))

  # A shadow's color has its own alpha, so it is a value, not a reference.
  defp shadow(group, t, colors) do
    {color, alpha} = t.value[:color]
    hex = hex(colors, color)

    value =
      {:shadow, group,
       [
         x: t.value[:x] || 0,
         y: t.value[:y] || 0,
         blur: t.value[:blur] || 0,
         spread: t.value[:spread] || 0,
         inset: t.value[:inset] || false,
         color: {:color, hex, alpha}
       ]}

    token([group, t.name], "shadow", value, t, deprecated(t))
  end

  defp deprecated(t), do: %{deprecated: Map.get(t, :deprecated, false)}

  defp dtcg_length(n) when is_number(n), do: {:px, n}
  defp dtcg_length({n, :rem}), do: {:rem, n}
  defp dtcg_length({n, :percent}), do: {:percent, n}

  defp segment(name) when is_atom(name), do: name |> Atom.to_string() |> String.replace("_", "-")
  defp segment(name) when is_integer(name), do: Integer.to_string(name)
  defp segment(name) when is_binary(name), do: String.replace(name, "_", "-")

  # Follows color aliases to the hex value.
  defp hex(colors, name) do
    case Map.fetch!(colors, name) do
      ref when is_atom(ref) -> hex(colors, ref)
      hex -> hex
    end
  end

  # -------------------------------------------------------------- tokens.json

  @doc false
  def json(tokens) do
    # A length in percent has no DTCG unit.
    tokens = Enum.reject(tokens, &match?({:percent, _}, &1.value))

    tree =
      for group <- @groups,
          members = for(t <- tokens, hd(t.path) == group, do: t),
          members != [] do
        {group, Enum.map(members, &{List.last(&1.path), json_token(&1)})}
      end

    case tree do
      # No tokens: an empty object, on two lines like any other, for the header.
      [] -> "{\n}\n"
      _ -> encode({:object, Enum.map(tree, fn {g, ms} -> {g, {:object, ms}} end)}, 0) <> "\n"
    end
  end

  defp json_token(t) do
    {:object,
     [{"$type", t.type}, {"$value", json_value(t.value)}] ++
       if(t.description, do: [{"$description", t.description}], else: []) ++
       if(t.deprecated, do: [{"$deprecated", true}], else: []) ++
       case t.extensions do
         [] -> []
         ext -> [{"$extensions", {:object, [{@extension, json_extensions(ext)}]}}]
       end}
  end

  defp json_extensions(ext) do
    {:object,
     for {key, value} <- ext do
       value =
         case value do
           {:ref, path} -> ref(path)
           [name: name] -> {:object, [{"name", name}]}
           other -> other
         end

       {Atom.to_string(key), value}
     end}
  end

  defp json_value({:ref, path}), do: ref(path)
  defp json_value({:color, hex, alpha}), do: color_object(hex, alpha)
  defp json_value({:px, n}), do: dimension(n, "px")
  defp json_value({:rem, n}), do: dimension(n, "rem")
  defp json_value({:family, name, _fallback}), do: name
  defp json_value({:number, n}), do: n

  defp json_value({:typography, t}) do
    {:object,
     [
       {"fontFamily", ref(t[:family])},
       {"fontSize", ref(t[:size])},
       {"fontWeight", ref(t[:weight])},
       {"letterSpacing", dimension(0, "px")},
       {"lineHeight", round4(t[:ratio])}
     ]}
  end

  defp json_value({:shadow, _group, s}) do
    {:object,
     [
       {"color", json_value(s[:color])},
       {"offsetX", dimension(s[:x], "px")},
       {"offsetY", dimension(s[:y], "px")},
       {"blur", dimension(s[:blur], "px")},
       {"spread", dimension(s[:spread], "px")}
     ] ++ if(s[:inset], do: [{"inset", true}], else: [])}
  end

  defp ref(path), do: "{" <> Enum.map_join(path, ".", &segment/1) <> "}"

  defp dimension(n, unit), do: {:object, [{"value", n}, {"unit", unit}]}

  defp color_object("#" <> _ = hex, alpha) do
    {r, g, b} = Web.rgb(hex)

    {:object,
     [
       {"colorSpace", "srgb"},
       {"components", Enum.map([r, g, b], &round4(&1 / 255))},
       {"alpha", alpha},
       {"hex", hex}
     ]}
  end

  defp round4(n) do
    n = Float.round(n / 1, 4)
    if n == trunc(n), do: trunc(n), else: n
  end

  # JSON with two-space indents and the members in the given order.
  defp encode({:object, []}, _), do: "{}"

  defp encode({:object, members}, indent) do
    pad = String.duplicate("  ", indent + 1)

    lines =
      Enum.map_join(members, ",\n", fn {key, value} ->
        pad <> JSON.encode!(key) <> ": " <> encode(value, indent + 1)
      end)

    "{\n" <> lines <> "\n" <> String.duplicate("  ", indent) <> "}"
  end

  defp encode(list, indent) when is_list(list),
    do: "[" <> Enum.map_join(list, ", ", &encode(&1, indent)) <> "]"

  defp encode(n, _) when is_float(n), do: Web.number(n)
  defp encode(value, _), do: JSON.encode!(value)

  # --------------------------------------------------------------- tokens.css

  @doc false
  def css(tokens, prefix) do
    var = fn path -> "--#{prefix}-" <> Enum.join(Enum.map(path, &segment/1), "-") end

    sections =
      tokens
      |> Enum.chunk_by(&{hd(&1.path), &1.group})
      |> Enum.map_join("\n", fn [first | _] = run ->
        comment = if first.group, do: "#{first.group}", else: title(hd(first.path))

        "  /* #{comment!(comment)} */\n" <>
          Enum.map_join(run, fn t ->
            deprecated = if t.deprecated, do: " /* deprecated */", else: ""
            "  #{var.(t.path)}: #{css_value(t.value, var)};#{deprecated}\n"
          end)
      end)

    ":root {\n" <> sections <> "}\n"
  end

  @titles %{
    "color" => "Colors",
    "font-family" => "Font families",
    "font-weight" => "Font weights",
    "font-size" => "Font sizes",
    "line-height" => "Line heights",
    "typography" => "Typography",
    "spacing" => "Spacing",
    "height" => "Heights",
    "max-height" => "Maximum heights",
    "radius" => "Radii",
    "shadow" => "Shadows",
    "text-shadow" => "Text shadows"
  }

  defp title(group), do: Map.fetch!(@titles, group)

  defp css_value({:ref, path}, var), do: "var(#{var.(path)})"
  defp css_value({:color, hex, 1}, _), do: hex
  defp css_value({:px, n}, _), do: "#{Web.number(n)}px"
  defp css_value({:rem, n}, _), do: "#{Web.number(n)}rem"
  defp css_value({:percent, n}, _), do: "#{Web.number(n)}%"
  defp css_value({:family, name, fallback}, _), do: "#{Web.css_str(name)}, #{fallback}"
  defp css_value({:number, n}, _), do: Integer.to_string(n)

  defp css_value({:typography, t}, var) do
    italic = if t[:italic], do: "italic ", else: ""

    "#{italic}var(#{var.(t[:weight])}) var(#{var.(t[:size])})/var(#{var.(t[:line_height])}) " <>
      "var(#{var.(t[:family])})"
  end

  defp css_value({:shadow, group, s}, _) do
    {:color, hex, alpha} = s[:color]
    {r, g, b} = Web.rgb(hex)
    px = fn n -> if n == 0, do: "0", else: "#{Web.number(n)}px" end
    lengths = [s[:x], s[:y], s[:blur]] ++ if(group == "shadow", do: [s[:spread]], else: [])
    inset = if s[:inset], do: "inset ", else: ""
    "#{inset}#{Enum.map_join(lengths, " ", px)} rgba(#{r}, #{g}, #{b}, #{Web.number(alpha)})"
  end

  defp comment!(text) do
    if String.contains?(text, "*/") or Regex.match?(~r/[\x{0}-\x{1F}\x{2028}\x{2029}]/u, text),
      do: raise(ArgumentError, "#{inspect(text)} can't be written in a comment")

    text
  end
end
