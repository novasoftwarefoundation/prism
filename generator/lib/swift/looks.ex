defmodule Prism.Generator.Swift.Looks do
  @moduledoc """
  A component's looks as layers, for the Swift target: each layer is the look
  of one node of the design (the component, a part, a variant, a flag, a look
  with a part or with a variant, a state) with the `ios:` binding's properties
  in place of the shared ones, the conditions under which it holds, and its
  rank.

  The Swift target lays the layers that hold over each other, so a component
  looks as its CSS makes it look on the web: a layer of a higher rank wins,
  and of two layers of the same rank, the later one in the design. The rank is
  what the web's selector for the node weighs (`Prism.Generator.Web.Classes`):

  - the component, a part, a variant, a flag and a look with a part are one
    class (`.acme-button`, `.acme-button--primary`, `.acme-button--with-icon`);
  - a variant's part, a variant's look with a part and a look with a variant
    are two (`.acme-button--primary.acme-button--with-icon`);
  - a state adds one, a pseudo-class or a modifier class; but a state the app
    sets on the component or on a part replaces that element's class
    (`.acme-text-field--invalid`), so it adds nothing there;
  - a state's change to a part adds one for the part;
  - a value the app gives is a modifier class, as a state the app sets
    (`.acme-spinner--progress`), and two with a variant
    (`.acme-spinner--inverse.acme-spinner--progress`).

  A state the app sets (`invalid`, `selected`, `loading`) outweighs `pressed`,
  `hovered` and `focused` for the properties both set (ADR 0008). The web
  writes that as one more selector on the app's state's rule, one class
  heavier than the pointer's or focus's (`.acme-text-field.acme-text-field--invalid:focus`);
  here it is one more layer, of those properties, that holds while both states
  do and weighs the same. So a focused invalid text field keeps its warning
  border, as on the web.

  The design's order, for two layers of one rank, is: the component, its
  parts and their states, its states and their changes to parts, its looks
  with a part, its values; then each variant (its look, its parts, its
  states, its looks with a part and with a variant, its changes to values);
  then each flag (its look, its states, its
  looks with a variant).
  """

  alias Prism.Generator.Web.Classes

  @states [:pressed, :hovered, :focused, :disabled, :checked, :selected, :loading, :invalid]

  @doc """
  The layers of component `c`, in the order they are laid over each other:
  `[%{part, conditions, style}]`. `part` is `nil` for the component itself or
  a part's name; `conditions` are `{:axis, axis, variant}`, `{:flag, name}`,
  `{:with, part}`, `{:value, name}`, `{:state, name}` (a state of the
  component) and `{:part_state, part, name}`; `style` is the node's look on iOS, a keyword
  list of properties. Layers without properties are left out.
  """
  def layers(c) do
    indexed = c |> nodes() |> Enum.with_index()

    (indexed ++ over(indexed, c))
    |> Enum.sort_by(fn {layer, index} -> {layer.rank, index} end)
    |> Enum.map(fn {layer, _} -> Map.delete(layer, :rank) end)
    |> Enum.reject(&(&1.style == []))
  end

  # ------------------------------------------------------------ the app's states

  # A state the app sets outweighs the pointer and the focus (ADR 0008): for each
  # layer of `invalid`, `selected` or `loading` and each `pressed`, `hovered` or
  # `focused` layer of the same element that holds with it, a layer of the
  # properties both set, which holds while both states do and weighs what the web's
  # added selector does: one more than the pointer's or focus's layer, and one more
  # for each condition of the app's state's own node, so a variant's own look for
  # the state stays above the component's. It goes right after the app's state's
  # layer, as the web's selector is on that layer's rule.
  @app [:invalid, :selected, :loading]
  @interaction [:pressed, :hovered, :focused]

  defp over(indexed, c) do
    states = for {layer, index} <- indexed, state = state(layer), do: {layer, index, state}

    for {a, index, {a_state, a_base}} <- states,
        state_name(a_state) in @app,
        {i, _, {i_state, i_base}} <- states,
        state_name(i_state) in @interaction,
        a.part == i.part,
        base = Enum.uniq(a_base ++ i_base),
        possible?(base),
        a_base -- i_base == [] or i_base -- a_base == [],
        keys = shared(a, i, a_state, a_base, i_base, states),
        keys != [] do
      layer = %{
        part: a.part,
        conditions: sort(base, c) ++ [i_state, a_state],
        style: Keyword.take(a.style, keys),
        rank: i.rank + 1 + length(a_base)
      }

      {layer, index + 0.5}
    end
    # The same state's look over two pointer or focus layers of different nodes is
    # one layer, of the higher rank.
    |> Enum.sort_by(fn {layer, _} -> -layer.rank end)
    |> Enum.uniq_by(fn {layer, _} -> {layer.part, layer.conditions, layer.style} end)
  end

  # The properties the app's state `a` and the pointer or focus `i` both set, less
  # those a node within `a`'s gives a look of its own for the same state, where that
  # node holds whenever `i` does: they are left to that look.
  defp shared(a, i, a_state, a_base, i_base, states) do
    own =
      for {other, _, {^a_state, base}} <- states,
          other.part == a.part,
          base != a_base,
          a_base -- base == [],
          base -- i_base == [],
          {key, _} <- other.style,
          do: key

    for {key, _} <- a.style, Keyword.has_key?(i.style, key), key not in own, do: key
  end

  # A layer's state, the last of its conditions, and the conditions before it.
  defp state(%{conditions: conditions}) do
    case List.last(conditions) do
      {:state, _} = state -> {state, Enum.drop(conditions, -1)}
      {:part_state, _, _} = state -> {state, Enum.drop(conditions, -1)}
      _ -> nil
    end
  end

  defp state_name({:state, name}), do: name
  defp state_name({:part_state, _, name}), do: name

  # Conditions that can hold together: no two variants of one axis.
  defp possible?(conditions) do
    axes = for {:axis, axis, _} <- conditions, do: axis
    axes == Enum.uniq(axes)
  end

  @doc """
  The states a component's layers depend on, in the format's order:
  `[{:state, name}]` and `[{:part_state, part, name}]`, the component's first.
  """
  def states(c) do
    conditions = c |> layers() |> Enum.flat_map(& &1.conditions) |> Enum.uniq()
    own = for s <- @states, {:state, s} in conditions, do: {:state, s}

    parts =
      for p <- c.parts,
          s <- @states,
          {:part_state, p.name, s} in conditions,
          do: {:part_state, p.name, s}

    own ++ parts
  end

  @doc "A node's look on iOS: its shared style, with its `ios:` binding's properties in place."
  def style(node) do
    overrides = node.ios

    Enum.map(node.style, fn {key, value} -> {key, Keyword.get(overrides, key, value)} end) ++
      Keyword.drop(overrides, Keyword.keys(node.style))
  end

  # ------------------------------------------------------------ the nodes

  defp nodes(c) do
    root = [layer(c, nil, [], 1, c)]

    parts =
      for p <- c.parts do
        [layer(c, p.name, [], 1, p) | states(c, p.name, [], 1, p, true)]
      end

    states = component_states(c, [], 1, c)

    withs =
      for w <- c.with_parts do
        conditions = [{:with, w.part}]
        [layer(c, nil, conditions, 1, w) | states(c, nil, conditions, 1, w, false)]
      end

    values = for v <- c.values, do: layer(c, nil, [{:value, v.name}], 1, v)
    variants = for v <- c.variants, do: variant(c, v)
    flags = for f <- c.flags, do: flag(c, f)

    List.flatten([root, parts, states, withs, values, variants, flags])
  end

  defp variant(c, v) do
    own = [{:axis, v.axis, v.name}]

    parts =
      for p <- v.parts do
        [layer(c, p.name, own, 2, p) | states(c, p.name, own, 2, p, true)]
      end

    withs =
      for w <- v.with_parts do
        conditions = own ++ [{:with, w.part}]
        [layer(c, nil, conditions, 2, w) | states(c, nil, conditions, 2, w, false)]
      end

    [
      layer(c, nil, own, 1, v),
      parts,
      component_states(c, own, 1, v),
      withs,
      with_variants(c, own, v),
      for(value <- v.values, do: layer(c, nil, own ++ [{:value, value.name}], 2, value))
    ]
  end

  defp flag(c, f) do
    own = [{:flag, f.name}]

    [
      layer(c, nil, own, 1, f),
      states(c, nil, own, 1, f, false),
      with_variants(c, own, f)
    ]
  end

  # A variant's or a flag's looks with a variant of another axis.
  defp with_variants(c, own, node) do
    for w <- node.with_variants do
      other = Enum.find(c.variants, &(&1.name == w.name))
      conditions = sort([{:axis, other.axis, other.name} | own], c)
      [layer(c, nil, conditions, 2, w) | states(c, nil, conditions, 2, w, false)]
    end
  end

  # The states of the component or of a variant, with their changes to parts. A state
  # the app sets replaces the component's class, so it weighs no more than it.
  defp component_states(c, conditions, rank, node) do
    for s <- node.states do
      own = conditions ++ [{:state, s.name}]
      rank = state_rank(c, nil, s.name, rank, conditions == [])

      [
        layer(c, nil, own, rank, s)
        | for(p <- s.parts, do: layer(c, p.name, own, rank + 1, p))
      ]
    end
  end

  # A part's states, or the states of a look with a part, a variant or a flag;
  # `element?` is whether the node is an element of its own (a part), whose class a
  # state the app sets replaces.
  defp states(c, part, conditions, rank, node, element?) do
    for s <- node.states do
      condition = if part, do: {:part_state, part, s.name}, else: {:state, s.name}
      layer(c, part, conditions ++ [condition], state_rank(c, part, s.name, rank, element?), s)
    end
  end

  defp state_rank(c, part, state, rank, element?) do
    pseudo? = Map.has_key?(Classes.pseudo_classes(c.name, part), state)
    if pseudo? or not element?, do: rank + 1, else: rank
  end

  defp layer(_c, part, conditions, rank, node),
    do: %{part: part, conditions: conditions, style: style(node), rank: rank}

  # Conditions in the order of the component's axes.
  defp sort(conditions, c) do
    axes = [:variant | Enum.map(c.axes, & &1.name)]

    Enum.sort_by(conditions, fn
      {:axis, axis, _} -> {0, Enum.find_index(axes, &(&1 == axis))}
      {:flag, _} -> {1, 0}
      {:with, _} -> {2, 0}
      {:value, _} -> {3, 0}
      _ -> {4, 0}
    end)
  end
end
