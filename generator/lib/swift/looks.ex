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

  So a focused text field shows its focused border over its invalid one, as
  on the web, where `:focus` outweighs the `--invalid` class.

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
    c
    |> nodes()
    |> Enum.with_index()
    |> Enum.sort_by(fn {layer, index} -> {layer.rank, index} end)
    |> Enum.map(fn {layer, _} -> Map.delete(layer, :rank) end)
    |> Enum.reject(&(&1.style == []))
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
    end)
  end
end
