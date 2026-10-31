defmodule Prism.Generator.DesignTools.Overview do
  @moduledoc """
  An overview of a design as one standalone SVG (`overview.svg`): every token,
  and every component's variants and states, drawn as shapes and text that a
  design tool imports as editable layers and a browser opens as is.

  - **Tokens**: color swatches with their name and value; the font families,
    fonts and text sizes, and each typography token, in their own fonts; spacing and
    heights as bars; radii; shadows on cards; text shadows on text.
  - **Components**: a sheet per component, a row per variant (each variant of
    the `:variant` axis, each variant of another axis combined with the
    first, each look with a variant of another axis with that variant, and
    each flag that is off by default turned on, or each flag that is on by
    default turned off), a column per state. A cell is drawn from the same data as the web
    target's `components.css`: the design's shared look with its `web:`
    binding, the markup of `Prism.Generator.Web.Elements` (which parts there
    are and what each holds), a part's look inside its component's.
    It is a sketch, not a rendering: text widths are estimated, and the web's
    mechanics are left out but for the two images it draws (a spinner's ring
    and a checkbox's check mark) and a field's width.

  The SVG holds no external references and no CSS: every look is a
  presentation attribute. Text is `<text>` (not outlined), its family the
  web font's name alone (no fallback list), so a design tool matches it to
  the installed font; a browser without the font falls back to its default.
  A shadow is an SVG filter in the structure Figma writes for its own drop
  and inner shadows. Every group has an `id`, which design tools show as the
  layer's name: a token's path (`color/accent`; a text size is its font size's,
  `font-size/body`, with its line height's, `line-height/body`, inside), or a
  component's cell (`button/primary/pressed`).
  """

  alias Prism.Generator.Web
  alias Prism.Generator.Web.{Components, Elements}

  @width 1200
  @margin 48
  @ink "#222222"
  @muted "#6B6B6B"
  @line "#D9D9D9"
  @bar "#8DA2C0"
  @placeholder "#B0B0B0"

  # The states, in the schema's order, for the order of a sheet's columns.
  @states [:pressed, :hovered, :focused, :disabled, :checked, :selected, :loading, :invalid]

  # The keys of a web binding that are the web's own, not properties.
  @binding_keys Components.bindings() |> Map.values() |> List.flatten() |> Enum.uniq()

  @doc "The overview of a design's `__schema__/0`, as SVG source."
  def svg(design) do
    ctx = context(design)

    sections =
      [
        title_section(ctx),
        colors(ctx),
        families(ctx),
        fonts(ctx),
        text_sizes(ctx),
        typography(ctx),
        lengths(ctx, "Spacing", :space, "spacing", & &1.key),
        lengths(ctx, "Heights", :height, "height", & &1.key),
        lengths(ctx, "Maximum heights", :max_height, "max-height", & &1.name),
        radii(ctx),
        shadows(ctx),
        text_shadows(ctx)
      ] ++ components(ctx)

    sections = Enum.reject(sections, &is_nil/1)

    {body, height} =
      Enum.reduce(sections, {[], @margin}, fn {id, _w, h, draw}, {body, y} ->
        {[body, group(id, [], draw.(@margin, y))], y + h + 56}
      end)

    height = height - 56 + @margin

    # As wide as the widest component sheet.
    width = sections |> Enum.map(&elem(&1, 1)) |> Enum.max() |> Kernel.+(2 * @margin)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{num(width)}" height="#{num(height)}" ),
      ~s(viewBox="0 0 #{num(width)} #{num(height)}">\n),
      filters(ctx),
      el("rect", id: "background", width: num(width), height: num(height), fill: "#FFFFFF"),
      body,
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  # ---------------------------------------------------------------- context

  defp context(design) do
    tokens = design.tokens
    by = fn kind -> for(%{kind: ^kind} = t <- tokens, do: t) end
    index = fn kind -> Map.new(by.(kind), &{&1.name, &1}) end

    ctx = %{
      design: design,
      by: by,
      colors: index.(:color),
      shadows: index.(:shadow),
      text_shadows: index.(:text_shadow),
      families: index.(:family),
      fonts: index.(:font),
      texts: index.(:text),
      typographies: index.(:typography),
      radii: index.(:radius),
      max_heights: index.(:max_height),
      prefix: design.web.prefix
    }

    Map.put(ctx, :caption, caption_family(ctx))
  end

  # The family the overview writes its own labels in: the body text's, or the first.
  defp caption_family(ctx) do
    font =
      case ctx.typographies[:body] do
        %{font: font} -> ctx.fonts[font]
        nil -> ctx.by.(:font) |> List.first()
      end

    case {font, ctx.by.(:family)} do
      {%{family: family}, _} -> ctx.families[family].web[:name]
      {nil, [family | _]} -> family.web[:name]
      {nil, []} -> "sans-serif"
    end
  end

  # ---------------------------------------------------------------- tokens

  defp title_section(ctx) do
    name = String.capitalize(ctx.prefix)

    {"title", @width - 2 * @margin, 64,
     fn x, y ->
       [
         label(ctx, x, y + 34, name, size: 36, weight: 800),
         label(ctx, x, y + 60, "Tokens and components, generated from the design",
           size: 16,
           fill: @muted
         )
       ]
     end}
  end

  defp heading(ctx, x, y, text), do: label(ctx, x, y + 22, text, size: 24, weight: 700)

  # A section: a heading, then items in rows that wrap at the page width. Each item
  # is `{id, width, height, draw}`; rows of a section are `gap` apart.
  defp flow(ctx, id, title, items, gap \\ 24) do
    if items == [] do
      nil
    else
      {rows, _} =
        Enum.reduce(items, {[[]], 0}, fn {_, w, _, _} = item, {[row | rows], used} ->
          if row != [] and used + w > @width - 2 * @margin,
            do: {[[item], row | rows], w + gap},
            else: {[[item | row] | rows], used + w + gap}
        end)

      rows = rows |> Enum.reverse() |> Enum.map(&Enum.reverse/1) |> Enum.reject(&(&1 == []))
      heights = Enum.map(rows, fn row -> row |> Enum.map(&elem(&1, 2)) |> Enum.max() end)
      height = 40 + Enum.sum(heights) + gap * (length(rows) - 1)

      {id, @width - 2 * @margin, height,
       fn x, y ->
         {drawn, _} =
           rows
           |> Enum.zip(heights)
           |> Enum.map_reduce(y + 40, fn {row, h}, ry ->
             {cells, _} =
               Enum.map_reduce(row, x, fn {item_id, w, _, draw}, rx ->
                 {group(item_id, [], draw.(rx, ry)), rx + w + gap}
               end)

             {cells, ry + h + gap}
           end)

         [heading(ctx, x, y, title), drawn]
       end}
    end
  end

  defp colors(ctx) do
    items =
      for t <- ctx.by.(:color) do
        {hex, _} = color(ctx, t.name)
        value = if is_atom(t.value), do: "#{t.value} · #{hex}", else: hex

        {"color/#{key(t.name)}", 132, 116,
         fn x, y ->
           [
             el("rect",
               x: x + 0.5,
               y: y + 0.5,
               width: 131,
               height: 71,
               rx: 8,
               fill: hex,
               stroke: @line
             ),
             label(ctx, x, y + 92, key(t.name), size: 14, weight: 700),
             label(ctx, x, y + 110, value, size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, "colors", "Colors", items)
  end

  defp families(ctx) do
    items =
      for t <- ctx.by.(:family) do
        web = t.web
        native = "iOS: #{native(t.ios)} · Android: #{native(t.android)}"

        {"font-family/#{key(t.name)}", @width - 2 * @margin, 76,
         fn x, y ->
           [
             text(x, y + 36, web[:name], family: web[:name], size: 36, weight: 400, fill: @ink),
             label(ctx, x, y + 60, "#{key(t.name)} · #{t.doc} · #{native}",
               size: 12,
               fill: @muted
             )
           ]
         end}
      end

    flow(ctx, "font-families", "Font families", items, 12)
  end

  defp native(:system), do: "system font"
  defp native(font), do: font[:name]

  defp fonts(ctx) do
    items =
      for t <- ctx.by.(:font) do
        family = ctx.families[t.family].web[:name]
        italic = if t[:italic], do: " italic", else: ""

        {"font-weight/#{key(t.name)}", 264, 52,
         fn x, y ->
           [
             text(x, y + 24, key(t.name),
               family: family,
               size: 22,
               weight: t.weight,
               italic: t[:italic] == true,
               fill: @ink
             ),
             label(ctx, x, y + 44, "#{family} #{t.weight}#{italic}", size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, "fonts", "Fonts", items, 16)
  end

  # A text size is two tokens: its layer is the font size's, with the line height's
  # inside it.
  defp text_sizes(ctx) do
    items =
      for t <- ctx.by.(:text) do
        w = max(estimate("Aa", t.size, 400), estimate(key(t.name), 12, 700)) + 8

        {"font-size/#{key(t.name)}", w, t.line_height + 40,
         fn x, y ->
           [
             text(x, y + baseline(0, t.line_height, t.size), "Aa",
               family: ctx.caption,
               size: t.size,
               weight: 400,
               fill: @ink
             ),
             label(ctx, x, y + t.line_height + 18, key(t.name), size: 12, weight: 700),
             group(
               "line-height/#{key(t.name)}",
               [],
               label(ctx, x, y + t.line_height + 34, "#{num(t.size)}/#{num(t.line_height)}",
                 size: 12,
                 fill: @muted
               )
             )
           ]
         end}
      end

    flow(ctx, "text-sizes", "Text sizes", items, 28)
  end

  defp typography(ctx) do
    items =
      for t <- ctx.by.(:typography) do
        type = type(ctx, t.name)
        italic = if type.italic, do: " italic", else: ""

        caption =
          "#{type.family} #{type.weight}#{italic} · #{num(type.size)}/#{num(type.line_height)}" <>
            " · font #{key(t.font)}, text #{key(t.text)}"

        {"typography/#{key(t.name)}", @width - 2 * @margin, type.line_height + 8,
         fn x, y ->
           [
             text(x, y + baseline(0, type.line_height, type.size), key(t.name),
               family: type.family,
               size: type.size,
               weight: type.weight,
               italic: type.italic,
               fill: @ink
             ),
             label(ctx, x + 560, y + baseline(0, type.line_height, 14), caption,
               size: 14,
               fill: @muted
             )
           ]
         end}
      end

    flow(ctx, "typography", "Typography", items, 12)
  end

  # Layers are named by the tokens' DTCG paths, with `/` as design tools nest them.
  defp lengths(ctx, title, kind, group, name) do
    items =
      for t <- ctx.by.(kind) do
        id = "#{group}/#{segment(name.(t))}"
        w = max(t.value, 96)

        {id, w, 52,
         fn x, y ->
           [
             el("rect", x: x, y: y, width: num(t.value), height: 16, fill: @bar),
             label(ctx, x, y + 34, segment(name.(t)), size: 12, weight: 700),
             label(ctx, x, y + 50, "#{num(t.value)}px", size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, String.downcase(String.replace(title, " ", "-")), title, items)
  end

  defp radii(ctx) do
    items =
      for t <- ctx.by.(:radius) do
        {"radius/#{key(t.name)}", 132, 116,
         fn x, y ->
           [
             el("rect",
               x: x + 1,
               y: y + 1,
               width: 70,
               height: 70,
               rx: num(radius(ctx, t.name, 72)),
               fill: "#F2F4F8",
               stroke: @bar,
               "stroke-width": 2
             ),
             label(ctx, x, y + 92, key(t.name), size: 14, weight: 700),
             label(ctx, x, y + 110, css_length(t.value), size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, "radii", "Radii", items)
  end

  defp shadows(ctx) do
    items =
      for t <- ctx.by.(:shadow) do
        id = filter_id(ctx, :shadow, t.name)
        note = if is_atom(t.value), do: "#{key(t.value)}", else: shadow_note(t.value)
        note = if Map.get(t, :deprecated), do: note <> " · deprecated", else: note

        {"shadow/#{key(t.name)}", 200, 152,
         fn x, y ->
           [
             el("rect",
               x: x + 16,
               y: y + 16,
               width: 168,
               height: 80,
               rx: 8,
               fill: "#F5F6F8",
               filter: "url(##{id})"
             ),
             label(ctx, x, y + 128, key(t.name), size: 14, weight: 700),
             label(ctx, x, y + 146, note, size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, "shadows", "Shadows", items)
  end

  defp text_shadows(ctx) do
    items =
      for t <- ctx.by.(:text_shadow) do
        {"text-shadow/#{key(t.name)}", 200, 96,
         fn x, y ->
           [
             text(x, y + 40, "Shadow",
               family: ctx.caption,
               size: 36,
               weight: 800,
               fill: "#FFFFFF",
               filter: "url(##{filter_id(ctx, :text_shadow, t.name)})"
             ),
             label(ctx, x, y + 72, key(t.name), size: 14, weight: 700),
             label(ctx, x, y + 90, shadow_note(t.value), size: 12, fill: @muted)
           ]
         end}
      end

    flow(ctx, "text-shadows", "Text shadows", items)
  end

  defp shadow_note(s) do
    inset = if s[:inset], do: "inset ", else: ""
    {color, alpha} = s[:color]

    "#{inset}#{num(s[:x] || 0)} #{num(s[:y] || 0)} #{num(s[:blur] || 0)}" <>
      if(s[:spread], do: " #{num(s[:spread])}", else: "") <> " #{key(color)} #{num(alpha)}"
  end

  # ---------------------------------------------------------------- filters

  # One filter per shadow and text shadow that is no alias; an alias uses its target's.
  defp filters(ctx) do
    defs =
      for {kind, tokens} <- [shadow: ctx.by.(:shadow), text_shadow: ctx.by.(:text_shadow)],
          t <- tokens,
          not is_atom(t.value),
          do: filter(ctx, filter_id(ctx, kind, t.name), t.value)

    if defs == [], do: [], else: ["<defs>\n", defs, "</defs>\n"]
  end

  defp filter_id(ctx, :shadow, name) do
    case ctx.shadows[name].value do
      ref when is_atom(ref) -> filter_id(ctx, :shadow, ref)
      _ -> "shadow-#{key(name)}"
    end
  end

  defp filter_id(_ctx, :text_shadow, name), do: "text-shadow-#{key(name)}"

  # Figma's own structure for a drop shadow and an inner shadow, so Figma reads the
  # filter back as an effect.
  defp filter(ctx, id, s) do
    {color, alpha} = s[:color]
    {hex, 1} = color(ctx, color)
    {r, g, b} = Web.rgb(hex)

    matrix =
      "0 0 0 0 #{num(r / 255)} 0 0 0 0 #{num(g / 255)} 0 0 0 0 #{num(b / 255)} 0 0 0 #{num(alpha)} 0"

    spread = s[:spread] || 0
    std = num((s[:blur] || 0) / 2)

    morphology =
      cond do
        spread > 0 ->
          el("feMorphology",
            radius: num(spread),
            operator: "dilate",
            in: "SourceAlpha",
            result: "spread"
          )

        spread < 0 ->
          el("feMorphology",
            radius: num(-spread),
            operator: "erode",
            in: "SourceAlpha",
            result: "spread"
          )

        true ->
          nil
      end

    alpha_in = if morphology, do: [in: "spread"], else: []

    primitives =
      if s[:inset] do
        [
          el("feFlood", "flood-opacity": 0, result: "BackgroundImageFix"),
          el("feBlend",
            mode: "normal",
            in: "SourceGraphic",
            in2: "BackgroundImageFix",
            result: "shape"
          ),
          el("feColorMatrix",
            in: "SourceAlpha",
            type: "matrix",
            values: "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0",
            result: "hardAlpha"
          ),
          morphology,
          el("feOffset", [dx: num(s[:x] || 0), dy: num(s[:y] || 0)] ++ alpha_in),
          el("feGaussianBlur", stdDeviation: std),
          el("feComposite", in2: "hardAlpha", operator: "arithmetic", k2: -1, k3: 1),
          el("feColorMatrix", type: "matrix", values: matrix),
          el("feBlend", mode: "normal", in2: "shape", result: "effect1_innerShadow")
        ]
      else
        [
          el("feFlood", "flood-opacity": 0, result: "BackgroundImageFix"),
          el("feColorMatrix",
            in: "SourceAlpha",
            type: "matrix",
            values: "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0",
            result: "hardAlpha"
          ),
          morphology,
          el("feOffset", [dx: num(s[:x] || 0), dy: num(s[:y] || 0)] ++ alpha_in),
          el("feGaussianBlur", stdDeviation: std),
          el("feColorMatrix", type: "matrix", values: matrix),
          el("feBlend", mode: "normal", in2: "BackgroundImageFix", result: "effect1_dropShadow"),
          el("feBlend",
            mode: "normal",
            in: "SourceGraphic",
            in2: "effect1_dropShadow",
            result: "shape"
          )
        ]
      end

    [
      ~s(<filter id="#{id}" x="-50%" y="-50%" width="200%" height="200%" ),
      ~s(color-interpolation-filters="sRGB">\n),
      for(p <- primitives, p != nil, do: ["  ", p]),
      "</filter>\n"
    ]
  end

  # ------------------------------------------------------------- components

  defp components(%{design: %{components: []}}), do: []

  defp components(ctx) do
    specs = Map.new(Elements.components(ctx.design, "the design-tools target"), &{&1.name, &1})

    for c <- ctx.design.components do
      sheet(ctx, c, specs)
    end
  end

  # A component's sheet: a row per variant selection, a column per state.
  defp sheet(ctx, c, specs) do
    rows = rows(c)
    columns = [nil | states(c)]
    label_w = rows |> Enum.map(&estimate(elem(&1, 0), 13, 700)) |> Enum.max() |> max(80)

    cells =
      for {_, sel} <- rows do
        for state <- columns do
          if state == nil or applies?(c, sel, state),
            do: specimen(ctx, c, specs, sel, state),
            else: nil
        end
      end

    widths =
      for i <- 0..(length(columns) - 1) do
        header = estimate(column_name(Enum.at(columns, i)), 12, 700)
        cells |> Enum.map(&Enum.at(&1, i)) |> Enum.map(&cell_width/1) |> Enum.max() |> max(header)
      end

    heights = Enum.map(cells, fn row -> row |> Enum.map(&cell_height/1) |> Enum.max() end)
    gap = 32
    height = 40 + 24 + Enum.sum(heights) + gap * length(rows)

    width = label_w + Enum.sum(widths) + gap * length(widths)

    {"component/#{key(c.name)}", width, height,
     fn x, y ->
       x0 = x + label_w + gap

       {headers, _} =
         columns
         |> Enum.zip(widths)
         |> Enum.map_reduce(x0, fn {state, w}, cx ->
           {label(ctx, cx, y + 54, column_name(state), size: 12, weight: 700, fill: @muted),
            cx + w + gap}
         end)

       {body, _} =
         rows
         |> Enum.zip(cells)
         |> Enum.zip(heights)
         |> Enum.map_reduce(y + 64 + gap / 2, fn {{{name, _}, row}, h}, ry ->
           {drawn, _} =
             row
             |> Enum.zip(columns)
             |> Enum.zip(widths)
             |> Enum.map_reduce(x0, fn {{cell, state}, w}, cx ->
               drawn =
                 if cell,
                   do:
                     group(
                       "#{key(c.name)}/#{row_id(name)}/#{column_name(state)}",
                       [],
                       [
                         backdrop(cell, cx, ry + (h - cell.h) / 2),
                         cell.draw.(cx, ry + (h - cell.h) / 2)
                       ]
                     ),
                   else: []

               {drawn, cx + w + gap}
             end)

           {[label(ctx, x, ry + h / 2 + 5, name, size: 13, weight: 700), drawn], ry + h + gap}
         end)

       [heading(ctx, x, y, title(c.name)), headers, body]
     end}
  end

  # A light look without a fill of its own (an inverse spinner) is drawn on a dark
  # backdrop, as it is meant to be seen.
  defp backdrop(%{backdrop: true} = cell, x, y),
    do:
      el("rect",
        x: num(x - 8),
        y: num(y - 8),
        width: num(cell.w + 16),
        height: num(cell.h + 16),
        rx: 4,
        fill: @ink
      )

  defp backdrop(_, _, _), do: []

  defp column_name(nil), do: "enabled"
  defp column_name(state), do: key(state)

  defp row_id(name), do: name |> String.replace(" + ", "+") |> String.replace(" ", "-")

  defp cell_width(nil), do: 0
  defp cell_width(cell), do: cell.w

  defp cell_height(nil), do: 0
  defp cell_height(cell), do: cell.h

  # The variant selections, each `{label, [variant]}`: the component without a
  # variant when its `:variant` axis has no default, each variant of that axis, and
  # each variant of another axis with the `:variant` axis's default (or its first
  # variant). Every selection also has the other axes' defaults that are variants.
  defp rows(c) do
    own = for v <- c.variants, v.axis == :variant, do: v
    others = for a <- c.axes, v <- c.variants, v.axis == a.name, do: v
    defaults = defaults(c)
    base = List.wrap(Enum.find(own, &(&1.name == c.default)) || List.first(own))

    none =
      cond do
        own == [] and others == [] -> [{"default", []}]
        own != [] and c.default == nil -> [{"no variant", defaults.(:variant)}]
        true -> []
      end

    # The flags that are on by default are on in every row.
    on = for f <- c.flags, f.default, do: f
    own_rows = Enum.map(own, &{key(&1.name), defaults.(:variant) ++ [&1] ++ on})

    other_rows =
      for v <- others do
        rest = for d <- defaults.(v.axis), d.axis != :variant, do: d
        {Enum.map_join(base ++ [v], " + ", &key(&1.name)), base ++ rest ++ [v] ++ on}
      end

    # Each look with a variant of another axis: the two variants, the :variant
    # axis's first.
    with_rows =
      for v <- c.variants, w <- v.with_variants do
        other = Enum.find(c.variants, &(&1.name == w.name))
        pair = Enum.sort_by([other, v], &(&1.axis != :variant))
        axes = Enum.map(pair, & &1.axis)
        rest = for d <- defaults.(nil), d.axis not in axes, do: d
        {Enum.map_join(pair, " + ", &key(&1.name)), rest ++ pair ++ on}
      end

    # Each flag the other way round from its default: on its own look's base, or
    # with each variant it has a look with.
    flag_rows =
      for f <- c.flags,
          sel <- flag_selections(c, f, base, defaults) do
        others = Enum.reject(on, &(&1.name == f.name))
        flag = if f.default, do: "not #{key(f.name)}", else: key(f.name)
        variants = Enum.filter(sel, &Map.has_key?(&1, :axis))
        flags = if f.default, do: others, else: others ++ [f]
        {Enum.map_join(variants, " + ", &key(&1.name)) <> " + " <> flag, sel ++ flags}
      end

    Enum.uniq_by(none ++ own_rows ++ other_rows ++ with_rows ++ flag_rows, fn {_, sel} ->
      Enum.map(sel, & &1.name)
    end)
  end

  defp flag_selections(c, f, base, defaults) do
    if f.style != [] or f.with_variants == [] do
      [defaults.(:variant) ++ base]
    else
      for w <- f.with_variants do
        v = Enum.find(c.variants, &(&1.name == w.name))
        for(d <- defaults.(v.axis), do: d) ++ [v]
      end
    end
  end

  # The variants the other axes' defaults pick, for a row of `axis`.
  defp defaults(c) do
    fn axis ->
      for a <- [%{name: :variant, default: c.default} | c.axes],
          a.name != axis,
          v = Enum.find(c.variants, &(&1.axis == a.name and &1.name == a.default)),
          do: v
    end
  end

  # Every state the component, a variant or a part declares, in the format's order.
  defp states(c) do
    declared =
      for node <-
            [c | c.variants] ++
              c.parts ++
              Enum.flat_map(c.variants, &(&1.parts ++ &1.with_variants)) ++
              c.flags ++ Enum.flat_map(c.flags, & &1.with_variants),
          s <- node.states,
          into: MapSet.new(),
          do: s.name

    for name <- @states, name in declared, do: name
  end

  defp applies?(c, sel, state) do
    nodes =
      [c | sel] ++ c.parts ++ Enum.flat_map(sel, &Map.get(&1, :parts, [])) ++ with_variants(sel)

    Enum.any?(nodes, fn node -> Enum.any?(node.states, &(&1.name == state)) end)
  end

  # ---------------------------------------------------------- the box model

  # A specimen: `%{w, h, draw}`, its draw function taking the top left corner.
  defp specimen(ctx, c, specs, sel, state) do
    spec = specs[c.name]
    look = root_look(c, sel, state)
    inherited = %{foreground: "#000000", typography: nil, weight: nil, decoration: nil}
    box = box(ctx, c, spec, specs, sel, state, look, inherited)

    Map.put(
      box,
      :backdrop,
      look[:background] in [nil, :transparent] and light?(ctx, look[:foreground])
    )
  end

  defp light?(_ctx, nil), do: false
  defp light?(_ctx, :transparent), do: false

  defp light?(ctx, color) do
    {r, g, b} = ctx |> color(color) |> elem(0) |> Web.rgb()
    0.2126 * r + 0.7152 * g + 0.0722 * b > 0.85 * 255
  end

  # The look of a selection: the component's, each variant's and flag's, their
  # looks with each other, and the same in the state.
  defp root_look(c, sel, state) do
    looks = sel ++ with_variants(sel)

    chain =
      [style(c)] ++
        Enum.map(looks, &style/1) ++
        Enum.map(state_nodes(c, state), &style/1) ++
        Enum.flat_map(looks, &Enum.map(state_nodes(&1, state), fn s -> style(s) end))

    Enum.reduce(chain, [], &merge(&2, &1))
  end

  # The looks with a variant that a selection of variants and flags has (a flag
  # has no axis).
  defp with_variants(sel) do
    names = for n <- sel, Map.has_key?(n, :axis), do: n.name
    for n <- sel, w <- Map.get(n, :with_variants, []), w.name in names, do: w
  end

  defp state_nodes(_node, nil), do: []
  defp state_nodes(node, state), do: Enum.filter(node.states, &(&1.name == state))

  # A part's look: its own, each variant's change to it, its state, and the state's
  # changes to it on the component and the variants.
  defp part_look(c, sel, state, name, part_state \\ :same) do
    part_state = if part_state == :same, do: state, else: part_state
    own = Enum.filter(c.parts, &(&1.name == name))
    changes = for v <- sel, p <- Map.get(v, :parts, []), p.name == name, do: p

    states =
      for s <- c.states ++ Enum.flat_map(sel, & &1.states),
          s.name == state,
          p <- s.parts,
          p.name == name,
          do: p

    chain =
      Enum.map(own ++ changes, &style/1) ++
        Enum.flat_map(
          own ++ changes,
          &Enum.map(state_nodes(&1, part_state), fn s -> style(s) end)
        ) ++
        Enum.map(states, &style/1)

    Enum.reduce(chain, [], &merge(&2, &1))
  end

  # A node's look on the web: its shared style, with its web binding's properties in
  # place of the shared ones, as the web target writes it.
  defp style(node) do
    overrides = Keyword.drop(node.web, @binding_keys)

    Enum.map(node.style, fn {key, value} -> {key, Keyword.get(overrides, key, value)} end) ++
      Keyword.drop(overrides, Keyword.keys(node.style))
  end

  defp merge(look, over) do
    Enum.reduce(over, look, fn {key, value}, acc ->
      merged =
        case {key, Keyword.get(acc, key)} do
          {k, old} when k in [:border, :outline] and is_list(old) ->
            Keyword.merge(old, value)

          {k, old} when k in [:padding, :margin, :inset] and is_map(old) ->
            Map.merge(old, sides(value))

          {k, _} when k in [:padding, :margin, :inset] ->
            sides(value)

          _ ->
            value
        end

      Keyword.put(acc, key, merged)
    end)
    |> sort_like(look ++ over)
  end

  # Keeps the order properties were first given in, for stable output.
  defp sort_like(look, order) do
    keys = order |> Keyword.keys() |> Enum.uniq()
    Enum.sort_by(look, fn {k, _} -> Enum.find_index(keys, &(&1 == k)) end)
  end

  defp sides(value) do
    Enum.reduce(value, %{}, fn
      {:x, n}, acc -> Map.merge(acc, %{left: n, right: n})
      {:y, n}, acc -> Map.merge(acc, %{top: n, bottom: n})
      {side, n}, acc -> Map.put(acc, side, n)
    end)
  end

  defp side(look, key, side), do: px(Map.get(Keyword.get(look, key, %{}), side, 0))

  # The box of a component (or of a part that is one) with its children.
  defp box(ctx, c, spec, specs, sel, state, look, inherited) do
    inherited = inherit(inherited, look)
    # The images a component draws take the color around it.
    look = Keyword.put_new(look, :foreground, inherited.foreground)

    children =
      Enum.flat_map(spec.children, &child(ctx, c, specs, sel, state, &1, look, inherited))

    {absolute, flow} = Enum.split_with(children, &(&1[:absolute] != nil))

    content =
      if spec.void and look[:placeholder],
        do: [text_box(ctx, "Placeholder", inherited, color: look[:placeholder])],
        else: flow

    # A field holds text the app types: it has the width of a typical field.
    field = (spec.void and look[:placeholder] != nil) or spec.element == "textarea"

    opts = [
      direction: if(spec.element == "div" and look[:gap] == nil, do: :column, else: :row),
      align: if(look[:size] || match?({:as, _}, spec.element), do: :center, else: :start),
      min_w: if(field, do: 240, else: 0),
      state: state
    ]

    ctx |> shape(c.name, look, content, opts) |> with_absolute(absolute)
  end

  defp child(ctx, c, specs, sel, state, child, look, inherited) do
    # A component of a fixed size with a part the app fills (an icon button) holds that
    # part, not text: drawn as a placeholder of its size.
    icon_only? =
      look[:size] != nil and Enum.any?(specs[c.name].children, &(&1.as == :slot))

    case child do
      %{as: :content} when icon_only? ->
        [icon_box(px(look[:size]))]

      %{as: :content, name: name} ->
        part = part_look(c, sel, state, name)
        # A part that is a form control holding text (a select's field) is as wide as a field.
        field = Prism.Generator.Web.Classes.control?(c.name, name)
        text = text_box(ctx, title(c.name), inherit(inherited, part), [])

        opts = [
          align: if(field, do: :start, else: :center),
          min_w: if(field, do: 240, else: 0)
        ]

        [ctx |> shape(nil, part, [text], opts) |> margin(part)]

      # A part whose side the app picks is drawn on its default side.
      %{as: :slot, side: side, name: name} when side != nil ->
        if side == Enum.find(c.parts, &(&1.name == name)).position,
          do: child(ctx, c, specs, sel, state, Map.delete(child, :side), look, inherited),
          else: []

      %{as: :slot, name: name} ->
        part = part_look(c, sel, state, name)

        # A part without a look of its own (an icon) is the app's to fill.
        if Keyword.keys(part) -- [:inset] == [] do
          []
        else
          text = text_box(ctx, title(name), inherit(inherited, part), [])
          [ctx |> shape(nil, part, [text], []) |> margin(part)]
        end

      %{as: :control, name: name} ->
        part = part_look(c, sel, state, name)
        [ctx |> shape(nil, part, [], align: :center) |> margin(part)]

      %{as: :component, name: name, while_loading: while_loading} ->
        part = Enum.find(c.parts, &(&1.name == name))
        other = Enum.find(ctx.design.components, &(&1.name == part.component))

        if while_loading and state != :loading do
          []
        else
          other_sel = defaults(other).(nil)
          own = other |> root_look(other_sel, nil) |> merge(part_look(c, sel, state, name))
          nested = box(ctx, other, specs[other.name], specs, other_sel, nil, own, inherited)
          # While loading, it shows in the place of the content.
          if while_loading, do: [Map.put(nested, :absolute, :center)], else: [nested]
        end

      %{as: :list, name: name, item: item} ->
        list = part_look(c, sel, state, name)

        items =
          for i <- 1..3 do
            # The first item shows the column's state.
            look = part_look(c, sel, nil, item, if(i == 1, do: state))
            text = text_box(ctx, "#{title(item)} #{i}", inherit(inherited, look), [])
            shape(ctx, nil, look, [text], [])
          end

        [
          ctx
          |> shape(nil, list, items, direction: :column, align: :stretch, min_w: 240)
          |> margin(list)
        ]

      %{as: :inner_block} ->
        if look[:typography] || inherited.typography do
          [text_box(ctx, if(look[:size], do: "1", else: title(c.name)), inherited, [])]
        else
          [placeholder_box(ctx)]
        end

      %{as: :value} ->
        if look[:placeholder],
          do: [text_box(ctx, "Placeholder", inherited, color: look[:placeholder])],
          else: []
    end
  end

  defp inherit(inherited, look) do
    for key <- [:foreground, :typography, :weight, :decoration],
        value = look[key],
        value != nil,
        into: inherited,
        do: {key, value}
  end

  defp margin(box, look) do
    Map.put(
      box,
      :margin,
      for(s <- [:top, :right, :bottom, :left], into: %{}, do: {s, side(look, :margin, s)})
    )
  end

  defp with_absolute(box, []), do: box

  defp with_absolute(box, absolute) do
    draw = box.draw

    %{
      box
      | draw: fn x, y ->
          [
            draw.(x, y),
            Enum.map(
              absolute,
              &draw_at(&1, x + (box.w - &1.w) / 2, y + (box.h - &1.h) / 2, &1.w, :start)
            )
          ]
        end
    }
  end

  # A line of text: `draw.(x, y, anchor)` puts it at the left of its box, or with
  # `:middle` at the box's center.
  defp text_box(ctx, text, inherited, opts) do
    type = type_of(ctx, inherited.typography)
    weight = inherited.weight || type.weight
    fill = opts[:color] || inherited.foreground
    w = estimate(text, type.size, weight)

    %{
      w: w,
      h: type.line_height,
      text: true,
      draw: fn x, y, anchor ->
        tx = if anchor == :middle, do: x + w / 2, else: x

        text(tx, y + baseline(0, type.line_height, type.size), text,
          family: type.family,
          size: type.size,
          weight: weight,
          italic: type.italic,
          fill: paint(ctx, fill),
          opacity: opacity_of(ctx, fill),
          anchor: if(anchor == :middle, do: "middle"),
          decoration: if(inherited.decoration == :underline, do: "underline")
        )
      end
    }
  end

  defp icon_box(size) do
    %{
      w: size,
      h: size,
      draw: fn x, y ->
        el("rect",
          x: num(x + 0.5),
          y: num(y + 0.5),
          width: num(size - 1),
          height: num(size - 1),
          rx: 2,
          fill: "none",
          stroke: @placeholder,
          "stroke-dasharray": "2 2"
        )
      end
    }
  end

  defp placeholder_box(ctx) do
    %{
      w: 160,
      h: 32,
      draw: fn x, y ->
        [
          el("rect",
            x: num(x + 0.5),
            y: num(y + 0.5),
            width: 159,
            height: 31,
            rx: 4,
            fill: "none",
            stroke: @placeholder,
            "stroke-dasharray": "4 4"
          ),
          label(ctx, x + 80, y + 20, "Content", size: 12, fill: @muted, anchor: "middle")
        ]
      end
    }
  end

  defp draw_at(%{text: true} = child, x, y, _width, align),
    do: child.draw.(x, y, if(align == :center, do: :middle, else: :start))

  defp draw_at(%{resize: resize} = child, x, y, width, _align) when width > child.w,
    do: resize.(width).draw.(x, y)

  defp draw_at(child, x, y, _width, _align), do: child.draw.(x, y)

  # A box with a look around its children, laid out in a `direction:` (`:row` or
  # `:column`) with an `align:` (`:start`, `:center`, or `:stretch` for a column),
  # at least `min_w:` wide.
  defp shape(ctx, kind, look, children, opts) do
    direction = opts[:direction] || :row
    align = opts[:align] || :start
    min_w = opts[:min_w] || 0
    gap = px(look[:gap] || 0)
    border = px(Keyword.get(look[:border] || [], :width, 0))
    pad = for s <- [:top, :right, :bottom, :left], into: %{}, do: {s, side(look, :padding, s)}
    none = %{top: 0, right: 0, bottom: 0, left: 0}

    outer =
      for child <- children do
        m = child[:margin] || none
        {child.w + m.left + m.right, child.h + m.top + m.bottom}
      end

    {ws, hs} = Enum.unzip(outer)
    gaps = gap * max(length(children) - 1, 0)

    {cw, ch} =
      case direction do
        :row -> {Enum.sum(ws) + gaps, Enum.max(hs, fn -> 0 end)}
        :column -> {Enum.max(ws, fn -> 0 end), Enum.sum(hs) + gaps}
      end

    w = max(cw + pad.left + pad.right + 2 * border, min_w)
    h = ch + pad.top + pad.bottom + 2 * border
    {w, h} = if look[:size], do: {px(look[:size]), px(look[:size])}, else: {w, h}
    h = if look[:height], do: px(look[:height]), else: h
    h = if look[:min_height], do: max(h, px(look[:min_height])), else: h
    # Content that may grow (a text area) starts at the top; a line is centered.
    top? = look[:min_height] != nil

    draw = fn x, y ->
      ix = x + border + pad.left
      iy = y + border + pad.top
      iw = w - 2 * border - pad.left - pad.right
      ih = h - 2 * border - pad.top - pad.bottom

      start =
        case direction do
          :row -> if align == :center, do: (iw - cw) / 2, else: 0
          :column -> if top? or length(children) > 1, do: 0, else: (ih - ch) / 2
        end

      {drawn, _} =
        children
        |> Enum.zip(outer)
        |> Enum.map_reduce(start, fn {child, {ow, oh}}, offset ->
          m = child[:margin] || none

          drawn =
            case direction do
              :row ->
                cy = if top?, do: iy, else: iy + (ih - oh) / 2
                draw_at(child, ix + offset + m.left, cy + m.top, child.w, align)

              :column ->
                width = if align == :stretch, do: iw - m.left - m.right, else: child.w
                draw_at(child, ix + m.left, iy + offset + m.top, width, :start)
            end

          {drawn, offset + if(direction == :row, do: ow, else: oh) + gap}
        end)

      body = [surface(ctx, kind, look, x, y, w, h, opts[:state]), drawn]

      case look[:opacity] do
        nil -> body
        o when o == 1 -> body
        o -> [~s(<g opacity="#{num(o)}">\n), body, "</g>\n"]
      end
    end

    %{
      w: w,
      h: h,
      draw: draw,
      resize: fn width -> shape(ctx, kind, look, children, Keyword.put(opts, :min_w, width)) end
    }
  end

  # The visible box: fill, border, outline and shadow, and the two images the web
  # draws, a spinner's ring and a checkbox's check mark.
  defp surface(ctx, kind, look, x, y, w, h, state) do
    r = radius_value(ctx, look[:radius], min(w, h))
    border = look[:border] || []
    bw = px(Keyword.get(border, :width, 0))
    fill = look[:background]

    shadow =
      if look[:shadow], do: [filter: "url(##{filter_id(ctx, :shadow, look[:shadow])})"], else: []

    rect =
      if fill || bw > 0 || shadow != [] do
        el(
          "rect",
          [
            x: num(x + bw / 2),
            y: num(y + bw / 2),
            width: num(w - bw),
            height: num(h - bw),
            rx: num(max(r - bw / 2, 0)),
            fill: if(fill, do: paint(ctx, fill), else: "none")
          ] ++
            opacity_attr("fill-opacity", ctx, fill) ++
            if(bw > 0,
              do:
                [stroke: paint(ctx, border[:color]), "stroke-width": num(bw)] ++
                  opacity_attr("stroke-opacity", ctx, border[:color]),
              else: []
            ) ++ shadow
        )
      else
        []
      end

    outline =
      case look[:outline] do
        nil ->
          []

        o ->
          ow = px(o[:width] || 0)
          off = px(o[:offset] || 0) + ow / 2

          if ow > 0 do
            el(
              "rect",
              [
                x: num(x - off),
                y: num(y - off),
                width: num(w + 2 * off),
                height: num(h + 2 * off),
                rx: num(if(r >= min(w, h) / 2, do: (min(w, h) + 2 * off) / 2, else: r + off)),
                fill: "none",
                stroke: paint(ctx, o[:color]),
                "stroke-width": num(ow)
              ] ++ opacity_attr("stroke-opacity", ctx, o[:color])
            )
          else
            []
          end
      end

    [rect, outline, image(ctx, kind, look, x, y, w, h, state)]
  end

  defp image(ctx, :spinner, look, x, y, w, _h, _state) do
    stroke = max(w / 8, 2)
    r = (w - stroke) / 2
    circumference = 2 * :math.pi() * r
    color = look[:foreground]

    el(
      "circle",
      [
        cx: num(x + w / 2),
        cy: num(y + w / 2),
        r: num(r),
        fill: "none",
        stroke: paint(ctx, color),
        "stroke-width": num(stroke),
        "stroke-linecap": "round",
        "stroke-dasharray": "#{num(circumference * 0.75)} #{num(circumference)}"
      ] ++ opacity_attr("stroke-opacity", ctx, color)
    )
  end

  defp image(ctx, :checkbox, look, x, y, w, h, :checked) do
    color = look[:foreground]

    points =
      [{0.25, 0.5}, {0.43, 0.68}, {0.75, 0.34}]
      |> Enum.map_join(" ", fn {px_, py} -> "#{num(x + w * px_)},#{num(y + h * py)}" end)

    el(
      "polyline",
      [
        points: points,
        fill: "none",
        stroke: paint(ctx, color),
        "stroke-width": num(max(w / 10, 1.5)),
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      ] ++ opacity_attr("stroke-opacity", ctx, color)
    )
  end

  defp image(_, _, _, _, _, _, _, _), do: []

  # ------------------------------------------------------------- values

  # A color as `{hex, alpha}`: a token's name, `{color, alpha}`, a hex or :transparent.
  defp color(_ctx, :transparent), do: {"#000000", 0}
  defp color(_ctx, "#" <> _ = hex), do: {hex, 1}
  defp color(ctx, {ref, alpha}), do: {elem(color(ctx, ref), 0), alpha}

  defp color(ctx, name) when is_atom(name) do
    case ctx.colors[name].value do
      ref when is_atom(ref) -> color(ctx, ref)
      hex -> {hex, 1}
    end
  end

  defp paint(_ctx, :transparent), do: "none"
  defp paint(ctx, value), do: elem(color(ctx, value), 0)

  defp opacity_of(_ctx, :transparent), do: nil

  defp opacity_of(ctx, value) do
    case color(ctx, value) do
      {_, 1} -> nil
      {_, a} -> a
    end
  end

  defp opacity_attr(_name, _ctx, nil), do: []

  defp opacity_attr(name, ctx, value) do
    case opacity_of(ctx, value) do
      nil -> []
      a -> [{name, num(a)}]
    end
  end

  defp radius(ctx, name, extent), do: radius_value(ctx, name, extent)

  defp radius_value(_ctx, nil, _), do: 0

  defp radius_value(ctx, name, extent) when is_atom(name),
    do: radius_value(ctx, ctx.radii[name].value, extent)

  defp radius_value(_ctx, {n, :percent}, extent), do: min(n, 50) / 100 * extent
  defp radius_value(_ctx, value, _), do: px(value)

  defp px(n) when is_number(n), do: n
  defp px({n, :rem}), do: n * 16
  defp px({_, :percent}), do: 0

  defp css_length(n) when is_number(n), do: "#{num(n)}px"
  defp css_length({n, :rem}), do: "#{num(n)}rem"
  defp css_length({n, :percent}), do: "#{num(n)}%"

  # A typography token, or the inherited default without one: `%{family, weight, italic, size,
  # line_height}`.
  defp type_of(ctx, nil),
    do: %{family: ctx.caption, weight: 400, italic: false, size: 16, line_height: 24}

  defp type_of(ctx, name) when is_atom(name), do: type(ctx, name)

  defp type_of(ctx, pair) do
    font = ctx.fonts[pair[:font]]

    {size, line_height} =
      case pair[:text] do
        {size, line_height} -> {size, line_height}
        name -> {ctx.texts[name].size, ctx.texts[name].line_height}
      end

    %{
      family: ctx.families[font.family].web[:name],
      weight: font.weight,
      italic: font[:italic] == true,
      size: size,
      line_height: line_height
    }
  end

  defp type(ctx, name) do
    t = ctx.typographies[name]
    type_of(ctx, font: t.font, text: t.text)
  end

  # A text's width, estimated: the overview can't measure the font.
  defp estimate(text, size, weight) do
    factor = if weight >= 600, do: 0.58, else: 0.53
    Float.round(String.length(text) * size * factor, 2)
  end

  # The baseline of a line of `size` text in a line box at `top` of `line_height`.
  defp baseline(top, line_height, size), do: top + line_height / 2 + 0.35 * size

  # ---------------------------------------------------------------- SVG

  defp label(ctx, x, y, text, opts) do
    text(x, y, text,
      family: ctx.caption,
      size: opts[:size] || 12,
      weight: opts[:weight] || 400,
      fill: opts[:fill] || @ink,
      anchor: opts[:anchor]
    )
  end

  defp text(x, y, content, opts) do
    attrs =
      [
        x: num(x),
        y: num(y),
        "font-family": opts[:family],
        "font-size": num(opts[:size]),
        "font-weight": opts[:weight],
        "font-style": if(opts[:italic], do: "italic"),
        "text-anchor": opts[:anchor],
        "text-decoration": opts[:decoration],
        fill: opts[:fill],
        "fill-opacity": opts[:opacity] && num(opts[:opacity]),
        filter: opts[:filter]
      ]
      |> Enum.reject(&(elem(&1, 1) == nil))

    ["<text", attributes(attrs), ">", escape(content), "</text>\n"]
  end

  defp group(id, attrs, body), do: ["<g", attributes([id: id] ++ attrs), ">\n", body, "</g>\n"]

  defp el(name, attrs), do: ["<", name, attributes(attrs), "/>\n"]

  defp attributes(attrs) do
    for {key, value} <- attrs,
        value != nil,
        do: [" ", to_string(key), "=\"", escape(to_string(value)), "\""]
  end

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp num(n) when is_integer(n), do: Integer.to_string(n)
  defp num(n), do: n |> Float.round(2) |> Web.number()

  defp key(name), do: name |> Atom.to_string() |> String.replace("_", "-")

  defp segment(name) when is_integer(name), do: Integer.to_string(name)
  defp segment(name) when is_atom(name), do: key(name)
  defp segment(name), do: String.replace(name, "_", "-")

  defp title(name),
    do: name |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
