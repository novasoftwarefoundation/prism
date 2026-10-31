defmodule Prism.Generator.Web.Components do
  @moduledoc """
  Writes `css/components.css` from a design's components. The design holds the
  look, which every target shares; this module holds the web's mechanics of
  each component it knows: display and layout, cursors, focus outlines,
  appearance resets, keyframes, the check mark and spinner images, and how a
  state becomes a selector.

  Its mechanics are keyed on component and part names. It knows these
  components (`kinds/0`): `:button`, `:text_field`, `:text_area`, `:field`,
  `:radio_group`, `:radio`, `:select`, `:spinner`, `:checkbox`, `:tag`,
  `:message_bar` and `:step_indicator`, and these parts of them (`parts/0`):
  the button's `:label` and `:icon`, the field's `:label` and
  `:error_message`, the radio's `:control` and `:label`, the select's
  `:field`, `:icon`, `:listbox` and `:option`, the tag's `:label`, and on any
  component a part that is another component. A design component it doesn't
  know fails generation, and so does a part it doesn't write. Each component
  writes the variants and states the design gives it, so a new variant needs
  no change here.

  ## Classes

  A class is made of the design's names, with `-` for `_`, and says what
  kind of name it is, as in BEM. The names come from
  `Prism.Generator.Web.Classes`, which the Phoenix components
  (`Prism.Generator.Phoenix`) use too:

  - a component is `.<prefix>-<component>` (`.acme-button`);
  - a part is `__<part>` after its component (`.acme-button__label`); a part
    that is another component has that component's class;
  - a variant, of any axis, is `--<variant>` (`.acme-button--primary`): the
    schema keeps a component's variant names unique across its axes;
  - a state that is no pseudo-class is `--<state>` after the component, or
    after the part it belongs to (`.acme-button--loading`,
    `.acme-select__option--selected`);
  - a look while the component has a part is `--with-<part>`
    (`.acme-button--with-icon`), combined with a variant's class when the
    variant gives it (`.acme-button--primary.acme-button--with-icon`);
  - a look with a variant of another axis is the two variants' classes
    together, the other variant's first (`.acme-button--secondary.acme-button--danger`
    for a `with_variant :secondary` in the tone `danger`);
  - a flag is `--<flag>` (`.acme-button--padded`), after the variant's
    class for its look with a variant (`.acme-button--text.acme-button--padded`).

  So a part never reads as a variant: `.acme-button__label` and
  `.acme-button--text` can't be confused, and a variant may have a part's name
  (`.acme-button--icon`, `.acme-button__icon`). A variant's aliases get a
  selector each.

  ## States

  On a form control (a button, a text field and a text area, the checkbox,
  the radio's control and the select's field; `Prism.Generator.Web.Classes`
  knows which) a state is the browser's:
  `:pressed` is `:active`, `:hovered` `:hover`, `:focused` `:focus`,
  `:disabled` `:disabled`, `:checked` `:checked`. On any other element
  `:hovered` is `:hover`. Any other state, such as `:loading`, `:invalid` or
  an option's `:selected`, is a modifier class the app sets.

  ## The `web:` binding

  The web reads a node's `web:` binding before its shared look: a property in
  it replaces the shared value, on the web only. Besides the properties, the
  web knows these keys (`bindings/0`):

  - `section:` (a component) the banner comment that starts its section;
  - `doc:` (any node, and a `variants` axis) the comment above its first rule.

  Some values can't be written on the web, so the schema refuses them at
  compile time, on their line: the checkbox's check mark can't have a color
  with alpha or `:transparent`, because it is drawn into an image; a spinner
  has no background, because it is drawn in its foreground color; and a
  spinner's size is px or rem, because a loading button centers it by half
  its size, as it does any part that is another component, whose size must be
  px or rem too.

  Generation fails when a value or a `web:` key of the design is written
  nowhere, so nothing in the design is ignored.

  ## The spinner

  A spinner is an image used as a mask over the spinner's text color
  (`background-color: currentColor`). The image is inline, a `data:` URI like
  the check mark's, because an app imports this CSS into its own stylesheet,
  where a relative URL would resolve against the app. Its color is its `foreground`, an
  ordinary color. A button hides a part that is another component unless it
  is loading.

  ## Spelling

  The spelling is fixed, so regenerating gives the same bytes: lower-case hex,
  `rgba(r, g, b, alpha)` for colors with alpha, `0` for zero lengths and in box
  shadows (`0px` in the select's list), and seconds for durations.
  """

  alias Prism.Generator.Web
  alias Prism.Generator.Web.Classes

  @kinds [
    :button,
    :text_field,
    :text_area,
    :field,
    :radio_group,
    :radio,
    :select,
    :spinner,
    :checkbox,
    :tag,
    :message_bar,
    :step_indicator
  ]

  # The parts each component writes, besides parts that are other components.
  @parts %{
    button: [:label, :icon],
    field: [:label, :error_message],
    radio: [:control, :label],
    select: [:field, :icon, :listbox, :option],
    tag: [:label]
  }

  @bindings %{
    component: [:section, :doc],
    variants: [:doc],
    variant: [:doc],
    part: [:doc],
    with_part: [:doc],
    with_variant: [:doc],
    flag: [:doc],
    state: [:doc]
  }

  @binding_keys @bindings |> Map.values() |> List.flatten() |> Enum.uniq()

  # Properties without a CSS declaration of their own: each component writes them
  # where they belong (`transition: all …`, `::placeholder`).
  @placed [:transition, :rotation, :placeholder]

  @check_mark "url(\"data:image/svg+xml,%3csvg viewBox='0 0 16 16' fill='FILL' xmlns='http://www.w3.org/2000/svg'%3e%3cpath d='M12.207 4.793a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0l-2-2a1 1 0 011.414-1.414L6.5 9.086l4.293-4.293a1 1 0 011.414 0z'/%3e%3c/svg%3e\")"

  # The spinner: a ring at a quarter of its opacity, and a quarter of it opaque. As
  # a mask only its alpha counts, so the spinner takes its color from the CSS. It
  # is inline, like the check mark: an app imports this CSS into its own, where a
  # relative URL would point into the app.
  @spinner_image "url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none'%3e%3ccircle cx='12' cy='12' r='10' stroke='black' stroke-opacity='0.25' stroke-width='4'/%3e%3cpath d='M22 12a10 10 0 0 0-10-10' stroke='black' stroke-width='4' stroke-linecap='round'/%3e%3c/svg%3e\")"
  @spinner_mask "#{@spinner_image} center / contain no-repeat"

  @design {__MODULE__, :design}
  @read {__MODULE__, :read}

  @doc "The components the web target knows."
  def kinds, do: @kinds

  @doc "The parts each component writes, besides parts that are other components."
  def parts, do: @parts

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

  @doc false
  # Checks, for the schema, a value the web writes in its own way at `place` (the
  # node's path as `[{kind, name}]`): the check mark is drawn into an image, a
  # spinner is drawn in its foreground color, and a spinner's size is halved to
  # center it.
  def check_value(place, key, value) do
    case {hd(place), List.last(place), key, value} do
      {{:component, :checkbox}, {:state, :checked}, :foreground, color} ->
        solid(color, "the check mark is an image in this color")

      {{:component, :spinner}, _, :background, _} ->
        {:error,
         "a spinner is drawn in its foreground color over no background; give it a foreground"}

      {{:component, :spinner}, _, :size, {_, :percent}} ->
        {:error,
         "a button centers its spinner by half the spinner's size, which a percentage can't give; use px or rem"}

      _ ->
        :ok
    end
  end

  @doc false
  # Checks, for the schema, a part of `component` that is the component `other`: a
  # loading button centers it by half its size, so its size is px or rem.
  def check_part(%{name: :button} = component, other) do
    loading? = Enum.any?(component.states, &(&1.name == :loading))

    case web_style(other)[:size] do
      _ when not loading? ->
        :ok

      nil ->
        {:error,
         "a loading button centers #{inspect(other.name)} by half its size, and #{inspect(other.name)} has none; give it a size in px or rem"}

      {_, :percent} ->
        {:error,
         "a loading button centers #{inspect(other.name)} by half its size, which a percentage can't give; give it a size in px or rem"}

      _ ->
        :ok
    end
  end

  def check_part(_component, _other), do: :ok

  defp solid(color, why) when is_tuple(color) or color == :transparent,
    do:
      {:error, "#{why}, so it has no alpha: give a color without {color, alpha} or :transparent"}

  defp solid(_, _), do: :ok

  @doc false
  # The body of css/components.css for a design's `__schema__/0`.
  def css(%{components: components, web: web} = design) do
    for c <- components, c.name not in @kinds do
      raise ArgumentError,
            "the web target has no component #{inspect(c.name)}; it knows #{Enum.map_join(@kinds, ", ", &inspect/1)}"
    end

    # A part the web doesn't write fails, also one without a look of its own that
    # only a variant or a state changes.
    for c <- components, %{component: nil} = p <- c.parts do
      known = Map.get(@parts, c.name, [])

      unless p.name in known,
        do:
          raise(
            ArgumentError,
            "the web target has no part #{inspect(p.name)} of #{inspect(c.name)}; " <>
              if(known == [],
                do: "it writes only parts that are other components there",
                else: "it knows #{Enum.map_join(known, ", ", &inspect/1)}"
              )
          )
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

  defp blocks(%{name: :button} = c) do
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
      part(c, :label, &declarations/1),
      part(c, :icon, &declarations/1),
      own(n, c, pseudo(c)),
      variants(c, &(&1 == :variant), pseudo(c)),
      loading(c),
      variants(c, &(&1 != :variant), pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  defp blocks(%{name: kind} = c) when kind in [:text_field, :text_area] do
    n = [c.name]
    resize = if kind == :text_area, do: ["resize: vertical"], else: []

    [
      rule(
        n,
        ".#{class(n)}",
        ["display: block", "width: 100%", declarations(n), "outline: none"] ++
          resize ++ [placed(n, :transition, &"transition: border-color #{&1}")]
      ),
      placeholder(n),
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  # A label and an error message around a control.
  defp blocks(%{name: :field} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [declarations(n)]),
      part(c, :label, &["display: block", declarations(&1)]),
      part(c, :error_message, &declarations/1),
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  defp blocks(%{name: :radio_group} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", ["display: flex", "flex-direction: row", declarations(n)]),
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  # One option of a radio group: a label element around the control and its label.
  defp blocks(%{name: :radio} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: flex",
        "flex-direction: row",
        "align-items: center",
        declarations(n),
        "cursor: pointer"
      ]),
      own(n, c, pseudo(c)),
      part(c, :control, fn path ->
        [
          "appearance: none",
          declarations(path),
          "cursor: pointer",
          placed(path, :transition, &"transition: all #{&1}")
        ]
      end),
      case Enum.find(c.parts, &(&1.name == :control)) do
        %{states: states} ->
          if Enum.any?(states, &(&1.name == :disabled)),
            do: [],
            else: rule(".#{class([c.name, :control])}:disabled", ["cursor: not-allowed"])

        nil ->
          []
      end,
      part(c, :label, fn path ->
        [
          declarations(path, except: [:margin]),
          "user-select: none",
          declarations(path, only: [:margin])
        ]
      end),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  defp blocks(%{name: :select} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", ["position: relative", "width: 100%", declarations(n)]),
      part(c, :field, fn path ->
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
      part(c, :listbox, fn path ->
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
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  # The spinner image, as a mask over the spinner's color, turning; the variants
  # that give a color come after the keyframes.
  defp blocks(%{name: :spinner} = c) do
    n = [c.name]
    colors = &Keyword.has_key?(web_style(&1), :foreground)

    [
      rule(n, ".#{class(n)}", [
        "display: inline-block",
        declarations(n),
        "background-color: currentColor",
        "-webkit-mask: #{@spinner_mask}",
        "mask: #{@spinner_mask}",
        placed(n, :rotation, &"animation: #{prefix()}-spin #{&1} infinite")
      ]),
      own(n, c, pseudo(c)),
      for(v <- c.variants, not colors.(v), do: axis_variant(c, v, pseudo(c))),
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
      for(v <- c.variants, colors.(v), do: axis_variant(c, v, pseudo(c))),
      flags(c, pseudo(c))
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
      states(n, c, pseudo(c), %{checked: checked}),
      with_parts(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
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
      part(c, :label, fn path ->
        [
          "display: flex",
          "flex-direction: column",
          "justify-content: center",
          "align-items: center",
          declarations(path)
        ]
      end),
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  defp blocks(%{name: :message_bar} = c) do
    n = [c.name]

    [
      rule(n, ".#{class(n)}", [
        "display: flex",
        "justify-content: center",
        "align-items: center",
        declarations(n)
      ]),
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  defp blocks(%{name: :step_indicator} = c) do
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
      own(n, c, pseudo(c)),
      variants(c, fn _ -> true end, pseudo(c)),
      flags(c, pseudo(c))
    ]
  end

  # ------------------------------------------------------------ shared rules

  # A component's own states and its looks with a part.
  defp own(path, c, selectors), do: [states(path, c, selectors), with_parts(path, c, selectors)]

  # The variants of the axes `axis?` picks, in the design's order: each variant's
  # rule, its parts, its states and its looks with a part. An axis's doc goes above
  # the first of its variants that has a rule.
  defp variants(c, axis?, selectors) do
    for v <- c.variants, axis?.(v.axis), do: axis_variant(c, v, selectors)
  end

  # A variant's rules, with its axis's doc above them when it is the axis's first
  # variant that has a rule. An axis whose variants have none writes its doc nowhere.
  defp axis_variant(c, v, selectors) do
    case List.flatten([variant(c, v, selectors)]) do
      [] -> []
      [first | rest] -> [axis_doc(c, v, selectors) <> first | rest]
    end
  end

  defp variant(c, v, selectors) do
    path = [c.name, {:variant, v.name}]

    parts =
      for p <- v.parts do
        part = path ++ [p.name]
        [rule(selector(part), declarations(part)) | states(part, p, selectors)]
      end

    with_doc(
      path,
      [rule(selector(path), declarations(path)) | parts] ++
        states(path, v, selectors) ++
        with_parts(path, v, selectors) ++ with_variants(path, v, selectors)
    )
  end

  # A variant's or a flag's looks with another variant: the rule, then its states.
  defp with_variants(path, node, selectors) do
    for w <- node.with_variants do
      with_path = path ++ [{:with_variant, w.name}]

      with_doc(with_path, [
        rule(selector(with_path), declarations(with_path)) | states(with_path, w, selectors)
      ])
    end
  end

  # The component's flags, after its variants: each flag's own rule and states,
  # then its looks with a variant.
  defp flags(c, selectors) do
    for f <- c.flags do
      path = [c.name, f.name]

      with_doc(
        path,
        [rule(selector(path), declarations(path)) | states(path, f, selectors)] ++
          with_variants(path, f, selectors)
      )
    end
  end

  # A component's or a variant's looks while the component has a part: the rule,
  # then its states.
  defp with_parts(path, node, selectors) do
    for w <- node.with_parts do
      with_path = path ++ [w.name]

      with_doc(with_path, [
        rule(selector(with_path), declarations(with_path)) | states(with_path, w, selectors)
      ])
    end
  end

  # A node's states, the loading state apart (`loading/1`): each state's rule, then
  # the parts it changes. `custom` writes a state's declarations itself. A state
  # without a pseudo-class is a modifier class: on its own for a state of a
  # component or one of its parts (`.acme-text-field--invalid`,
  # `.acme-select__option--selected`), inside the variant for a state of a variant's
  # part (`.acme-tag--accent .acme-tag__label--selected`), on the variant or look it
  # belongs to otherwise (`.acme-tag--accent.acme-tag--invalid`).
  defp states(path, node, selectors, custom \\ %{}) do
    for s <- node.states, s.name != :loading, sel = state_selector(path, s, selectors) do
      state = path ++ [s.name]
      lines = Map.get(custom, s.name, &declarations/1).(state)
      cursor = if s.name == :disabled, do: ["cursor: not-allowed"], else: []

      with_doc(state, [
        rule(sel, lines ++ cursor) | Enum.map(s.parts, &state_part(sel, state, &1))
      ])
    end
  end

  # A state's selector, or `nil` for a state the markup can't show, which is then
  # written nowhere, so generation fails.
  defp state_selector(path, s, selectors) do
    state = path ++ [s.name]

    case {selectors_for(path, selectors)[s.name], nodes!(path)} do
      {nil, [{:component, _}]} -> "." <> class(state)
      {nil, [{:component, _}, {:part, _}]} -> "." <> class(state)
      {nil, [{:component, c}, {:variant, _}, {:part, p}]} -> variant_part(c, p, path, state)
      {nil, _} -> selector(path, "." <> class(state))
      {suffix, _} -> selector(path, suffix)
    end
  end

  # A variant's part in a state the app sets: the part's modifier class inside the
  # variant, once per name of the variant. The markup gives a part that is another
  # component no modifier class, so there the state has no selector, as outside a
  # variant.
  defp variant_part(c, p, path, state) do
    case Enum.find(c.parts, &(&1.name == p.name)) do
      %{component: nil} -> selector(Enum.take(path, 2), " ." <> class(state))
      _ -> nil
    end
  end

  # The states of a part that is a form control are the browser's; any other part
  # is an element.
  defp selectors_for(path, selectors) do
    case path |> nodes!() |> Enum.reverse() |> Enum.find(&match?({:part, _}, &1)) do
      nil -> selectors
      {:part, p} -> Classes.pseudo_classes(hd(path), p.name)
    end
  end

  # A part while its component is in a state: the part's class after each of the
  # state's selectors (`.a:hover .acme-tag__label, .b:hover .acme-tag__label`).
  defp state_part(sel, state, part) do
    descendant = " ." <> class([hd(state), part.name])

    sel
    |> String.split(",\n")
    |> Enum.map_join(",\n", &(&1 <> descendant))
    |> rule(declarations(state ++ [part.name]))
  end

  # While loading, the parts change, and a part that is another component (a
  # spinner) sits in the middle; while not loading, that part is hidden.
  defp loading(c) do
    case state(c, :loading) do
      nil ->
        []

      s ->
        state = [c.name, :loading]

        spinners =
          for %{component: ref} = p <- c.parts, ref != nil do
            margin = [ref] |> get(:size) |> half() |> css_length()

            [
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
              ]),
              rule(".#{class([c.name])}:not(.#{class(state)}) .#{class([c.name, p.name])}", [
                "display: none"
              ])
            ]
          end

        [
          rule(state, ".#{class(state)}", ["position: relative", declarations(state)])
          | Enum.map(s.parts, &state_part(".#{class(state)}", state, &1))
        ] ++ spinners
    end
  end

  # A part the component declares: its rule, from `lines`, then its states.
  defp part(c, name, lines) do
    case Enum.find(c.parts, &(&1.name == name)) do
      nil ->
        []

      p ->
        path = [c.name, name]

        [
          rule(path, selector(path), lines.(path)),
          states(path, p, Classes.pseudo_classes(c.name, name))
        ]
    end
  end

  defp placeholder(path) do
    if has?(path, :placeholder),
      do: rule(selector(path, "::placeholder"), ["color: #{value(path, :placeholder)}"]),
      else: []
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
  # doc above it when the node's path is given. A rule without declarations is
  # left out.
  defp rule(path \\ nil, selector, lines) do
    case List.flatten(lines) do
      [] ->
        []

      lines ->
        body =
          Enum.map_join(lines, "\n", fn
            {:raw, text} -> text
            line -> "  #{line};"
          end)

        "#{if path, do: comment(web(path, :doc)), else: ""}#{selector} {\n#{body}\n}\n"
    end
  end

  # A node's doc goes above the first of its rules; a node without rules has none.
  defp with_doc(path, rules) do
    case List.flatten(rules) do
      [] -> []
      [first | rest] -> [comment(web(path, :doc)) <> first | rest]
    end
  end

  defp axis_doc(c, v, selectors) do
    with %{} = axis <- Enum.find(c.axes, &(&1.name == v.axis)),
         [^v | _] <-
           Enum.filter(
             c.variants,
             &(&1.axis == v.axis and List.flatten([variant(c, &1, selectors)]) != [])
           ),
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

  # The class of the last node of `path` (see the moduledoc). A part's class comes
  # from the part the component declares, so a variant's or a state's change to a
  # part that is another component has that component's class.
  defp class(path) do
    [{:component, c} | _] = nodes = nodes!(path)

    case List.last(nodes) do
      {:component, _} ->
        Classes.component(prefix(), c.name)

      {:part, part} ->
        # A rule for a variant's or a state's change to the part writes the part.
        read({:node, [c.name, part.name]})
        Classes.part(prefix(), c, part.name)

      # A part's state modifies the part's class, any other state the component's.
      {:state, s} ->
        case Enum.at(nodes, -2) do
          {:part, part} -> Classes.part_modifier(prefix(), c, part.name, s.name)
          _ -> Classes.modifier(prefix(), c.name, s.name)
        end

      # A variant, or a look with a part (`with_icon`).
      {_, node} ->
        Classes.modifier(prefix(), c.name, node.name)
    end
  end

  # The selector of a component, variant, part or look with a part, with `suffix`
  # after it: one per name of a variant with aliases, a variant's part as a
  # descendant, and a variant's look with a part on the same element.
  defp selector(path, suffix \\ "") do
    nodes = nodes!(path)

    [{:component, c} | _] = nodes
    modifier = &Classes.modifier(prefix(), c.name, &1)

    alternatives =
      case tl(nodes) do
        [] ->
          [Classes.component(prefix(), c.name)]

        [{kind, _}] when kind in [:part, :with_part, :flag] ->
          [class(path)]

        # A flag's look with a variant: the variant's class, then the flag's.
        [{:flag, f}, {:with_variant, w}] ->
          for other <- names(c, w.name), do: "#{modifier.(other)}.#{modifier.(f.name)}"

        [{:variant, v} | rest] ->
          own = for name <- names(c, v.name), do: modifier.(name)

          Enum.reduce(rest, own, fn
            {:part, _}, acc ->
              Enum.map(acc, &"#{&1} .#{class(path)}")

            {:with_part, _}, acc ->
              Enum.map(acc, &"#{&1}.#{class(path)}")

            # The other variant's class first.
            {:with_variant, w}, acc ->
              for other <- names(c, w.name), sel <- acc, do: "#{modifier.(other)}.#{sel}"
          end)
      end

    Enum.map_join(alternatives, ",\n", &".#{&1}#{suffix}")
  end

  # A variant's names: its own and its aliases.
  defp names(c, name) do
    v = Enum.find(c.variants, &(&1.name == name))
    [v.name | v.aliases]
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

  # Minus half a length, to center something of that size (a spinner) by its margins.
  defp half(n) when is_number(n), do: -n / 2
  defp half({n, :rem}), do: {-n / 2, :rem}

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

  # The states that are the browser's on a component's own element.
  defp pseudo(c), do: Classes.pseudo_classes(c.name, nil)

  defp node!(path), do: path |> nodes!() |> List.last() |> elem(1)

  # The nodes along a path, each as {kind, node}. A variant and a look with a
  # variant are `{kind, name}` in a path, since a variant may share its name with a
  # part; every other node is its name.
  defp nodes!([name | names] = path) do
    component =
      Enum.find(Process.get(@design).components, &(&1.name == name)) ||
        raise(ArgumentError, "no component #{inspect(name)}")

    read({:node, path})

    names
    |> Enum.reduce([{:component, component}], fn name, [{_, node} | _] = acc ->
      case Enum.find(children(node), fn {kind, child} -> path_name(kind, child) == name end) do
        nil -> raise ArgumentError, "#{label(path)}: no #{inspect(name)} there"
        child -> [child | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp children(node) do
    for kind <- [:part, :variant, :with_part, :with_variant, :flag, :state],
        child <- Map.get(node, :"#{kind}s", []),
        do: {kind, child}
  end

  defp path_name(kind, node) when kind in [:variant, :with_variant], do: {kind, node.name}
  defp path_name(_kind, node), do: node.name

  defp label(path) do
    Enum.map_join(path, ".", fn
      {_kind, name} -> Atom.to_string(name)
      name -> Atom.to_string(name)
    end)
  end

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
      for {kind, child} <- children(node),
          entry <- walk(child, path ++ [path_name(kind, child)]),
          do: entry

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
