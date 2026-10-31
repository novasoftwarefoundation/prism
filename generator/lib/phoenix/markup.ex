if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Prism.Generator.Phoenix.Markup do
    @moduledoc false
    # Renders a component of `Prism.Generator.Phoenix` from its data and the app's
    # assigns: the element with its classes, then its children in the design's order.
    use Phoenix.Component

    def render(spec, assigns) do
      tag =
        case spec.element do
          {:as, _} -> as!(assigns.as)
          element -> element
        end

      assigns =
        assign(assigns,
          prism_tag: tag,
          prism_void: spec.void,
          prism_attrs: root_attrs(spec, assigns),
          prism_children: Enum.flat_map(spec.children, &child(&1, spec, assigns))
        )

      ~H"""
      <.dynamic_tag :if={@prism_void} tag_name={@prism_tag} {@prism_attrs} />
      <.dynamic_tag :if={!@prism_void} tag_name={@prism_tag} {@prism_attrs}><.child
          :for={child <- @prism_children}
          child={child}
        /></.dynamic_tag>
      """
    end

    defp as!(tag) do
      if tag in Prism.Generator.Web.Elements.as(),
        do: tag,
        else:
          raise(
            ArgumentError,
            "as: #{inspect(tag)} is not one of #{Enum.map_join(Prism.Generator.Web.Elements.as(), ", ", &inspect/1)}"
          )
    end

    # One child: an element with its attributes and the slot entries it renders, an
    # element without content, or text.
    defp child(assigns) do
      ~H"""
      <%= case @child do %>
        <% {:element, tag, attrs, entries} -> %><.dynamic_tag tag_name={tag} {attrs}>{render_slot(
            entries
          )}</.dynamic_tag>
        <% {:list, tag, attrs, items} -> %><.dynamic_tag tag_name={tag} {attrs}><.child
            :for={item <- items}
            child={item}
          /></.dynamic_tag>
        <% {:empty, tag, attrs} -> %><.dynamic_tag tag_name={tag} {attrs}>{""}</.dynamic_tag>
        <% {:void, tag, attrs} -> %><.dynamic_tag tag_name={tag} {attrs} />
        <% {:slot, entries} -> %>{render_slot(entries)}
        <% {:text, text} -> %>{text}
      <% end %>
      """
    end

    defp root_attrs(spec, assigns) do
      axes = for a <- spec.axes, do: a.classes[assigns[a.name]]
      states = for {:class, nil, class} <- effects(spec, assigns), do: class
      withs = for {part, class} <- spec.withs, present?(spec, part, assigns), do: class

      native =
        for {:native, nil, name} <- effects(spec, assigns), do: {name, true}

      rest = if spec.rest == :root, do: Map.to_list(assigns.rest), else: []

      spec.attrs ++
        native ++
        rest ++ [class: [spec.class | axes ++ states ++ withs] ++ List.wrap(assigns.class)]
    end

    # What the states the app has set do: `{:class | :native, part | nil, …}`.
    defp effects(spec, assigns),
      do: for(s <- spec.states, assigns[s.name], e <- s.effects, do: e)

    # The element's own attributes the states set on a part (`disabled: true`).
    defp natives(spec, part, assigns),
      do: for({:native, ^part, name} <- effects(spec, assigns), do: {name, true})

    defp part_classes(spec, part, assigns),
      do: for({:class, ^part, class} <- effects(spec, assigns), do: class)

    defp child(%{as: :inner_block}, _spec, assigns), do: [{:slot, assigns.inner_block}]

    defp child(%{as: :value}, _spec, assigns),
      do: [{:text, Phoenix.HTML.Form.normalize_value("textarea", assigns.value)}]

    defp child(%{as: :content} = p, spec, assigns) do
      case assigns.inner_block do
        [] ->
          []

        entries ->
          [
            {:element, p.element,
             p.attrs ++
               natives(spec, p.name, assigns) ++
               [class: [p.class | part_classes(spec, p.name, assigns)]], entries}
          ]
      end
    end

    # One element per slot entry, with the entry's attributes.
    defp child(%{as: :slot} = p, spec, assigns) do
      for entry <- Map.get(assigns, p.name, []) do
        {:element, p.element,
         p.attrs ++ entry_attrs(entry, [p.class | part_classes(spec, p.name, assigns)]), [entry]}
      end
    end

    defp child(%{as: :control} = p, spec, assigns) do
      native = natives(spec, p.name, assigns)
      rest = if spec.rest == :control, do: Map.to_list(assigns.rest), else: []
      class = [p.class | part_classes(spec, p.name, assigns)]
      [{:void, p.element, [type: p.type] ++ native ++ rest ++ [class: class]}]
    end

    defp child(%{as: :component} = p, _spec, assigns) do
      if p.while_loading and not assigns[:loading],
        do: [],
        else: [{:empty, p.element, [class: p.class]}]
    end

    defp child(%{as: :list} = p, _spec, assigns) do
      case Map.get(assigns, p.item, []) do
        [] ->
          []

        entries ->
          items =
            for entry <- entries do
              selected = for s <- p.item_states, entry[s.name], do: s.class

              aria =
                if Map.has_key?(entry, :selected),
                  do: [{"aria-selected", to_string(!!entry.selected)}],
                  else: []

              {:element, p.item_element,
               [role: "option"] ++
                 aria ++
                 entry_attrs(Map.drop(entry, Enum.map(p.item_states, & &1.name)), [
                   p.item_class | selected
                 ]), [entry]}
            end

          [{:list, p.element, [role: "listbox", class: [p.class]], items}]
      end
    end

    # A slot entry's attributes on its part's element, its class after the part's.
    defp entry_attrs(entry, classes) do
      attrs = Map.drop(entry, [:__slot__, :inner_block, :class])
      Map.to_list(attrs) ++ [class: classes ++ List.wrap(entry[:class])]
    end

    defp present?(spec, part, assigns) do
      case Enum.find(spec.children, &(&1[:name] == part)) do
        %{as: :content} -> assigns.inner_block != []
        %{as: :slot} -> Map.get(assigns, part, []) != []
        %{as: :list, item: item} -> Map.get(assigns, item, []) != []
        %{as: :component} = p -> not p.while_loading or assigns[:loading] == true
        _ -> false
      end
    end
  end
end
