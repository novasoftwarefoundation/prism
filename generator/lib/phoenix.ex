if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Prism.Generator.Phoenix do
    @moduledoc """
    Function components for a Phoenix app, built from a design while the app
    compiles. There are no generated files: the app's module reads the design's
    `__schema__/0` and gets one function component per design component.

        defmodule MyAppWeb.Design do
          use Prism.Generator.Phoenix, design: MyApp.Design
        end

        <MyAppWeb.Design.button variant={:primary} tone={:danger} loading={@saving}>
          Save
          <:icon><.icon name="check" /></:icon>
        </MyAppWeb.Design.button>

    This module exists only when the app has Phoenix LiveView: Phoenix is an
    optional dependency of the generator, and the design needs none.

    A component renders its look: its element, classes and parts. What it does
    is the app's: a button goes inside the app's own link or form, or gets its
    `phx-click` through `rest`.

    ## Attributes and slots

    - **Each axis** (`variant`, and each `variants` block such as `tone` or
      `size`) is an atom attribute with `values:` from the design: its variants
      and their aliases, and its default when that is a name without a look
      of its own. Phoenix warns at compile time about any other value. Its
      default is the axis's `default:` in the design; a default that is one of
      the variants adds that variant's class, one without a look adds none. An
      axis without a default adds no class until the app picks a variant.
    - **Each state the app sets** is a boolean attribute: a state the CSS writes
      as a modifier class adds that class (`loading`, `invalid`, a radio's
      `disabled`); `disabled` and `checked` on a form control set the element's
      own attribute, which the CSS's pseudo-class reads. A disabled component
      also disables the form controls among its parts. States the browser sets
      (`pressed`, `hovered`, `focused` on a form control) need no attribute.
    - **Parts**, in the design's order: the part that holds the content is the
      inner block (a button's or a tag's `label`), a part such as an icon is a
      slot of its own name (`<:icon>`), and a part that is another component (a
      button's spinner) is rendered while the component is `loading`, when it
      has a loading state, and always otherwise, with the classes of its own
      defaults that are variants. A part's state is an attribute of the
      component, like the component's own (a field label's `invalid`). A part's slot takes `class`
      and any other attributes for the part's element. While a part is there,
      its look with a part (`with_part :icon`) adds `--with-icon`.
    - `class` appends the app's classes to the component's own; `rest` takes
      global attributes (`id`, `phx-*`, `aria-*`, `data-*`) and the element's
      own (`type`, `name`, `value`, …).

    Class names come from `Prism.Generator.Web.Classes`, the same functions
    that name the classes of the web target's CSS.

    ## Elements

    Like the web target, this target knows the components by name and picks
    each one's element from what the CSS expects:

    | Component | Element | Content |
    |---|---|---|
    | `button` | `as`: `"button"` (the default), `"a"`, `"span"` or `"div"` | `label` holds the inner block; `<:icon>`; the spinner while loading |
    | `text_field` | `<input>` | none |
    | `text_area` | `<textarea>` | the `value` attribute |
    | `field` | `<div>` | `<:label>` (a `<label>`), the inner block (the control), `<:error_message>` (a `<p>`) |
    | `radio_group` | `<div role="radiogroup">` | the inner block (the radios) |
    | `radio` | `<label>` | its `control` (an `<input type="radio">`, which gets `rest`), `label` holds the inner block |
    | `select` | `<div>` | `field` (a `<button>`) holds the inner block; `<:icon>`; `listbox` (a `<ul>`) holds the `<:option>` entries |
    | `spinner` | `<span>` | none |
    | `checkbox` | `<input type="checkbox">` | none |
    | `tag` | `<span>` | `label` holds the inner block |
    | `message_bar` | `<div>` | the inner block |
    | `step_indicator` | `<span>` | the inner block |

    A select's `<:option>` takes `selected` (adds the option's selected class
    and `aria-selected`); its other attributes go on the option. The listbox is
    there while the app gives options. A design component or part this target
    doesn't know fails the app's compilation, at the `use` line.

    ## Recompiling

    This module is compiled only when Phoenix LiveView is there, so an app
    that adds LiveView after its first compile rebuilds the generator once:
    `mix deps.compile prism_generator --force`.

    The module requires the design, a compile-time dependency, so it recompiles
    when the design changes: a new variant is there at once, and Phoenix warns
    where the app still passes a removed one.
    """

    alias Prism.Generator.Web.Classes

    # Per component: its element, its parts (what each one is, and its element), and
    # where the inner block goes when no part holds it (`:end`, `{:after, part}`,
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

    @doc false
    def as, do: @as

    # The element's own attributes `rest` takes, besides the globals.
    @own %{
      "button" =>
        ~w(type form formaction formenctype formmethod formnovalidate formtarget name value autofocus href target rel download disabled),
      "input" =>
        ~w(accept autocomplete autofocus form list max maxlength min minlength multiple name pattern placeholder readonly required size step type value disabled checked),
      "textarea" =>
        ~w(autocomplete autofocus cols form maxlength minlength name placeholder readonly required rows wrap disabled)
    }

    # The states, in the schema's order, for the order of the attributes.
    @states [:pressed, :hovered, :focused, :disabled, :checked, :selected, :loading, :invalid]

    # States a form control has as an attribute of its own.
    @native [:disabled, :checked]

    # Names the components' own attributes and slots take.
    @reserved [:class, :rest, :as, :value, :inner_block]

    @doc false
    defmacro __using__(opts) do
      env = __CALLER__

      design =
        case Keyword.fetch(opts, :design) do
          {:ok, design} -> Macro.expand(design, env)
          :error -> fail(env, "use Prism.Generator.Phoenix needs design: MyApp.Design")
        end

      unless is_atom(design) and match?({:module, _}, Code.ensure_compiled(design)) and
               function_exported?(design, :__schema__, 0),
             do:
               fail(
                 env,
                 "design: #{inspect(design)} is not a design (a module that uses Prism.Generator.Schema)"
               )

      components = components(design.__schema__(), env)

      # `use Phoenix.Component` once: the app's module may have it already.
      setup =
        unless Module.has_attribute?(env.module, :__components__),
          do: quote(do: use(Phoenix.Component))

      quote do
        unquote(setup)
        require Phoenix.Component
        # A compile-time dependency: this module recompiles when the design changes.
        require unquote(design)
        unquote_splicing(Enum.map(components, &define/1))
      end
    end

    @doc false
    # The components of a design's `__schema__/0`, each as the data its function
    # renders from.
    def components(%{components: components, web: web}, env) do
      unless web, do: fail(env, "the design has no `web` declaration, which names its classes")

      for c <- components do
        kind =
          Map.get(@kinds, c.name) ||
            fail(
              env,
              "the Phoenix target has no component #{inspect(c.name)}; it knows #{@kinds |> Map.keys() |> Enum.sort() |> Enum.map_join(", ", &inspect/1)}"
            )

        component(c, kind, web.prefix, components, env)
      end
    end

    defp component(c, kind, prefix, components, env) do
      known = Keyword.keys(kind.parts)

      for %{component: nil, name: name} <- c.parts, name not in known do
        fail(
          env,
          "the Phoenix target has no part #{inspect(name)} of #{inspect(c.name)}; " <>
            if(known == [],
              do: "it renders only parts that are other components there",
              else: "it knows #{Enum.map_join(known, ", ", &inspect/1)}"
            )
        )
      end

      parts = Enum.map(c.parts, &part(c, kind, &1, prefix, components, env))
      states = states(c, parts, prefix)
      items = for %{as: :list, item: item} <- parts, do: item

      spec = %{
        name: c.name,
        element: kind.element,
        void: kind.element in @void,
        class: Classes.component(prefix, c.name),
        attrs: Map.get(kind, :attrs, []),
        axes: axes(c, prefix),
        states: states,
        children: children(parts, kind, c),
        withs: withs(c, prefix),
        rest: if(Enum.any?(parts, &(&1.as == :control)), do: :control, else: :root)
      }

      names =
        Enum.map(spec.axes, & &1.name) ++
          Enum.map(states, & &1.name) ++ for(%{as: :slot, name: n} <- parts, do: n) ++ items

      for name <- names, name in @reserved do
        fail(env, "#{inspect(c.name)}: #{inspect(name)} is an attribute of every component")
      end

      spec
    end

    # A design part as what this target renders: the part's class and element, and
    # what it is.
    # A part that is another component has that component's element and class, with
    # the classes of its axes' defaults that are variants.
    defp part(c, _kind, %{component: ref} = p, prefix, components, _env) when ref != nil do
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

    defp part(c, kind, p, prefix, _components, env) do
      class = Classes.part(prefix, c, p.name)

      case kind.parts[p.name] do
        {:list, element, item} ->
          unless Enum.any?(c.parts, &(&1.name == item)),
            do: fail(env, "#{inspect(c.name)}: its #{inspect(p.name)} has no #{inspect(item)}")

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
              fail(
                env,
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

    # The children of the component's element, in the design's order, with the inner
    # block where the component puts it.
    defp children(parts, kind, c) do
      loading? = loading?(c)

      rendered =
        for p <- parts, p.as != :item do
          if p.as == :component, do: Map.put(p, :while_loading, loading?), else: p
        end

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
      own =
        c.states ++
          Enum.flat_map(c.with_parts, & &1.states) ++
          Enum.flat_map(
            c.variants,
            &(&1.states ++ Enum.flat_map(&1.with_parts, fn w -> w.states end))
          )

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

    # ------------------------------------------------------------ the function

    defp define(spec) do
      assigns = quote(do: assigns)

      body =
        quote do:
                Prism.Generator.Phoenix.Markup.render(
                  unquote(Macro.escape(spec)),
                  unquote(assigns)
                )

      # A `def` without the quote's import metadata, so it is the caller's: the one
      # `use Phoenix.Component` imports, which ties the attributes and slots above to
      # the function. A quoted `def` would be `Kernel.def`.
      function = {:def, [], [{spec.name, [], [assigns]}, [do: body]]}

      quote do
        @doc unquote(doc(spec))
        unquote_splicing(declarations(spec))
        unquote(function)
      end
    end

    defp declarations(spec) do
      axes =
        for a <- spec.axes do
          opts = [
            values: a.values,
            doc: "One of #{Enum.map_join(a.values, ", ", &"`#{inspect(&1)}`")}."
          ]

          opts = if a.default, do: Keyword.put(opts, :default, a.default), else: opts
          quote do: Phoenix.Component.attr(unquote(a.name), :atom, unquote(opts))
        end

      states =
        for s <- spec.states,
            do: quote(do: Phoenix.Component.attr(unquote(s.name), :boolean, default: false))

      as =
        case spec.element do
          {:as, default} ->
            [
              quote(
                do:
                  Phoenix.Component.attr(:as, :string,
                    default: unquote(default),
                    values: unquote(@as),
                    doc: "The element."
                  )
              )
            ]

          _ ->
            []
        end

      value =
        if Enum.any?(spec.children, &(&1.as == :value)),
          do: [quote(do: Phoenix.Component.attr(:value, :any, default: nil))],
          else: []

      element = rest_element(spec)
      own = Map.get(@own, element, []) -- Enum.map(spec.states, &Atom.to_string(&1.name))

      common = [
        quote(
          do:
            Phoenix.Component.attr(:class, :any,
              default: nil,
              doc: "Classes after the component's own."
            )
        ),
        quote(do: Phoenix.Component.attr(:rest, :global, include: unquote(own)))
      ]

      slots =
        for child <- spec.children,
            slot <- slots(child),
            do: slot

      axes ++ states ++ as ++ value ++ common ++ slots
    end

    defp slots(%{as: as}) when as in [:content, :inner_block],
      do: [quote(do: Phoenix.Component.slot(:inner_block))]

    # A part's slot takes any attribute, for the part's element: its `class` after
    # the part's own, `for` on a label, `phx-click` on an option. Phoenix checks a
    # slot's attributes only while it declares none and `validate_attrs` is off.
    defp slots(%{as: :slot, name: name}) do
      doc = "The #{name} part; its attributes go on the part's element."
      [quote(do: Phoenix.Component.slot(unquote(name), validate_attrs: false, doc: unquote(doc)))]
    end

    defp slots(%{as: :list, item: item, item_states: states}) do
      doc =
        "One #{item}; its attributes go on the #{item}'s element" <>
          Enum.map_join(states, "", &", and `#{&1.name}` adds its #{&1.name} look") <> "."

      [quote(do: Phoenix.Component.slot(unquote(item), validate_attrs: false, doc: unquote(doc)))]
    end

    defp slots(_), do: []

    defp rest_element(%{rest: :control, children: children}),
      do: Enum.find_value(children, &(&1.as == :control && &1.element))

    defp rest_element(%{element: {:as, default}}), do: default
    defp rest_element(%{element: element}), do: element

    defp doc(spec), do: "The design's `#{spec.name}` component."

    defp fail(env, description),
      do: raise(CompileError, file: env.file, line: env.line, description: description)
  end
end
