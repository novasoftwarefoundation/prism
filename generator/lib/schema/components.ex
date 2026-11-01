defmodule Prism.Generator.Schema.Components do
  @moduledoc """
  The component part of the schema: `component`, `style`, `variant`,
  `variants`, `part`, `with_part`, `with_variant`, `flag`, `state` and
  `value`. A design that uses `Prism.Generator.Schema` imports these macros.

      component :button, web: [section: "Buttons"] do
        style typography: :button, radius: :default, transition: {150, :ease_in_out}
        part :label
        part :icon
        part :spinner, component: :spinner

        variant :primary, background: :accent, foreground: :white, padding: [y: 15, x: 16] do
          state :pressed, padding: [top: 16, bottom: 14], shadow: :pressed
          state :disabled, opacity: 0.5

          with_part :icon, padding: [y: 4, x: 16], gap: 12 do
            state :pressed, padding: [top: 5, bottom: 3]
          end
        end

        state :loading do
          part :label, opacity: 0
        end

        variants :tone, default: :accent do
          variant :danger, background: :error
        end
      end

  A component is one concept, such as a button or a checkbox: how it looks and
  how its look changes in a state. What it does is never part of a design.

  - `style` is the component's own look, once per component.
  - A `variant` is a look to choose. Variants outside a `variants` block form
    the `:variant` axis; `variants :color do … end` adds a second axis, whose
    variants combine with one of the first. `aliases:` gives a variant more
    names. `default:` on the component (for the `:variant` axis) or on a
    `variants` block is the variant the axis has when the app picks none: one
    of its variants, or a name without a look of its own, such as `24` for a
    size axis whose 24 is the component's own look.
  - A variant's name is a snake_case atom, or a whole number above 0 for a
    variant named by a number it has, such as a size in px (`variant 16,
    size: 16`). An axis's variants, aliases and default are all names or
    all numbers.
  - A `part` is a named piece of the component (a label, an icon), in the
    order the design gives them. `component:` makes the part another component.
    A variant or a state may change a part's look by naming it again. A
    part's own state changes only that part; a state of the component may
    change any of its parts. `variants:` picks the other component's variants
    for a part that is one (`part :spinner, component: :spinner, variants:
    [size: 20]`): one variant per axis, by its name.
  - `with_part` is the look while the component has one of its parts, such
    as a button with an icon: in a component or a variant, it names a part
    the component declares. It is not a variant: whether the part is there
    decides it, not a choice of the app's.
  - `position:` on a part lets the app put it at the `:start` or the `:end`
    of the component's content (`start` and `end` follow the text's
    direction); its value is the side the part has when the app picks none.
  - `with_variant` is the look while the component has a variant of another
    axis too: in a variant, it names a variant of another axis
    (`with_variant :secondary, foreground: :error` in a tone); in a flag, a
    variant of any axis. A list (`with_variant [:plain, :text], …`) gives
    each of them the same look.
  - A `flag` is a look the app turns on or off, such as a button's padding:
    `default:` is `true` or `false` (the default) when the app sets nothing.
    Its own properties are its look on any variant, and its `with_variant`s
    its look with one.
  - A `state` changes the look while it holds. States have a fixed meaning that
    every target knows; see `states/0`. Where a state the app sets (such as
    `:invalid`) and `:pressed`, `:hovered` or `:focused` change one property
    of one element, the app's state wins (ADR 0008): an invalid field keeps
    its border while it has the focus.
  - A `value` is a number the app gives, from 0 to 100, that the look
    follows, such as a spinner's progress (`value :progress, stroke: {16,
    :percent}, track: :grey4`). Its properties are the look while the app
    gives it; without it, the component looks as it does without a value. A
    variant changes a value's look by naming it again (`value :progress,
    track: {:white, 0.3}` in `variant :inverse`).
    Each target knows the values of its components by name, and draws what
    follows the number (on the web, the length of a ring's arc).

  Every node takes `web:`, `ios:` and `android:`, its binding for that target:
  properties whose values replace the shared ones there, and keys of the
  target's own (for the web, `Prism.Generator.Web.Components`). The schema
  refuses a key the target doesn't know, and a value the target can't write.

  A look is a keyword list of properties, in the design's order. Each property
  has a type, and its value is a token reference or a literal of that type;
  see `properties/0`.
  """

  alias Prism.Generator.Schema

  @states [
    pressed: "while it is pressed",
    hovered: "while the pointer is over it",
    focused: "while it has the input focus",
    disabled: "while it can't be used",
    checked: "while a checkbox or radio is on",
    selected: "while it is the chosen one of several",
    loading: "while it is busy; the app sets it",
    invalid: "while its value is invalid; the app sets it"
  ]

  @properties [
    background: {:color, "the fill"},
    foreground: {:color, "text and icons"},
    placeholder: {:color, "the placeholder text of a field"},
    border: {:border, "[width: length, color: color], either may be left out"},
    outline: {:outline, "[width: length, color: color, offset: length], any may be left out"},
    radius: {:radius, "corner radius: a radius token or a length"},
    padding: {:insets, "space inside"},
    margin: {:insets, "space outside"},
    inset: {:insets, "distance from the edges of what holds it"},
    gap: {:length, "space between its children"},
    size: {:length, "width and height"},
    height: {:length, "height"},
    min_height: {:length, "minimum height"},
    max_height: {:max_height, "maximum height: a max_height token or a length"},
    typography:
      {:typography, "a typography token, or [font: font, text: text | {size, line_height}]"},
    weight: {:weight, "a font weight on top of the typography: 100, 200, …, 1000"},
    decoration: {:decoration, ":underline or :none"},
    shadow: {:shadow, "a shadow token"},
    opacity: {:opacity, "a number from 0 to 1"},
    transition: {:motion, "how changes animate: {milliseconds, easing}"},
    rotation: {:motion, "one full turn: {milliseconds, easing}"},
    stroke: {:length, "the width of the line it draws, such as a ring"},
    track: {:color, "the line beyond a value's length, such as a ring's rest"}
  ]

  @easings [:linear, :ease, :ease_in, :ease_out, :ease_in_out]
  @sides [:top, :right, :bottom, :left, :x, :y]

  # The options each kind of node takes besides its properties.
  @targets [:web, :ios, :android]

  @options %{
    component: [:default | @targets],
    variants: [:default | @targets],
    style: [],
    variant: [:aliases | @targets],
    part: [:component, :position, :variants | @targets],
    with_part: @targets,
    with_variant: @targets,
    flag: [:default | @targets],
    state: @targets,
    value: @targets
  }

  # The sides a part with `position:` may have.
  @positions [:start, :end]

  # What may be declared directly inside what; `nil` is the top of the design.
  @children %{
    nil => [:component],
    component: [:style, :variants, :variant, :part, :with_part, :flag, :state, :value],
    variants: [:variant],
    variant: [:part, :with_part, :with_variant, :state, :value],
    part: [:state],
    with_part: [:state],
    with_variant: [:state],
    flag: [:with_variant, :state],
    state: [:part],
    value: []
  }

  @doc "The states, with what each means: `[{name, meaning}]`."
  def states, do: @states

  @doc "The properties, with their type and meaning: `[{name, {type, meaning}}]`."
  def properties, do: @properties

  @doc """
  A component: `component :name, web: [section: "Buttons"] do … end`. Its
  options are `default:`, the default of its `:variant` axis, and its
  bindings, `web:`, `ios:` and `android:`. Its CSS class is
  made of its name (`.<prefix>-<name>`, with `-` for `_`); there is no option
  for it.
  """
  defmacro component(name, opts \\ [], block \\ []),
    do: node(:component, name, opts, block, __CALLER__)

  @doc "A component's own look: `style padding: [x: 12], radius: :default`."
  defmacro style(props) do
    quote do
      Prism.Generator.Schema.Components.__open__(
        __MODULE__,
        __ENV__.file,
        unquote(__CALLER__.line),
        :style,
        nil,
        unquote(props)
      )

      Prism.Generator.Schema.Components.__close__(__MODULE__)
    end
  end

  @doc """
  An axis of variants other than `:variant`: `variants :tone, default: :accent do … end`.
  `default:` is the axis's variant when the app picks none: one of its variants,
  or a name without a look of its own, which adds no class.
  """
  defmacro variants(axis, opts \\ [], block \\ []),
    do: node(:variants, axis, opts, block, __CALLER__)

  @doc "A variant: its look, and a block of the parts and states it changes."
  defmacro variant(name, props \\ [], block \\ []),
    do: node(:variant, name, props, block, __CALLER__)

  @doc "A part: its look, and a block of its states."
  defmacro part(name, props \\ [], block \\ []),
    do: node(:part, name, props, block, __CALLER__)

  @doc """
  The look while the component has one of its parts: `with_part :icon, gap: 12`,
  and a block of its states. `part` names a part the component declares.
  """
  defmacro with_part(part, props \\ [], block \\ []),
    do: node(:with_part, part, props, block, __CALLER__)

  @doc """
  The look while the component has another variant too: `with_variant :primary,
  background: :error`, and a block of its states. In a variant, it names a
  variant of another axis; in a flag, a variant of any axis. A list of
  variants gives each one the same look.
  """
  defmacro with_variant(names, props \\ [], block \\ [])

  defmacro with_variant(names, props, block) when is_list(names) do
    if names == [],
      do: fail(__CALLER__.file, __CALLER__.line, "with_variant []: name at least one variant")

    nodes = Enum.map(names, &node(:with_variant, &1, props, block, __CALLER__))
    quote do: (unquote_splicing(nodes))
  end

  defmacro with_variant(name, props, block),
    do: node(:with_variant, name, props, block, __CALLER__)

  @doc """
  A flag: a look the app turns on or off (`flag :padded, default: true do … end`).
  `default:` is `true` or `false` (the default), its state when the app sets
  nothing. Its properties are its look on any variant, and its block holds its
  looks with a variant (`with_variant`) and its states.
  """
  defmacro flag(name, props \\ [], block \\ []),
    do: node(:flag, name, props, block, __CALLER__)

  @doc "A state: the look while it holds, and a block of the parts it changes."
  defmacro state(name, props \\ [], block \\ []),
    do: node(:state, name, props, block, __CALLER__)

  @doc """
  A value: a number from 0 to 100 the app gives, and the look while it gives
  it (`value :progress, stroke: {16, :percent}, track: :grey4`).
  """
  defmacro value(name, props \\ []),
    do: node(:value, name, props, [], __CALLER__)

  # `variant :dark do … end` passes the block as the second argument.
  defp node(kind, name, [do: block], [], caller), do: node(kind, name, [], [do: block], caller)

  defp node(kind, name, props, block, caller) do
    cond do
      snake_case?(name) ->
        :ok

      kind in [:variant, :with_variant] ->
        unless number?(name),
          do:
            fail(
              caller.file,
              caller.line,
              "#{kind} #{Macro.to_string(name)}: name must be a snake_case atom or a whole number above 0"
            )

      true ->
        fail(
          caller.file,
          caller.line,
          "#{kind} #{Macro.to_string(name)}: name must be a snake_case atom"
        )
    end

    body = Keyword.get(block, :do)

    quote do
      Prism.Generator.Schema.Components.__open__(
        __MODULE__,
        __ENV__.file,
        unquote(caller.line),
        unquote(kind),
        unquote(name),
        unquote(props)
      )

      unquote(body)
      Prism.Generator.Schema.Components.__close__(__MODULE__)
    end
  end

  @doc false
  # Records a node and makes it the parent of what its block declares. Its place is
  # checked here, the rest when the design compiles.
  def __open__(mod, file, line, kind, name, props) do
    stack = Module.get_attribute(mod, :prism_stack)
    parent = List.first(stack)
    parent_kind = parent && parent.kind
    # A part inside a state only changes the part's look; it has no states of its own.
    # A part's state changes only that part.
    part_state? = match?([%{kind: :state}, %{kind: :part} | _], stack)

    allowed =
      if (parent_kind == :part and in_state?(stack)) or part_state?,
        do: [],
        else: @children[parent_kind]

    unless kind in allowed do
      where = if parent, do: "inside #{label(parent)}", else: "outside a component"

      why =
        if part_state?,
          do: ": a part's state changes only that part; a state of the component changes others",
          else: ""

      fail(file, line, "#{label(%{kind: kind, name: name})} can't be declared #{where}#{why}")
    end

    group = Module.get_attribute(mod, :prism_group)

    if kind == :component and group,
      do:
        fail(
          file,
          line,
          "component #{inspect(name)} inside group #{inspect(group)}: groups are for tokens"
        )

    path = Enum.reverse(Enum.map(stack, &{&1.kind, &1.name}))
    entry = %{kind: kind, name: name, parent: path, line: line, props: props}
    Module.put_attribute(mod, :prism_nodes, entry)
    Module.put_attribute(mod, :prism_stack, [entry | stack])
  end

  @doc false
  def __close__(mod) do
    [_ | stack] = Module.get_attribute(mod, :prism_stack)
    Module.put_attribute(mod, :prism_stack, stack)
  end

  @doc false
  # Fails when a token, group or web declaration is inside a component.
  def __top_level__!(mod, file, line, what) do
    case Module.get_attribute(mod, :prism_stack) do
      [] ->
        :ok

      stack ->
        fail(
          file,
          line,
          "#{what} inside #{label(List.last(stack))}: it goes at the top of the design"
        )
    end
  end

  defp in_state?(stack), do: Enum.any?(stack, &(&1.kind == :state))

  @doc false
  # The nodes in declaration order to the components' data, checked against the tokens.
  def validate!(nodes, tokens, file) do
    known = MapSet.new(tokens, &{&1.kind, &1.name})
    components = for %{kind: :component} = n <- nodes, do: n

    Enum.reduce(components, MapSet.new(), fn c, seen ->
      if c.name in seen, do: fail(file, c.line, "component #{inspect(c.name)} is defined twice")
      MapSet.put(seen, c.name)
    end)

    built = Enum.map(components, &component!(&1, nodes, known, file))
    names = MapSet.new(built, & &1.name)

    for c <- components, p <- children(nodes, c, :part), ref = p.props[:component] do
      unless ref in names and ref != c.name,
        do:
          fail(
            file,
            p.line,
            "#{path_label(p)}: component: #{inspect(ref)} is not another component"
          )

      # The web places a part that is another component by that component's look.
      component = Enum.find(built, &(&1.name == c.name))
      other = Enum.find(built, &(&1.name == ref))
      part = Enum.find(component.parts, &(&1.name == p.name))
      part_variants!(p, part.variants, other, file)

      with {:error, message} <-
             Prism.Generator.Web.Components.check_part(component, part, other),
           do: fail(file, p.line, "#{path_label(p)}: #{message}")

      # The part's own states, in or outside a variant.
      for %{kind: :state, parent: [{:component, name} | _] = parent} = s <- nodes,
          name == c.name and List.last(parent) == {:part, p.name} do
        with {:error, message} <-
               Prism.Generator.Web.Components.check_part_state(c.name, p.name, ref, s.name),
             do: fail(file, s.line, "#{path_label(s)}: #{message}")
      end

      # Outside a variant, the part's own look and states.
      part = Enum.find(component.parts, &(&1.name == p.name))

      case Prism.Generator.Web.Components.check_part_look(c.name, part, ref) do
        :ok ->
          :ok

        {:error, message, :part} ->
          fail(file, p.line, "#{path_label(p)}: #{message}")

        {:error, message, {:state, name}} ->
          s = Enum.find(children(nodes, p, :state), &(&1.name == name))
          fail(file, s.line, "#{path_label(s)}: #{message}")
      end
    end

    built
  end

  # The variants a part picks of the component it is: one per axis of that
  # component, each one of the axis's variants, by its name.
  defp part_variants!(p, picks, other, file) do
    fail = &fail(file, p.line, "#{path_label(p)}: variants: #{&1}")

    for {axis, name} <- picks do
      of_axis = for v <- other.variants, v.axis == axis, do: v

      cond do
        of_axis == [] ->
          fail.("#{inspect(other.name)} has no axis #{inspect(axis)}")

        Enum.any?(of_axis, &(&1.name == name)) ->
          :ok

        v = Enum.find(of_axis, &(name in &1.aliases)) ->
          fail.("#{inspect(name)} is an alias of #{inspect(v.name)}; name the variant")

        true ->
          fail.(
            "#{inspect(name)} is not a variant of #{inspect(other.name)}'s #{inspect(axis)}; it has #{Enum.map_join(of_axis, ", ", &inspect(&1.name))}"
          )
      end
    end
  end

  defp component!(c, nodes, known, file) do
    {opts, []} = split!(c, file)
    styles = children(nodes, c, :style)

    if length(styles) > 1,
      do: fail(file, Enum.at(styles, 1).line, "#{path_label(c)}: style is given twice")

    style =
      Enum.flat_map(styles, fn s ->
        {[], props} = split!(s, file)
        props!(s, props, known, file)
      end)

    axes = children(nodes, c, :variants)

    for a <- axes do
      if a.name == :variant,
        do:
          fail(
            file,
            a.line,
            "variants :variant: variants outside a variants block are the :variant axis"
          )

      if children(nodes, a, :variant) == [],
        do: fail(file, a.line, "#{path_label(a)} has no variants")
    end

    Enum.reduce(axes, MapSet.new(), fn a, seen ->
      if a.name in seen, do: fail(file, a.line, "#{path_label(a)} is given twice")
      MapSet.put(seen, a.name)
    end)

    axes =
      for a <- axes do
        {opts, []} = split!(a, file)
        Map.merge(%{name: a.name, default: opts[:default]}, bindings!(a, opts, known, file))
      end

    variants =
      for v <- variants_of(nodes, c) do
        axis =
          case List.last(v.parent) do
            {:variants, axis} -> axis
            {:component, _} -> :variant
          end

        {opts, props} = split!(v, file)
        aliases = Keyword.get(opts, :aliases, [])
        kind? = if number?(v.name), do: &number?/1, else: &snake_case?/1

        unless is_list(aliases) and Enum.all?(aliases, kind?),
          do:
            fail(
              file,
              v.line,
              "#{path_label(v)}: aliases: must be a list of #{if number?(v.name), do: "whole numbers above 0, as the variant's name is", else: "snake_case atoms"}"
            )

        Map.merge(
          %{
            name: v.name,
            axis: axis,
            aliases: aliases,
            style: props!(v, props, known, file),
            parts: overrides!(nodes, v, c, known, file),
            with_parts: with_parts!(nodes, v, c, known, file),
            values: value_changes!(nodes, v, c, known, file),
            states: states!(nodes, v, c, known, file),
            node: v
          },
          bindings!(v, opts, known, file)
        )
      end

    # An axis's variants are all names or all numbers.
    for {axis, [first | _] = of_axis} <- Enum.group_by(variants, & &1.axis),
        v <- of_axis,
        number?(v.name) != number?(first.name) do
      fail(
        file,
        v.node.line,
        "#{path_label(v.node)}: the #{inspect(axis)} axis's variants are all names or all numbers, and #{inspect(first.name)} is #{if number?(first.name), do: "a number", else: "a name"}"
      )
    end

    # A variant's looks with a variant of another axis, now that every variant is known.
    variants =
      for v <- variants do
        Map.put(
          v,
          :with_variants,
          with_variants!(nodes, v.node, v.axis, c, variants, known, file)
        )
      end

    flags =
      for f <- children(nodes, c, :flag) do
        {opts, props} = split!(f, file)
        default = Keyword.get(opts, :default, false)

        unless is_boolean(default),
          do: fail(file, f.line, "#{path_label(f)}: default: must be true or false")

        Map.merge(
          %{
            name: f.name,
            default: default,
            style: props!(f, props, known, file),
            with_variants: with_variants!(nodes, f, nil, c, variants, known, file),
            states: states!(nodes, f, c, known, file)
          },
          bindings!(f, opts, known, file)
        )
      end

    variants = Enum.map(variants, &Map.delete(&1, :node))

    parts =
      for p <- children(nodes, c, :part) do
        {opts, props} = split!(p, file)
        position = opts[:position]
        picks = Keyword.get(opts, :variants, [])

        cond do
          picks == [] ->
            :ok

          opts[:component] == nil ->
            fail(
              file,
              p.line,
              "#{path_label(p)}: variants: is for a part that is another component"
            )

          not Keyword.keyword?(picks) or Keyword.keys(picks) != Enum.uniq(Keyword.keys(picks)) ->
            fail(
              file,
              p.line,
              "#{path_label(p)}: variants: must be a keyword list of an axis and a variant, each axis once"
            )

          true ->
            :ok
        end

        cond do
          position == nil ->
            :ok

          opts[:component] != nil ->
            fail(
              file,
              p.line,
              "#{path_label(p)}: position: is for a part the app fills, not another component"
            )

          position not in @positions ->
            fail(
              file,
              p.line,
              "#{path_label(p)}: position: #{inspect(position)} is not :start or :end, the side the part has when the app picks none"
            )

          true ->
            :ok
        end

        Map.merge(
          %{
            name: p.name,
            component: opts[:component],
            position: position,
            variants: picks,
            style: props!(p, props, known, file),
            states: states!(nodes, p, c, known, file)
          },
          bindings!(p, opts, known, file)
        )
      end

    with_parts = with_parts!(nodes, c, c, known, file)
    states = states!(nodes, c, c, known, file)
    defaults = defaults!(c, opts[:default], nodes, variants, file)

    values =
      for v <- children(nodes, c, :value) do
        {opts, props} = split!(v, file)

        Map.merge(
          %{name: v.name, style: props!(v, props, known, file)},
          bindings!(v, opts, known, file)
        )
      end

    # Variants (with their aliases), states, flags and the looks with a part share
    # one set of names, as their modifier classes would; parts share another with
    # all of them but the variants, whose classes (`__icon`, `--icon`) can't be
    # confused.
    withs =
      Enum.uniq(for(w <- with_parts ++ Enum.flat_map(variants, & &1.with_parts), do: w.name))

    modifiers =
      Enum.map(states, &{&1.name, "state"}) ++
        Enum.map(values, &{&1.name, "value"}) ++
        Enum.map(flags, &{&1.name, "flag"}) ++
        Enum.map(withs, &{&1, "look with a part"}) ++ Enum.map(defaults, &{&1, "default"})

    unique!(
      Enum.map(variants, &{&1.name, "variant"}) ++
        for(v <- variants, a <- v.aliases, do: {a, "variant alias"}) ++ modifiers,
      c,
      file
    )

    unique!(Enum.map(parts, &{&1.name, "part"}) ++ modifiers, c, file)

    Map.merge(
      %{
        name: c.name,
        default: opts[:default],
        style: style,
        parts: parts,
        variants: variants,
        axes: axes,
        with_parts: with_parts,
        flags: flags,
        states: states,
        values: values
      },
      bindings!(c, opts, known, file)
    )
  end

  # A variant's or a flag's looks with another variant: each names a variant of the
  # component, of another axis than `axis` (the variant's own; `nil` for a flag),
  # once.
  defp with_variants!(nodes, node, axis, component, variants, known, file) do
    withs = children(nodes, node, :with_variant)
    unique!(Enum.map(withs, &{&1.name, "look with a variant"}), node, file)

    for w <- withs do
      fail = &fail(file, w.line, "#{path_label(w)}: #{&1}")

      case Enum.find(variants, &(&1.name == w.name)) do
        nil ->
          if v = Enum.find(variants, &(w.name in &1.aliases)),
            do: fail.("#{inspect(w.name)} is an alias of #{inspect(v.name)}; name the variant"),
            else: fail.("the component has no variant #{inspect(w.name)}")

        %{axis: ^axis} ->
          fail.(
            "#{inspect(w.name)} is a variant of the same axis, #{inspect(axis)}, which the app can't combine with it"
          )

        _ ->
          :ok
      end

      {opts, props} = split!(w, file)

      Map.merge(
        %{
          name: w.name,
          style: props!(w, props, known, file),
          states: states!(nodes, w, component, known, file)
        },
        bindings!(w, opts, known, file)
      )
    end
  end

  # The default of each axis: one of its variants, or a name without a look of its
  # own, which has no class. The names of the second kind are returned, as they
  # share the component's names.
  defp defaults!(c, default, nodes, variants, file) do
    axes =
      [{c, :variant, default}] ++
        for(a <- children(nodes, c, :variants), do: {a, a.name, a.props[:default]})

    for {node, axis, default} <- axes, default != nil, reduce: [] do
      acc ->
        fail = &fail(file, node.line, "#{path_label(node)}: default: #{inspect(default)} #{&1}")
        of_axis = for v <- variants, v.axis == axis, do: v
        if of_axis == [], do: fail.("is the default of the :variant axis, which has no variants")

        cond do
          number?(hd(of_axis).name) and not number?(default) ->
            fail.("must be a whole number above 0, as the axis's variants are")

          not number?(hd(of_axis).name) and not snake_case?(default) ->
            fail.("must be a snake_case atom")

          true ->
            :ok
        end

        cond do
          Enum.any?(of_axis, &(&1.name == default)) ->
            acc

          v = Enum.find(of_axis, &(default in &1.aliases)) ->
            fail.("is an alias of #{inspect(v.name)}; name the variant")

          true ->
            acc ++ [default]
        end
    end
  end

  # A variant's or a state's changes to parts the component declares.
  defp overrides!(nodes, node, component, known, file) do
    declared = for p <- children(nodes, component, :part), do: p.name
    parts = children(nodes, node, :part)
    states = children(nodes, node, :state)

    unique!(
      Enum.map(parts, &{&1.name, "part"}) ++ Enum.map(states, &{&1.name, "state"}),
      node,
      file
    )

    for p <- parts do
      unless p.name in declared,
        do:
          fail(
            file,
            p.line,
            "#{path_label(p)}: #{path_label(component)} has no part #{inspect(p.name)}"
          )

      {opts, props} = split!(p, file)

      Map.merge(
        %{
          name: p.name,
          style: props!(p, props, known, file),
          states: states!(nodes, p, component, known, file)
        },
        bindings!(p, opts, known, file)
      )
    end
  end

  # A variant's changes to values the component declares, each named once: the
  # value's look with that variant.
  defp value_changes!(nodes, node, component, known, file) do
    declared = for v <- children(nodes, component, :value), do: v.name
    changes = children(nodes, node, :value)
    unique!(Enum.map(changes, &{&1.name, "value"}), node, file)

    for v <- changes do
      unless v.name in declared,
        do:
          fail(
            file,
            v.line,
            "#{path_label(v)}: #{path_label(component)} has no value #{inspect(v.name)}"
          )

      {opts, props} = split!(v, file)

      Map.merge(
        %{name: v.name, style: props!(v, props, known, file)},
        bindings!(v, opts, known, file)
      )
    end
  end

  # A component's or a variant's looks while the component has a part: each names a
  # part the component declares, once. Its name is `with_<part>`.
  defp with_parts!(nodes, node, component, known, file) do
    declared = for p <- children(nodes, component, :part), do: p.name
    withs = children(nodes, node, :with_part)
    unique!(Enum.map(withs, &{&1.name, "look with a part"}), node, file)

    for w <- withs do
      unless w.name in declared,
        do:
          fail(
            file,
            w.line,
            "#{path_label(w)}: #{path_label(component)} has no part #{inspect(w.name)}"
          )

      {opts, props} = split!(w, file)

      Map.merge(
        %{
          name: :"with_#{w.name}",
          part: w.name,
          style: props!(w, props, known, file),
          states: states!(nodes, w, component, known, file)
        },
        bindings!(w, opts, known, file)
      )
    end
  end

  defp states!(nodes, node, component, known, file) do
    states = children(nodes, node, :state)
    unique!(Enum.map(states, &{&1.name, "state"}), node, file)

    for s <- states do
      unless Keyword.has_key?(@states, s.name),
        do:
          fail(
            file,
            s.line,
            "#{path_label(s)}: unknown state; the states are #{Enum.map_join(Keyword.keys(@states), ", ", &inspect/1)}"
          )

      {opts, props} = split!(s, file)

      Map.merge(
        %{
          name: s.name,
          style: props!(s, props, known, file),
          parts: overrides!(nodes, s, component, known, file)
        },
        bindings!(s, opts, known, file)
      )
    end
  end

  defp unique!(names, node, file) do
    Enum.reduce(names, %{}, fn {name, what}, seen ->
      if other = seen[name],
        do:
          fail(
            file,
            node.line,
            "#{path_label(node)}: #{inspect(name)} is both a #{other} and a #{what}"
          )

      Map.put(seen, name, what)
    end)
  end

  # A component's variants of every axis, in the design's order.
  defp variants_of(nodes, c) do
    path = [{:component, c.name}]

    for %{kind: :variant, parent: parent} = n <- nodes,
        parent == path or
          (match?([{:component, _}, {:variants, _}], parent) and hd(parent) == hd(path)),
        do: n
  end

  defp children(nodes, parent, kind) do
    path = parent.parent ++ [{parent.kind, parent.name}]
    for %{kind: ^kind, parent: ^path} = n <- nodes, do: n
  end

  # A node's keyword list split into its options and its properties. Only the
  # node's own options and the properties are known, so nothing in it can replace
  # the node's name, kind or place.
  defp split!(%{kind: kind, props: props} = node, file) do
    fail = &fail(file, node.line, "#{path_label(node)}: #{&1}")
    unless Keyword.keyword?(props), do: fail.("properties must be a keyword list")
    keys = Keyword.keys(props)

    case keys -- Enum.uniq(keys) do
      [] -> :ok
      [key | _] -> fail.("option #{inspect(key)} is given twice")
    end

    # Only a part the component declares can be another component.
    options = if kind == :part and length(node.parent) > 1, do: @targets, else: @options[kind]
    properties = if kind in [:component, :variants], do: [], else: Keyword.keys(@properties)

    case keys -- (options ++ properties) do
      [] -> :ok
      extra -> fail.("unknown option #{Enum.map_join(extra, ", ", &inspect/1)}")
    end

    Keyword.split(props, options)
  end

  # A node's per-target bindings, `%{web: [...], ios: [...], android: [...]}`. A key is
  # a property, whose value the target uses instead of the shared one, or a key the
  # target knows for this kind of node; anything else fails, so nothing is ignored.
  defp bindings!(node, opts, known, file) do
    Map.new(@targets, fn target ->
      binding = Keyword.get(opts, target, [])
      fail = &fail(file, node.line, "#{path_label(node)}: #{target}: #{&1}")
      unless Keyword.keyword?(binding), do: fail.("must be a keyword list")
      keys = Keyword.keys(binding)

      case keys -- Enum.uniq(keys) do
        [] -> :ok
        [key | _] -> fail.("#{inspect(key)} is given twice")
      end

      own = target_keys(target, node.kind)

      properties =
        if node.kind in [:component, :variants], do: [], else: Keyword.keys(@properties)

      # A component's own look is its style, so its binding may change those properties.
      properties = if node.kind == :component, do: Keyword.keys(@properties), else: properties

      for {key, value} <- binding do
        cond do
          key in own ->
            with {:error, message} <- target_check(target, key, value),
                 do: fail.("#{key}: #{message}")

          key in properties ->
            {type, _} = @properties[key]

            with {:error, message} <- check(type, value, known),
                 do: fail.("#{key}: #{message}")

            with {:error, message} <- target_value(target, node, key, value),
                 do: fail.("#{key}: #{message}")

          true ->
            known_keys = Enum.map_join(own, ", ", &inspect/1)

            fail.(
              "unknown key #{inspect(key)}; the #{target} target knows #{if own == [], do: "only the properties", else: known_keys <> " and the properties"} here"
            )
        end
      end

      {target, binding}
    end)
  end

  # The keys each target knows besides the properties. The native targets don't
  # exist yet, so they know only the properties.
  defp target_keys(:web, kind), do: Map.get(Prism.Generator.Web.Components.bindings(), kind, [])
  defp target_keys(_, _), do: []

  defp target_check(:web, key, value),
    do: Prism.Generator.Web.Components.check_binding(key, value)

  # The shared look: checked against its type, and against what the web target
  # can write for this node, since the web reads the shared value too.
  defp props!(node, props, known, file) do
    for {key, value} <- props do
      {type, _} = @properties[key]

      with :ok <- check(type, value, known),
           :ok <- target_value(:web, node, key, value) do
        {key, value}
      else
        {:error, message} -> fail(file, node.line, "#{path_label(node)}: #{key}: #{message}")
      end
    end
  end

  # A value a target writes in its own way, such as a color the web draws into an
  # image, may have limits there; the native targets have none yet.
  defp target_value(:web, node, key, value) do
    place = node.parent ++ [{node.kind, node.name}]
    Prism.Generator.Web.Components.check_value(place, key, value)
  end

  defp target_value(_, _, _, _), do: :ok

  # ------------------------------------------------------------ values

  defp check(:color, :transparent, _), do: :ok

  defp check(:color, "#" <> hex, _) do
    if Regex.match?(~r/\A[0-9A-F]{6}\z/, hex),
      do: :ok,
      else: {:error, "write colors as #RRGGBB (upper case)"}
  end

  defp check(:color, {ref, alpha}, known) when is_atom(ref) do
    if is_number(alpha) and alpha >= 0 and alpha <= 1,
      do: token(known, :color, ref),
      else: {:error, "the alpha of #{inspect({ref, alpha})} is not a number from 0 to 1"}
  end

  defp check(:color, ref, known) when is_atom(ref) and not is_boolean(ref) and ref != nil,
    do: token(known, :color, ref)

  defp check(:color, value, _),
    do:
      {:error,
       "#{inspect(value)} is not a color: a color's name, {color, alpha}, \"#RRGGBB\" or :transparent"}

  defp check(:length, value, _) do
    if length?(value),
      do: :ok,
      else:
        {:error,
         "#{inspect(value)} is not a length (a number >= 0 in px, {n, :rem} or {n, :percent})"}
  end

  defp check(:insets, value, _) do
    sides =
      if Keyword.keyword?(value), do: Enum.flat_map(Keyword.keys(value), &expand/1), else: nil

    cond do
      not Keyword.keyword?(value) or value == [] ->
        {:error,
         "#{inspect(value)} is not a keyword list of sides (top, right, bottom, left, x, y)"}

      (extra = Keyword.keys(value) -- @sides) != [] ->
        {:error, "unknown side #{Enum.map_join(extra, ", ", &inspect/1)}"}

      sides != Enum.uniq(sides) ->
        {:error,
         "a side is given twice in #{inspect(value)} (x is left and right, y is top and bottom)"}

      not Enum.all?(value, fn {_, v} -> length?(v) end) ->
        {:error, "every side is a length (a number >= 0 in px, {n, :rem} or {n, :percent})"}

      true ->
        :ok
    end
  end

  defp check(type, value, known) when type in [:border, :outline] do
    keys = if type == :border, do: [:width, :color], else: [:width, :color, :offset]

    cond do
      not Keyword.keyword?(value) or value == [] or Keyword.keys(value) -- keys != [] or
          length(Keyword.keys(value)) != length(Enum.uniq(Keyword.keys(value))) ->
        {:error,
         "#{inspect(value)} is not a keyword list of #{Enum.map_join(keys, ", ", &"#{&1}:")}"}

      not Enum.all?(Keyword.delete(value, :color), fn {_, v} -> length?(v) end) ->
        {:error, "#{Enum.map_join(keys -- [:color], " and ", &"#{&1}:")} must be lengths"}

      Keyword.has_key?(value, :color) ->
        check(:color, value[:color], known)

      true ->
        :ok
    end
  end

  defp check(type, ref, known)
       when type in [:radius, :max_height] and is_atom(ref) and ref != nil,
       do: token(known, type, ref)

  defp check(type, value, known) when type in [:radius, :max_height],
    do: check(:length, value, known)

  defp check(:shadow, ref, known) when is_atom(ref) and ref != nil, do: token(known, :shadow, ref)
  defp check(:shadow, value, _), do: {:error, "#{inspect(value)} is not the name of a shadow"}

  defp check(:typography, ref, known) when is_atom(ref) and ref != nil,
    do: token(known, :typography, ref)

  defp check(:typography, value, known) do
    if Keyword.keyword?(value) and Enum.sort(Keyword.keys(value)) == [:font, :text] do
      with :ok <- token(known, :font, value[:font]) do
        case value[:text] do
          {size, lh} when is_number(size) and size > 0 and is_number(lh) and lh > 0 ->
            :ok

          ref when is_atom(ref) ->
            token(known, :text, ref)

          other ->
            {:error, "text: #{inspect(other)} is not a text size or {size, line_height} in px"}
        end
      end
    else
      {:error, "#{inspect(value)} is not a typography token or [font: font, text: text]"}
    end
  end

  defp check(:weight, value, _) do
    if value in 100..1000//100,
      do: :ok,
      else: {:error, "#{inspect(value)} is not one of 100, 200, …, 1000"}
  end

  defp check(:decoration, value, _) do
    if value in [:underline, :none],
      do: :ok,
      else: {:error, "#{inspect(value)} is not :underline or :none"}
  end

  defp check(:opacity, value, _) do
    if is_number(value) and value >= 0 and value <= 1,
      do: :ok,
      else: {:error, "#{inspect(value)} is not a number from 0 to 1"}
  end

  defp check(:motion, value, _) do
    case value do
      {ms, easing} when is_number(ms) and ms >= 0 and easing in @easings ->
        :ok

      _ ->
        {:error,
         "#{inspect(value)} is not {milliseconds, easing}, easing one of #{Enum.map_join(@easings, ", ", &inspect/1)}"}
    end
  end

  defp token(known, kind, ref) do
    if {kind, ref} in known, do: :ok, else: {:error, "unknown #{kind} #{inspect(ref)}"}
  end

  defp length?(n) when is_number(n), do: n >= 0
  defp length?({n, unit}) when is_number(n) and unit in [:rem, :percent], do: n >= 0
  defp length?(_), do: false

  defp expand(:x), do: [:left, :right]
  defp expand(:y), do: [:top, :bottom]
  defp expand(side), do: [side]

  # ------------------------------------------------------------ messages

  defp snake_case?(name),
    do: is_atom(name) and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, Atom.to_string(name))

  defp number?(name), do: is_integer(name) and name > 0

  defp label(%{kind: :style}), do: "style"
  defp label(%{kind: kind, name: name}), do: "#{kind} #{inspect(name)}"

  # "component :button, variant :primary, state :pressed"
  defp path_label(node) do
    Enum.map_join(node.parent ++ [{node.kind, node.name}], ", ", fn {kind, name} ->
      label(%{kind: kind, name: name})
    end)
  end

  defp fail(file, line, description), do: Schema.__fail__(file, line, description)
end
