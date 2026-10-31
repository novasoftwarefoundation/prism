defmodule Prism.Generator.Web.Components do
  @moduledoc """
  Writes `css/components.css` from a design's components. The design holds the
  look, which every target shares; this module holds the web's mechanics of
  each component it knows: display and layout, cursors, focus outlines,
  appearance resets, keyframes, the check mark image, and how a state becomes a
  selector.

  It knows these components, by name: `:btn`, `:input`, `:textarea`, `:label`,
  `:radio`, `:dropdown`, `:spinner`, `:checkbox`, `:tag`, `:alert` and
  `:number_icon` (`kinds/0`). A design component it doesn't know fails
  generation. Each one writes the variants, parts and states the design gives
  it, so a new variant needs no change here.

  ## Classes

  A class is made of the design's names: `.<prefix>-<component>`, then
  `-<variant>`, `-<part>` or `-<state>` (`.acme-btn-primary`), with `-` for `_`.
  A variant's aliases get a selector each. A part that is another component
  has that component's class.

  ## States

  On a form control (a button, an input, the radio and checkbox controls, a
  dropdown's input) a state is the browser's: `:pressed` is `:active`,
  `:hovered` `:hover`, `:focused` `:focus`, `:disabled` `:disabled`, `:checked`
  `:checked`. On any other element `:hovered` is `:hover`, and `:disabled` and
  `:selected` are classes the app sets (`.disabled`, `.selected`). Any other
  state, such as `:loading` and `:error`, is a modifier class
  (`.acme-btn-loading`).

  ## The `web:` binding

  The web reads a node's `web:` binding before its shared look: a property in
  it replaces the shared value, on the web only. Besides the properties, the
  web knows these keys (`bindings/0`):

  - `section:` (a component) the banner comment that starts its section;
  - `doc:` (any node, and a `variants` axis) the comment above its first rule;
  - `filter:` (a spinner variant) `[color: "#RRGGBB", value: "…"]`, the CSS
    filter that tints the spinner image in that color. The web writes white
    and black itself; any other color needs a filter made for the color the
    design gives, or generation fails.

  Generation fails when a value or a `web:` key of the design is written
  nowhere, so nothing in the design is ignored.

  ## Spelling

  The spelling is fixed, so regenerating gives the same bytes: lower-case hex,
  `rgba(r, g, b, alpha)` for colors with alpha, `0` for zero lengths and in box
  shadows (`0px` in the dropdown's list), seconds for
  durations, and a `filter:` wrapped at 80 columns.
  """

  alias Prism.Generator.Web

  @kinds [
    :btn,
    :input,
    :textarea,
    :label,
    :radio,
    :dropdown,
    :spinner,
    :checkbox,
    :tag,
    :alert,
    :number_icon
  ]

  @bindings %{
    component: [:section, :doc],
    variants: [:doc],
    variant: [:doc, :filter],
    part: [:doc],
    state: [:doc]
  }

  @binding_keys @bindings |> Map.values() |> List.flatten() |> Enum.uniq()

  # Properties without a CSS declaration of their own: each component writes them
  # where they belong (`transition: all …`, `::placeholder`).
  @placed [:transition, :rotation, :placeholder]

  @control %{
    pressed: ":active",
    hovered: ":hover",
    focused: ":focus",
    disabled: ":disabled",
    checked: ":checked"
  }

  @element %{hovered: ":hover", disabled: ".disabled", selected: ".selected"}

  @check_mark "url(\"data:image/svg+xml,%3csvg viewBox='0 0 16 16' fill='FILL' xmlns='http://www.w3.org/2000/svg'%3e%3cpath d='M12.207 4.793a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0l-2-2a1 1 0 011.414-1.414L6.5 9.086l4.293-4.293a1 1 0 011.414 0z'/%3e%3c/svg%3e\")"

  @design {__MODULE__, :design}
  @read {__MODULE__, :read}

  @doc "The components the web target knows."
  def kinds, do: @kinds

  @doc "The keys a `web:` binding may have besides the properties, per kind of node."
  def bindings, do: @bindings

  @doc false
  # Checks the value of a web binding key, for the schema.
  def check_binding(key, value) when key in [:section, :doc] do
    if is_binary(value) and String.valid?(value) and not String.contains?(value, "*/") and
         not Regex.match?(~r/[\x{0}-\x{1F}\x{7F}\x{2028}\x{2029}]/u, value),
       do: :ok,
       else: {:error, "must be one line of text without */"}
  end

  def check_binding(:filter, value) do
    if Keyword.keyword?(value) and Enum.sort(Keyword.keys(value)) == [:color, :value] and
         is_binary(value[:color]) and Regex.match?(~r/\A#[0-9A-F]{6}\z/, value[:color]) and
         check_binding(:doc, value[:value]) == :ok,
       do: :ok,
       else: {:error, ~s(must be [color: "#RRGGBB", value: "a CSS filter"])}
  end

  @doc false
  # The body of css/components.css for a design's `__schema__/0`.
  def css(%{components: components, web: web} = design) do
    for c <- components, c.name not in @kinds do
      raise ArgumentError,
            "the web target has no component #{inspect(c.name)}; it knows #{Enum.map_join(@kinds, ", ", &inspect/1)}"
    end

    Process.put(@design, design)
    Process.put(@read, MapSet.new())

    try do
      body =
        components
        |> Enum.map(fn c -> c |> blocks() |> List.flatten() |> section(c) end)
        |> Enum.join("\n")

      covered!(design)
      Web.doc_block(web.components_doc) <> body
    after
      Process.delete(@design)
      Process.delete(@read)
    end
  end

  # ------------------------------------------------------------ components

  defp blocks(%{name: :btn} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: inline-flex",
        "align-items: center",
        "justify-content: center",
        declarations(n),
        "cursor: pointer",
        "outline: none",
        placed(n, :transition, &"transition: all #{&1}")
      ]),
      rule(".#{class(n)}:focus", ["outline: none"]),
      states(n, c, @control),
      variants(c, &(&1 == :variant), @control),
      loading(c),
      variants(c, &(&1 != :variant), @control)
    ]
  end

  defp blocks(%{name: :input} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: block",
        "width: 100%",
        declarations(n),
        "outline: none",
        placed(n, :transition, &"transition: border-color #{&1}")
      ]),
      placeholder(n),
      states(n, c, @control),
      variants(c, fn _ -> true end, @control)
    ]
  end

  defp blocks(%{name: :textarea} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: block",
        "width: 100%",
        declarations(n),
        "outline: none",
        "resize: vertical",
        placed(n, :transition, &"transition: border-color #{&1}")
      ]),
      placeholder(n),
      states(n, c, @control),
      variants(c, fn _ -> true end, @control)
    ]
  end

  defp blocks(%{name: :label} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", ["display: block", declarations(n)]),
      states(n, c, @element),
      variants(c, fn _ -> true end, @element)
    ]
  end

  # The component is the radio control; the group holds the options, and an option
  # is a label around the control and its text.
  defp blocks(%{name: :radio} = c) do
    n = [c.name]

    [
      part(c, :group, &["display: flex", "flex-direction: row", declarations(&1)]),
      part(c, :label, fn path ->
        [
          "display: flex",
          "flex-direction: row",
          "align-items: center",
          declarations(path),
          "cursor: pointer"
        ]
      end),
      rule(n, ".#{class(n)}", [
        "appearance: none",
        declarations(n),
        "cursor: pointer",
        placed(n, :transition, &"transition: all #{&1}")
      ]),
      states(n, c, @control),
      if(state(c, :disabled),
        do: [],
        else: rule(".#{class(n)}:disabled", ["cursor: not-allowed"])
      ),
      part(c, :text, fn path ->
        [
          declarations(path, except: [:margin]),
          "user-select: none",
          declarations(path, only: [:margin])
        ]
      end),
      variants(c, fn _ -> true end, @control)
    ]
  end

  defp blocks(%{name: :dropdown} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", ["position: relative", "width: 100%", declarations(n)]),
      part(c, :input, fn path ->
        [
          "display: block",
          "width: 100%",
          declarations(path),
          "outline: none",
          "cursor: pointer",
          "white-space: pre-wrap"
        ]
      end),
      part(c, :icon, fn path ->
        [
          "position: absolute",
          declarations(path),
          "top: 50%",
          "transform: translateY(-50%)",
          "pointer-events: none"
        ]
      end),
      part(c, :options, fn path ->
        [
          "position: absolute",
          "z-index: 20",
          declarations(path, only: [:inset]),
          "width: 100%",
          declarations(path, only: [:background, :radius]),
          # The list's shadow writes its zeros as 0px.
          if(has?(path, :shadow),
            do: "box-shadow: #{value(path, :shadow, zero: "0px")}",
            else: []
          ),
          declarations(path, only: [:max_height]),
          "overflow-y: auto",
          declarations(path, except: [:inset, :background, :radius, :shadow, :max_height])
        ]
      end),
      part(c, :option, fn path ->
        [
          "display: flex",
          "flex-direction: column",
          "justify-content: center",
          declarations(path),
          "white-space: nowrap",
          "cursor: pointer",
          placed(path, :transition, &"transition: background-color #{&1}")
        ]
      end),
      variants(c, fn _ -> true end, @control)
    ]
  end

  # The spinner is an image that turns; a variant with a color tints it with a CSS
  # filter, after the keyframes.
  defp blocks(%{name: :spinner} = c) do
    n = [c.name]
    {tinted, other} = Enum.split_with(c.variants, &Keyword.has_key?(web_style(&1), :foreground))

    [
      rule(n, ".#{class(n)}", [
        declarations(n),
        placed(n, :rotation, &"animation: #{prefix()}-spin #{&1} infinite")
      ]),
      states(n, c, @element),
      Enum.map(other, &prepend(axis_doc(c, &1), variant(c, &1, @element))),
      """
      @keyframes #{prefix()}-spin {
        from {
          transform: rotate(0deg);
        }
        to {
          transform: rotate(360deg);
        }
      }
      """,
      Enum.map(tinted, fn v ->
        path = [c.name, v.name]

        prepend(
          axis_doc(c, v),
          rule(path, selector(path), [declarations(path, except: [:foreground]), filter(path)])
        )
      end)
    ]
  end

  defp blocks(%{name: :checkbox} = c) do
    n = [c.name]

    checked = fn path ->
      [
        declarations(path, except: [:foreground]),
        "background-image: #{String.replace(@check_mark, "FILL", check_color(path))}",
        "background-size: 100% 100%",
        "background-position: center",
        "background-repeat: no-repeat"
      ]
    end

    [
      rule(n, ".#{class(n)}", [
        "appearance: none",
        declarations(n),
        "cursor: pointer",
        placed(n, :transition, &"transition: all #{&1}")
      ]),
      states(n, c, @control, %{checked: checked}),
      variants(c, fn _ -> true end, @control)
    ]
  end

  defp blocks(%{name: :tag} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: inline-flex",
        "align-items: center",
        "justify-content: center",
        declarations(n)
      ]),
      part(c, :inner, fn path ->
        [
          "display: flex",
          "flex-direction: column",
          "justify-content: center",
          "align-items: center",
          declarations(path)
        ]
      end),
      states(n, c, @element),
      variants(c, fn _ -> true end, @element)
    ]
  end

  defp blocks(%{name: :alert} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: flex",
        "justify-content: center",
        "align-items: center",
        declarations(n)
      ]),
      states(n, c, @element),
      variants(c, fn _ -> true end, @element)
    ]
  end

  defp blocks(%{name: :number_icon} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: flex",
        "align-items: center",
        "justify-content: center",
        "flex-shrink: 0",
        declarations(n),
        "font-variant-numeric: tabular-nums"
      ]),
      states(n, c, @element),
      variants(c, fn _ -> true end, @element)
    ]
  end

  # ------------------------------------------------------------ shared rules

  # The variants of the axes `axis?` picks, in the design's order: each variant's
  # rule, its parts and its states. An axis's doc goes above its first variant.
  defp variants(c, axis?, selectors) do
    for v <- c.variants, axis?.(v.axis), do: prepend(axis_doc(c, v), variant(c, v, selectors))
  end

  defp variant(c, v, selectors) do
    path = [c.name, v.name]
    own = if web_style(v) == [], do: [], else: [rule(selector(path), declarations(path))]

    parts =
      for p <- v.parts,
          do: rule(selector(path ++ [p.name]), declarations(path ++ [p.name]))

    with_doc(path, own ++ parts ++ states(path, v, selectors))
  end

  # A node's states, the loading state apart (`loading/1`): each state's rule, then
  # the parts it changes. `custom` writes a state's declarations itself.
  defp states(path, node, selectors, custom \\ %{}) do
    for s <- node.states, s.name != :loading do
      state = path ++ [s.name]
      lines = Map.get(custom, s.name, &declarations/1).(state)
      cursor = if s.name == :disabled, do: ["cursor: not-allowed"], else: []

      sel =
        case selectors[s.name] do
          nil -> "." <> class(state)
          suffix -> selector(path, suffix)
        end

      [rule(state, sel, lines ++ cursor) | Enum.map(s.parts, &state_part(sel, state, &1))]
    end
  end

  # A part while its component is in a state: `<state selector> .<part class>`.
  defp state_part(sel, state, part),
    do: rule("#{sel} .#{class([hd(state), part.name])}", declarations(state ++ [part.name]))

  # While loading, the parts change, and a part that is another component (a
  # spinner) sits in the middle.
  defp loading(c) do
    case state(c, :loading) do
      nil ->
        []

      s ->
        state = [c.name, :loading]

        spinners =
          for %{component: ref} = p <- c.parts, ref != nil do
            margin = css_length(-get([ref], :size) / 2)

            rule(".#{class(state)} .#{class([c.name, p.name])}", [
              "position: absolute",
              "top: 50%",
              "left: 50%",
              {:raw,
               "  /* Use margins instead of transform for centering because\n" <>
                 "     the spinner animation uses transform: rotate() which would\n" <>
                 "     override translate(-50%, -50%) centering */"},
              "margin-top: #{margin}",
              "margin-left: #{margin}"
            ])
          end

        [
          rule(state, ".#{class(state)}", ["position: relative", declarations(state)])
          | Enum.map(s.parts, &state_part(".#{class(state)}", state, &1))
        ] ++ spinners
    end
  end

  # A part the component declares: its rule, from `lines`, then its states. A
  # dropdown's input is a form control; any other part is an element.
  defp part(c, name, lines) do
    case Enum.find(c.parts, &(&1.name == name)) do
      nil ->
        []

      p ->
        path = [c.name, name]
        selectors = if name == :input, do: @control, else: @element
        [rule(path, selector(path), lines.(path)), states(path, p, selectors)]
    end
  end

  defp placeholder(path) do
    if has?(path, :placeholder),
      do: rule(selector(path, "::placeholder"), ["color: #{value(path, :placeholder)}"]),
      else: []
  end

  defp filter(path) do
    color = path |> get(:foreground) |> resolve_color()

    value =
      case web(path, :filter) do
        nil when color == "#FFFFFF" ->
          "brightness(0) invert(1)"

        nil when color == "#000000" ->
          "brightness(0)"

        nil ->
          raise ArgumentError,
                "#{label(path)}: the web tints the spinner with a CSS filter; give it web: [filter: [color: #{inspect(color)}, value: ...]]"

        filter ->
          unless filter[:color] == color,
            do:
              raise(
                ArgumentError,
                "#{label(path)}: its web filter was made for #{filter[:color]}, but its color is #{color}; make one for #{color}"
              )

          filter[:value]
      end

    {:raw, wrap("  filter: #{value};")}
  end

  # Wrapped like prettier at 80 columns: words on a line while they fit.
  defp wrap(line) do
    [first | words] = String.split(line, " ")

    words
    |> Enum.reduce([first], fn word, [current | done] ->
      if String.length(current) + 1 + String.length(word) > 80,
        do: ["    " <> word, current | done],
        else: [current <> " " <> word | done]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  # The check mark's color in its SVG: white and black by name.
  defp check_color(path) do
    case path |> get(:foreground) |> resolve_color() do
      "#FFFFFF" -> "white"
      "#000000" -> "black"
      "#" <> hex -> "%23" <> String.downcase(hex)
    end
  end

  # ------------------------------------------------------------ rules and comments

  # A rule: `selector {`, its declarations one per line, and `}`; with the node's
  # doc above it when the node's path is given.
  defp rule(path \\ nil, selector, lines) do
    body =
      lines
      |> List.flatten()
      |> Enum.map_join("\n", fn
        {:raw, text} -> text
        line -> "  #{line};"
      end)

    "#{if path, do: comment(web(path, :doc)), else: ""}#{selector} {\n#{body}\n}\n"
  end

  # A variant's doc goes above the first of its rules.
  defp with_doc(path, rules) do
    case {web(path, :doc), List.flatten(rules)} do
      {nil, rules} -> rules
      {doc, [first | rest]} -> [comment(doc) <> first | rest]
      {_, []} -> []
    end
  end

  # Puts `comment` (an axis's doc) above the first of `rules`.
  defp prepend("", rules), do: rules

  defp prepend(comment, rules) do
    [first | rest] = List.flatten([rules])
    [comment <> first | rest]
  end

  defp axis_doc(c, v) do
    with %{} = axis <- Enum.find(c.axes, &(&1.name == v.axis)),
         [^v | _] <- Enum.filter(c.variants, &(&1.axis == v.axis)),
         doc when doc != nil <- axis.web[:doc] do
      read({:axis, c.name, v.axis, :doc})
      comment(doc)
    else
      _ -> ""
    end
  end

  defp comment(nil), do: ""
  defp comment(doc), do: "/* #{doc} */\n"

  # A component's blocks, with the banner of its section above the first.
  defp section(blocks, c) do
    case {web([c.name], :section), blocks} do
      {nil, blocks} ->
        Enum.join(blocks, "\n")

      {title, [first | rest]} ->
        bar = String.duplicate("=", 74)
        Enum.join(["/* #{bar}\n   #{title}\n   #{bar} */\n\n" <> first | rest], "\n")
    end
  end

  # ------------------------------------------------------------ the design's values

  defp class(path) do
    case path |> nodes!() |> List.last() do
      {:component, c} -> base(c.name)
      {:part, %{component: ref}} when ref != nil -> base(ref)
      {_, node} -> "#{base(hd(path))}-#{key(node.name)}"
    end
  end

  # The selector of a component, variant or part, with `suffix` after it: one per
  # name of a variant with aliases, and a variant's part as a descendant.
  defp selector(path, suffix \\ "") do
    nodes = nodes!(path)

    alternatives =
      case tl(nodes) do
        [] ->
          [base(hd(path))]

        [{:part, _}] ->
          [class(path)]

        [{:variant, v} | part] ->
          for name <- [v.name | v.aliases] do
            "#{base(hd(path))}-#{key(name)}" <>
              Enum.map_join(part, fn _ -> " .#{class(path)}" end)
          end
      end

    Enum.map_join(alternatives, ",\n", &".#{&1}#{suffix}")
  end

  # A node's properties as declarations, in the design's order; `only:` and `except:`
  # pick some, for a rule whose mechanics come between them.
  defp declarations(path, opts \\ []) do
    path
    |> style()
    |> Enum.filter(fn {key, _} ->
      key not in @placed and (opts[:only] == nil or key in opts[:only]) and
        key not in Keyword.get(opts, :except, [])
    end)
    |> Enum.flat_map(fn {key, value} ->
      read({:value, path, key})
      declaration(key, value)
    end)
  end

  defp value(path, key, opts \\ []) do
    value = get(path, key)

    case key do
      k when k in [:background, :foreground, :placeholder] -> color(value)
      k when k in [:transition, :rotation] -> motion(value)
      :shadow -> shadow(value, Keyword.get(opts, :zero, "0"))
    end
  end

  defp get(path, key) do
    case Keyword.fetch(style(path), key) do
      {:ok, value} ->
        read({:value, path, key})
        value

      :error ->
        raise ArgumentError, "#{label(path)} has no #{key}"
    end
  end

  defp has?(path, key), do: Keyword.has_key?(style(path), key)

  # A declaration of a value the component writes in its own place, when it has one.
  defp placed(path, key, line),
    do: if(has?(path, key), do: line.(value(path, key)), else: [])

  # A node's look on the web: its shared style, with the properties of its web
  # binding in place of the shared ones.
  defp style(path), do: path |> node!() |> web_style()

  defp web_style(node) do
    overrides = Keyword.drop(node.web, @binding_keys)

    Enum.map(node.style, fn {key, value} -> {key, Keyword.get(overrides, key, value)} end) ++
      Keyword.drop(overrides, Keyword.keys(node.style))
  end

  defp web(path, key) do
    case Keyword.fetch(node!(path).web, key) do
      {:ok, value} ->
        read({:web, path, key})
        value

      :error ->
        nil
    end
  end

  defp state(c, name), do: Enum.find(c.states, &(&1.name == name))

  defp declaration(:background, value), do: ["background-color: #{color(value)}"]
  defp declaration(:foreground, value), do: ["color: #{color(value)}"]
  defp declaration(:border, value), do: line_style("border", value)

  defp declaration(:outline, value) do
    {offset, rest} = Keyword.split(value, [:offset])
    line = if rest == [], do: [], else: line_style("outline", rest)
    line ++ Enum.map(offset, fn {_, o} -> "outline-offset: #{css_length(o)}" end)
  end

  defp declaration(:radius, value), do: ["border-radius: #{radius(value)}"]
  defp declaration(:padding, value), do: insets("padding", value)
  defp declaration(:margin, value), do: insets("margin", value)
  defp declaration(:inset, value), do: sides(nil, value)
  defp declaration(:gap, value), do: ["gap: #{css_length(value)}"]

  defp declaration(:size, value),
    do: ["width: #{css_length(value)}", "height: #{css_length(value)}"]

  defp declaration(:height, value), do: ["height: #{css_length(value)}"]
  defp declaration(:min_height, value), do: ["min-height: #{css_length(value)}"]
  defp declaration(:max_height, value), do: ["max-height: #{max_height(value)}"]
  defp declaration(:weight, value), do: ["font-weight: #{value}"]
  defp declaration(:decoration, value), do: ["text-decoration: #{value}"]
  defp declaration(:shadow, value), do: ["box-shadow: #{shadow(value, "0")}"]
  defp declaration(:opacity, value), do: ["opacity: #{Web.number(value)}"]

  defp declaration(:typography, value) do
    {font, {size, line_height}} = typography(value)
    family = token!(:family, font.family).web
    italic = if font[:italic], do: ["font-style: italic"], else: []

    [
      "font-family: #{Web.css_str(family[:name])}, #{family[:fallback]}",
      "font-weight: #{font.weight}"
    ] ++ italic ++ ["font-size: #{css_length(size)}", "line-height: #{css_length(line_height)}"]
  end

  # `border: 2px solid #cccccc` with a width and a color; `border-color: …` with one.
  defp line_style(name, value) do
    if Keyword.has_key?(value, :width) and Keyword.has_key?(value, :color),
      do: ["#{name}: #{css_length(value[:width])} solid #{color(value[:color])}"],
      else:
        Enum.map(value, fn
          {:width, w} -> "#{name}-width: #{css_length(w)}"
          {:color, c} -> "#{name}-color: #{color(c)}"
        end)
  end

  # `padding: 15px 16px` for `[y:, x:]`; one declaration per side otherwise, in the
  # design's order (`x:` is left and right, `y:` top and bottom).
  defp insets(name, value) do
    if Enum.sort(Keyword.keys(value)) == [:x, :y] do
      {y, x} = {css_length(value[:y]), css_length(value[:x])}
      ["#{name}: #{if y == x, do: y, else: "#{y} #{x}"}"]
    else
      sides(name, value)
    end
  end

  defp sides(name, value) do
    for {side, size} <- value, side <- expand(side) do
      if name, do: "#{name}-#{side}: #{css_length(size)}", else: "#{side}: #{css_length(size)}"
    end
  end

  defp expand(:x), do: [:left, :right]
  defp expand(:y), do: [:top, :bottom]
  defp expand(side), do: [side]

  defp css_length(n) when is_number(n) and n == 0, do: "0"
  defp css_length(n) when is_number(n), do: "#{Web.number(n)}px"
  defp css_length({n, :rem}), do: "#{Web.number(n)}rem"
  defp css_length({n, :percent}), do: "#{Web.number(n)}%"

  defp color(:transparent), do: "transparent"

  defp color({ref, alpha}) do
    {r, g, b} = Web.rgb(resolve_color(ref))
    "rgba(#{r}, #{g}, #{b}, #{Web.number(alpha)})"
  end

  defp color(value), do: value |> resolve_color() |> String.downcase()

  defp resolve_color("#" <> _ = hex), do: hex
  defp resolve_color({ref, _alpha}), do: resolve_color(ref)

  defp resolve_color(ref) do
    case token!(:color, ref).value do
      next when is_atom(next) -> resolve_color(next)
      hex -> hex
    end
  end

  defp radius(ref) when is_atom(ref), do: css_length(token!(:radius, ref).value)
  defp radius(value), do: css_length(value)

  defp max_height(ref) when is_atom(ref), do: css_length(token!(:max_height, ref).value)
  defp max_height(value), do: css_length(value)

  defp shadow(ref, zero), do: Web.shadow_css(tokens(), resolve_shadow(ref), zero: zero)

  defp resolve_shadow(ref) do
    case token!(:shadow, ref).value do
      next when is_atom(next) -> resolve_shadow(next)
      value -> value
    end
  end

  defp motion({ms, easing}),
    do: "#{Web.number(ms / 1000)}s #{easing |> Atom.to_string() |> String.replace("_", "-")}"

  # A typography token or [font:, text:] to the font token and {size, line height}.
  defp typography(ref) when is_atom(ref) do
    t = token!(:typography, ref)
    typography(font: t.font, text: t.text)
  end

  defp typography(pair) do
    size =
      case pair[:text] do
        {size, line_height} -> {size, line_height}
        ref -> {token!(:text, ref).size, token!(:text, ref).line_height}
      end

    {token!(:font, pair[:font]), size}
  end

  # ------------------------------------------------------------ the design

  defp tokens, do: Process.get(@design).tokens
  defp prefix, do: Process.get(@design).web.prefix

  defp token!(kind, name),
    do:
      Enum.find(tokens(), &(&1.kind == kind and &1.name == name)) ||
        raise(ArgumentError, "no #{kind} #{inspect(name)}")

  defp base(component), do: "#{prefix()}-#{key(component)}"
  defp key(name), do: name |> Atom.to_string() |> String.replace("_", "-")

  defp node!(path), do: path |> nodes!() |> List.last() |> elem(1)

  # The nodes along a path, each as {kind, node}.
  defp nodes!([name | names] = path) do
    component =
      Enum.find(Process.get(@design).components, &(&1.name == name)) ||
        raise(ArgumentError, "no component #{inspect(name)}")

    read({:node, path})

    names
    |> Enum.reduce([{:component, component}], fn name, [{_, node} | _] = acc ->
      case Enum.find(children(node), fn {_, child} -> child.name == name end) do
        nil -> raise ArgumentError, "#{label(path)}: no #{inspect(name)} there"
        child -> [child | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp children(node) do
    for kind <- [:part, :variant, :state],
        child <- Map.get(node, :"#{kind}s", []),
        do: {kind, child}
  end

  defp label(path), do: Enum.map_join(path, ".", &Atom.to_string/1)

  defp read(entry), do: Process.put(@read, MapSet.put(Process.get(@read), entry))

  # Every node, value and web key of the design is in the file.
  defp covered!(design) do
    read = Process.get(@read)
    nodes = for {:node, path} <- read, do: path

    missing =
      for c <- design.components,
          entry <- walk(c, [c.name]) ++ axes(c),
          not covered?(entry, read, nodes),
          do: describe(entry)

    if missing != [],
      do: raise(ArgumentError, "the web target writes nothing for #{Enum.join(missing, ", ")}")
  end

  defp walk(node, path) do
    values = for {key, _} <- web_style(node), do: {:value, path, key}
    keys = for {key, _} <- Keyword.take(node.web, @binding_keys), do: {:web, path, key}

    children =
      for {_, child} <- children(node), entry <- walk(child, path ++ [child.name]), do: entry

    [{:node, path} | values] ++ keys ++ children
  end

  defp axes(c), do: for(a <- c.axes, {key, _} <- a.web, do: {:axis, c.name, a.name, key})

  defp covered?({:node, path}, _, nodes), do: Enum.any?(nodes, &List.starts_with?(&1, path))
  defp covered?(entry, read, _), do: entry in read

  defp describe({:node, path}), do: label(path)
  defp describe({:value, path, key}), do: "#{label(path)} #{key}"
  defp describe({:web, path, key}), do: "#{label(path)} web: #{key}"
  defp describe({:axis, c, axis, key}), do: "#{c} variants #{inspect(axis)} web: #{key}"
end
