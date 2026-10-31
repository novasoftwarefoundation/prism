defmodule Prism.Generator.Web.Elements do
  @moduledoc """
  The markup of a design's components on the web: per component, its element,
  its parts in the design's order and what each one is, and the classes and
  attributes each axis value and state adds. The Phoenix components
  (`Prism.Generator.Phoenix`) and the React components
  (`Prism.Generator.React`) both render from it, and it names every class
  with `Prism.Generator.Web.Classes`, as the CSS does. So the two kinds of
  components render the same markup, with the classes the CSS styles.

  Like the web target's CSS, it knows the components by name and picks each
  one's element from what the CSS expects:

  | Component | Element | Content |
  |---|---|---|
  | `button` | the app's choice: `button` (the default), `a`, `span` or `div` | `label` holds the content; `icon`; the spinner while loading |
  | `text_field` | `<input>` | none |
  | `text_area` | `<textarea>` | its value |
  | `field` | `<div>` | `label` (a `<label>`), the content (the control), `error_message` (a `<p>`) |
  | `radio_group` | `<div role="radiogroup">` | the content (the radios) |
  | `radio` | `<label>` | its `control` (an `<input type="radio">`, which gets the app's attributes), `label` holds the content |
  | `select` | `<div>` | `field` (a `<button>`) holds the content; `icon`; `listbox` (a `<ul>`) holds the options |
  | `spinner` | `<span>` | none |
  | `checkbox` | `<input type="checkbox">` | none |
  | `tag` | `<span>` | `label` holds the content |
  | `message_bar` | `<div>` | the content |
  | `step_indicator` | `<span>` | the content |

  ## The data

  `components/2` returns one map per design component, in the design's order:

  - `name`; `element`: a tag, or `{:as, default}` when the app picks it from
    `as/0`; `void`: whether the element has no content; `class`: the
    component's class; `attrs`: the element's fixed attributes
    (`[role: "radiogroup"]`).
  - `axes`: `[%{name, values, default, classes}]`, the `:variant` axis first,
    then the `variants` blocks. `values` are the axis's variants and aliases,
    with its default first when that is a name without a look of its own;
    `classes` maps each variant and alias to its class (a default without a
    look has none).
  - `states`: `[%{name, effects}]`, the states the app sets, in the order of
    `Prism.Generator.Schema.Components.states/0`. An effect is
    `{:class, part, class}`, a class on the element (`part` `nil`) or on a
    part, or `{:native, part, state}`, the element's own attribute
    (`disabled`, `checked`) on the element or on a part that is a form
    control. A disabled component disables the form controls among its parts.
  - `children`: the element's content in the design's order, each one of
    - `%{as: :content, name, element, attrs, class}`: the part that holds the
      app's content;
    - `%{as: :slot, name, element, attrs, class}`: a part the app fills, such
      as an icon. A part whose side the app picks (`positions`) is there
      twice, just before and just after the content, each with `side`
      (`:start`, `:end`) and `position`, its setting's name: it renders only
      on the side the setting has;
    - `%{as: :control, name, element, type, class}`: a form control, which
      gets the app's attributes (`rest` is `:control`);
    - `%{as: :component, name, element, class, while_loading}`: a part that
      is another component, with that component's class and the classes of
      its defaults that are variants; while `while_loading`, it is there only
      while the component is loading;
    - `%{as: :list, name, element, class, item, item_element, item_class,
      item_states}`: a list of items the app gives, such as a select's
      options; `item_states` are `[%{name, class}]`;
    - `%{as: :inner_block}`: the app's content where no part holds it;
    - `%{as: :value}`: a text area's value.
  - `withs`: `%{part => class}`, the class of the look with each part, added
    while that part is there.
  - `flags`: `[%{name, default, class, only}]`, the looks the app turns on
    or off: `class` is added while the flag is on, and `default` is whether
    it is when the app sets nothing. A flag whose only looks are with
    variants has `only`, `[{axis, values}]`: its class is added only while
    one of those axes has one of those values (a variant or an alias), so a
    variant it has no look on gets no class. `only` is `nil` otherwise.
  - `positions`: `[%{name, part, default}]`, the parts whose side of the
    content the app picks: `name` is the setting (`icon_position`), and
    `default` the side without one, `:start` or `:end`.
  - `rest`: where the app's other attributes go, `:root` or `:control`.

  A design component or part this module doesn't know raises an
  `ArgumentError` that names the target asking.
  """

  alias Prism.Generator.Web.Classes

  # Per component: its element, its parts (what each one is, and its element), and
  # where the content goes when no part holds it (`:end`, `{:after, part}`,
  # `:value` for a text area, `nil` for none).
  @kinds %{
    button: %{
      element: {:as, "button"},
      parts: [label: {:content, "span"}, icon: {:slot, "span"}],
      content: :end
    },
    text_field: %{element: "input", parts: [], content: nil},
    text_area: %{element: "textarea", parts: [], content: :value},
    field: %{
      element: "div",
      parts: [label: {:slot, "label"}, error_message: {:slot, "p"}],
      content: {:after, :label}
    },
    radio_group: %{element: "div", attrs: [role: "radiogroup"], parts: [], content: :end},
    radio: %{
      element: "label",
      parts: [control: {:control, "input", "radio"}, label: {:content, "span"}],
      content: :end
    },
    select: %{
      element: "div",
      parts: [
        field: {:content, "button", type: "button"},
        icon: {:slot, "span"},
        listbox: {:list, "ul", :option},
        option: {:item, "li"}
      ],
      content: nil
    },
    spinner: %{element: "span", parts: [], content: nil},
    checkbox: %{element: "input", attrs: [type: "checkbox"], parts: [], content: nil},
    tag: %{element: "span", parts: [label: {:content, "span"}], content: :end},
    message_bar: %{element: "div", parts: [], content: :end},
    step_indicator: %{element: "span", parts: [], content: :end}
  }

  @void ["input"]

  # The elements a component whose element is the app's choice (`as`) may be: what
  # holds a look inside the app's own action, or is that action.
  @as ~w(button a span div)

  # The states, in the schema's order, for the order of the attributes.
  @states [:pressed, :hovered, :focused, :disabled, :checked, :selected, :loading, :invalid]

  # States a form control has as an attribute of its own.
  @native [:disabled, :checked]

  @doc "The elements a component whose element is the app's choice may be."
  def as, do: @as

  @doc """
  The components of a design's `__schema__/0`, each as the data its markup is
  rendered from. `target` names the target in errors (`"the Phoenix target"`).
  """
  def components(%{components: components, web: web}, target) do
    unless web,
      do: raise(ArgumentError, "the design has no `web` declaration, which names its classes")

    for c <- components do
      kind =
        Map.get(@kinds, c.name) ||
          raise(
            ArgumentError,
            "#{target} has no component #{inspect(c.name)}; it knows #{@kinds |> Map.keys() |> Enum.sort() |> Enum.map_join(", ", &inspect/1)}"
          )

      component(c, kind, web.prefix, components, target)
    end
  end

  defp component(c, kind, prefix, components, target) do
    known = Keyword.keys(kind.parts)

    for %{component: nil, name: name} <- c.parts, name not in known do
      raise ArgumentError,
            "#{target} has no part #{inspect(name)} of #{inspect(c.name)}; " <>
              if(known == [],
                do: "it renders only parts that are other components there",
                else: "it knows #{Enum.map_join(known, ", ", &inspect/1)}"
              )
    end

    parts = Enum.map(c.parts, &part(c, kind, &1, prefix, components))

    %{
      name: c.name,
      element: kind.element,
      void: kind.element in @void,
      class: Classes.component(prefix, c.name),
      attrs: Map.get(kind, :attrs, []),
      axes: axes(c, prefix),
      states: states(c, parts, prefix),
      children: children(parts, kind, c),
      withs: withs(c, prefix),
      flags: flags(c, prefix),
      positions:
        for(
          %{position: side} = p <- c.parts,
          side != nil,
          do: %{name: position_name(p.name), part: p.name, default: side}
        ),
      rest: if(Enum.any?(parts, &(&1.as == :control)), do: :control, else: :root)
    }
  end

  defp position_name(part), do: :"#{part}_position"

  # A flag's class, and the variants it is added with when its only looks are with
  # variants.
  defp flags(c, prefix) do
    for f <- c.flags do
      # A web binding's doc is no look.
      web = Keyword.drop(f.web, Prism.Generator.Web.Components.bindings().flag)
      own? = f.style != [] or f.states != [] or web != []

      only =
        if own? or f.with_variants == [] do
          nil
        else
          f.with_variants
          |> Enum.map(fn w -> Enum.find(c.variants, &(&1.name == w.name)) end)
          |> Enum.group_by(& &1.axis, &[&1.name | &1.aliases])
          |> Enum.map(fn {axis, names} -> {axis, List.flatten(names)} end)
          |> Enum.sort_by(fn {axis, _} -> axis_index(c, axis) end)
        end

      %{
        name: f.name,
        default: f.default,
        class: Classes.modifier(prefix, c.name, f.name),
        only: only
      }
    end
  end

  defp axis_index(_c, :variant), do: -1
  defp axis_index(c, axis), do: Enum.find_index(c.axes, &(&1.name == axis))

  # A design part as what the markup renders: the part's class and element, and
  # what it is.
  # A part that is another component has that component's element and class, with
  # the classes of its axes' defaults that are variants.
  defp part(c, _kind, %{component: ref} = p, prefix, components) when ref != nil do
    element =
      case @kinds[ref] do
        %{element: {:as, default}} -> default
        %{element: element} -> element
        nil -> "span"
      end

    other = Enum.find(components, &(&1.name == ref))

    defaults =
      for %{default: default, classes: classes} <- axes(other, prefix),
          class = classes[default],
          do: class

    %{
      name: p.name,
      as: :component,
      element: element,
      class: [Classes.part(prefix, c, p.name) | defaults]
    }
  end

  defp part(c, kind, p, prefix, _components) do
    class = Classes.part(prefix, c, p.name)

    case kind.parts[p.name] do
      {:list, element, item} ->
        unless Enum.any?(c.parts, &(&1.name == item)),
          do:
            raise(
              ArgumentError,
              "#{inspect(c.name)}: its #{inspect(p.name)} has no #{inspect(item)}"
            )

        item_states =
          for name <- part_states(c, item),
              pseudo(c.name, item, name) == nil,
              do: %{name: name, class: Classes.part_modifier(prefix, c, item, name)}

        %{
          name: p.name,
          as: :list,
          element: element,
          class: class,
          item: item,
          item_element: elem(kind.parts[item], 1),
          item_class: Classes.part(prefix, c, item),
          item_states: item_states
        }

      # An item is rendered inside its list, which the design must declare too.
      {:item, _} ->
        lists = for {name, {:list, _, item}} <- kind.parts, item == p.name, do: name

        unless Enum.any?(c.parts, &(&1.name in lists)),
          do:
            raise(
              ArgumentError,
              "#{inspect(c.name)}: its #{inspect(p.name)} goes in its #{Enum.map_join(lists, " or ", &inspect/1)}, which the design doesn't declare"
            )

        %{name: p.name, as: :item}

      {:control, element, type} ->
        %{name: p.name, as: :control, element: element, type: type, class: class}

      {as, element} ->
        %{name: p.name, as: as, element: element, attrs: [], class: class}

      {as, element, attrs} ->
        %{name: p.name, as: as, element: element, attrs: attrs, class: class}
    end
  end

  # The children of the component's element, in the design's order, with the
  # content where the component puts it.
  defp children(parts, kind, c) do
    loading? = loading?(c)

    rendered =
      for p <- parts, p.as != :item do
        if p.as == :component, do: Map.put(p, :while_loading, loading?), else: p
      end

    positioned = for p <- c.parts, p.position != nil, do: p.name
    {moved, rendered} = Enum.split_with(rendered, &(&1[:name] in positioned))

    rendered
    |> with_content(kind)
    |> around_content(moved, c)
  end

  # A part whose side the app picks, just before and just after the content.
  defp around_content(children, [], _c), do: children

  defp around_content(children, moved, c) do
    for p <- moved, p.as != :slot do
      raise ArgumentError,
            "#{inspect(c.name)}: its #{inspect(p.name)} can't have position:, which is for a part the app fills"
    end

    i =
      Enum.find_index(children, &(&1.as in [:content, :inner_block])) ||
        raise(
          ArgumentError,
          "#{inspect(c.name)}: its #{Enum.map_join(moved, ", ", &inspect(&1.name))} goes beside its content, and it has none"
        )

    side = fn side ->
      for p <- moved, do: Map.merge(p, %{side: side, position: position_name(p.name)})
    end

    {before, [content | rest]} = Enum.split(children, i)
    before ++ side.(:start) ++ [content | side.(:end)] ++ rest
  end

  # The content where the component puts it, when no part holds it.
  defp with_content(rendered, kind) do
    cond do
      Enum.any?(rendered, &(&1.as == :content)) or kind.content == nil ->
        rendered

      kind.content == :value ->
        rendered ++ [%{as: :value}]

      match?({:after, _}, kind.content) ->
        {:after, name} = kind.content

        case Enum.find_index(rendered, &(&1.name == name)) do
          nil -> [%{as: :inner_block} | rendered]
          i -> List.insert_at(rendered, i + 1, %{as: :inner_block})
        end

      true ->
        rendered ++ [%{as: :inner_block}]
    end
  end

  # The axes: `:variant` first, then the `variants` blocks in the design's order.
  defp axes(c, prefix) do
    own =
      if Enum.any?(c.variants, &(&1.axis == :variant)), do: [{:variant, c.default}], else: []

    for {axis, default} <- own ++ Enum.map(c.axes, &{&1.name, &1.default}) do
      variants = for v <- c.variants, v.axis == axis, name <- [v.name | v.aliases], do: name
      classes = Map.new(variants, &{&1, Classes.modifier(prefix, c.name, &1)})

      values =
        if default == nil or default in variants, do: variants, else: [default | variants]

      %{name: axis, values: values, default: default, classes: classes}
    end
  end

  # The states the app sets, each with what it does where it is declared: a class
  # on the element or a part, or the element's own attribute.
  defp states(c, parts, prefix) do
    withs = &Enum.flat_map(&1, fn w -> w.states end)

    own =
      c.states ++
        withs.(c.with_parts) ++
        Enum.flat_map(c.variants, &(&1.states ++ withs.(&1.with_parts ++ &1.with_variants))) ++
        Enum.flat_map(c.flags, &(&1.states ++ withs.(&1.with_variants)))

    # The form controls among the parts: a radio's control, a select's field.
    controls =
      for p <- parts,
          p.as == :control or (p.as == :content and Classes.control?(c.name, p.name)),
          do: p.name

    single = for p <- parts, p.as in [:content, :control, :slot], do: p.name

    places =
      Enum.map(own, &{nil, &1.name}) ++
        for part <- single, name <- part_states(c, part), do: {part, name}

    places
    |> Enum.uniq()
    |> Enum.flat_map(fn {part, name} ->
      effects =
        case {pseudo(c.name, part, name), part} do
          {nil, nil} ->
            [{:class, nil, Classes.modifier(prefix, c.name, name)}]

          {nil, part} ->
            [{:class, part, Classes.part_modifier(prefix, c, part, name)}]

          {_, part} ->
            if name in @native and Classes.control?(c.name, part),
              do: [{:native, part, name}],
              else: []
        end

      # A disabled component disables its form controls too.
      effects =
        if name == :disabled and part == nil,
          do: effects ++ for(cp <- controls, do: {:native, cp, :disabled}),
          else: effects

      for e <- effects, do: {name, e}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort_by(fn {name, _} -> Enum.find_index(@states, &(&1 == name)) end)
    |> Enum.map(fn {name, effects} -> %{name: name, effects: Enum.uniq(effects)} end)
  end

  # A part's states, in its own declaration and in each variant's change to it.
  defp part_states(c, part) do
    changes = for v <- c.variants, p <- v.parts, p.name == part, do: p

    for p <- Enum.filter(c.parts, &(&1.name == part)) ++ changes,
        s <- p.states,
        uniq: true,
        do: s.name
  end

  defp withs(c, prefix) do
    for w <- c.with_parts ++ Enum.flat_map(c.variants, & &1.with_parts),
        uniq: true,
        into: %{},
        do: {w.part, Classes.modifier(prefix, c.name, w.name)}
  end

  defp loading?(c) do
    Enum.any?(c.states ++ Enum.flat_map(c.variants, & &1.states), &(&1.name == :loading))
  end

  defp pseudo(component, part, state), do: Classes.pseudo_classes(component, part)[state]
end
