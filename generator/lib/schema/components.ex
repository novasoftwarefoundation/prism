defmodule Prism.Generator.Schema.Components do
  @moduledoc """
  The component part of the schema: `component`, `style`, `variant`,
  `variants`, `part` and `state`. A design that uses `Prism.Generator.Schema`
  imports these macros.

      component :button, web: "btn" do
        style typography: :button, radius: :default, transition: {150, :ease_in_out}
        part :label
        part :spinner, component: :spinner

        variant :primary, background: :accent, foreground: :white, padding: [y: 15, x: 16] do
          state :pressed, padding: [top: 16, bottom: 14], shadow: :pressed
          state :disabled, opacity: 0.5
        end

        state :loading do
          part :label, opacity: 0
        end

        variants :color do
          variant :danger, background: :error, aliases: [:delete]
        end
      end

  A component is one concept, such as a button or a checkbox: how it looks and
  how its look changes in a state. What it does is never part of a design.

  - `style` is the component's own look, once per component.
  - A `variant` is a look to choose. Variants outside a `variants` block form
    the `:variant` axis; `variants :color do … end` adds a second axis, whose
    variants combine with one of the first. `aliases:` gives a variant more
    names.
  - A `part` is a named piece of the component (a label, an icon), in the
    order the design gives them. `component:` makes the part another component.
    A variant or a state may change a part's look by naming it again.
  - A `state` changes the look while it holds. States have a fixed meaning that
    every target knows; see `states/0`.

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
    error: "while its value is invalid; the app sets it"
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
    rotation: {:motion, "one full turn: {milliseconds, easing}"}
  ]

  @easings [:linear, :ease, :ease_in, :ease_out, :ease_in_out]
  @sides [:top, :right, :bottom, :left, :x, :y]

  # The options each kind of node takes besides its properties.
  @targets [:web, :ios, :android]

  @options %{
    component: @targets,
    variants: @targets,
    style: [],
    variant: [:aliases | @targets],
    part: [:component | @targets],
    state: @targets
  }

  # What may be declared directly inside what; `nil` is the top of the design.
  @children %{
    nil => [:component],
    component: [:style, :variants, :variant, :part, :state],
    variants: [:variant],
    variant: [:part, :state],
    part: [:state],
    state: [:part]
  }

  @doc "The states, with what each means: `[{name, meaning}]`."
  def states, do: @states

  @doc "The properties, with their type and meaning: `[{name, {type, meaning}}]`."
  def properties, do: @properties

  @doc """
  A component: `component :name, web: "class" do … end`. `web:` is its CSS
  class name after the prefix (default: the name with `-` for `_`).
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

  @doc "An axis of variants other than `:variant`: `variants :color do … end`."
  defmacro variants(axis, opts \\ [], block \\ []),
    do: node(:variants, axis, opts, block, __CALLER__)

  @doc "A variant: its look, and a block of the parts and states it changes."
  defmacro variant(name, props \\ [], block \\ []),
    do: node(:variant, name, props, block, __CALLER__)

  @doc "A part: its look, and a block of its states."
  defmacro part(name, props \\ [], block \\ []),
    do: node(:part, name, props, block, __CALLER__)

  @doc "A state: the look while it holds, and a block of the parts it changes."
  defmacro state(name, props \\ [], block \\ []),
    do: node(:state, name, props, block, __CALLER__)

  # `variant :dark do … end` passes the block as the second argument.
  defp node(kind, name, [do: block], [], caller), do: node(kind, name, [], [do: block], caller)

  defp node(kind, name, props, block, caller) do
    unless snake_case?(name),
      do:
        fail(
          caller.file,
          caller.line,
          "#{kind} #{Macro.to_string(name)}: name must be a snake_case atom"
        )

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
    allowed = if parent_kind == :part and in_state?(stack), do: [], else: @children[parent_kind]

    unless kind in allowed do
      where = if parent, do: "inside #{label(parent)}", else: "outside a component"
      fail(file, line, "#{label(%{kind: kind, name: name})} can't be declared #{where}")
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
    end

    built
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
        Map.merge(%{name: a.name}, bindings!(a, opts, known, file))
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

        unless is_list(aliases) and Enum.all?(aliases, &snake_case?/1),
          do: fail(file, v.line, "#{path_label(v)}: aliases: must be a list of snake_case atoms")

        Map.merge(
          %{
            name: v.name,
            axis: axis,
            aliases: aliases,
            style: props!(v, props, known, file),
            parts: overrides!(nodes, v, c, known, file),
            states: states!(nodes, v, c, known, file)
          },
          bindings!(v, opts, known, file)
        )
      end

    parts =
      for p <- children(nodes, c, :part) do
        {opts, props} = split!(p, file)

        Map.merge(
          %{
            name: p.name,
            component: opts[:component],
            style: props!(p, props, known, file),
            states: states!(nodes, p, c, known, file)
          },
          bindings!(p, opts, known, file)
        )
      end

    states = states!(nodes, c, c, known, file)

    # Variants (with their aliases), parts and states share one set of names, as
    # their CSS classes would.
    names =
      Enum.map(variants, &{&1.name, "variant"}) ++
        for(v <- variants, a <- v.aliases, do: {a, "variant alias"}) ++
        Enum.map(parts, &{&1.name, "part"}) ++ Enum.map(states, &{&1.name, "state"})

    unique!(names, c, file)

    Map.merge(
      %{
        name: c.name,
        style: style,
        parts: parts,
        variants: variants,
        axes: axes,
        states: states
      },
      bindings!(c, opts, known, file)
    )
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

  defp props!(node, props, known, file) do
    for {key, value} <- props do
      {type, _} = @properties[key]

      case check(type, value, known) do
        :ok -> {key, value}
        {:error, message} -> fail(file, node.line, "#{path_label(node)}: #{key}: #{message}")
      end
    end
  end

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
