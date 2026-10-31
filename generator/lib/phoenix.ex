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
    - **Each flag** (`flag :padded, default: true`) is a boolean attribute
      with the flag's default; while it is on, it adds its class
      (`--padded`). A flag whose only looks are with some variants adds it
      only with those (a padding only some variants have).
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
      its look with a part (`with_part :icon`) adds `--with-icon`. A part
      with `position:` in the design goes at the `:start` or the `:end` of
      the content, as the attribute `<part>_position` says (`icon_position`,
      with the design's side as its default); `start` and `end` follow the
      text's direction.
    - `class` appends the app's classes to the component's own; `rest` takes
      global attributes (`id`, `phx-*`, `aria-*`, `data-*`) and the element's
      own (`type`, `name`, `value`, …).

    The markup comes from `Prism.Generator.Web.Elements`, which the React
    components (`Prism.Generator.React`) render from too, and its class names
    from `Prism.Generator.Web.Classes`, the same functions that name the
    classes of the web target's CSS.

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

    alias Prism.Generator.Web.Elements

    # The element's own attributes `rest` takes, besides the globals.
    @own %{
      "button" =>
        ~w(type form formaction formenctype formmethod formnovalidate formtarget name value autofocus href target rel download disabled),
      "input" =>
        ~w(accept autocomplete autofocus form list max maxlength min minlength multiple name pattern placeholder readonly required size step type value disabled checked),
      "textarea" =>
        ~w(autocomplete autofocus cols form maxlength minlength name placeholder readonly required rows wrap disabled)
    }

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
    # renders from (`Prism.Generator.Web.Elements`).
    def components(schema, env) do
      specs =
        try do
          Elements.components(schema, "the Phoenix target")
        rescue
          e in ArgumentError -> fail(env, Exception.message(e))
        end

      for spec <- specs do
        names =
          Enum.map(spec.axes, & &1.name) ++
            Enum.map(spec.flags, & &1.name) ++
            Enum.map(spec.positions, & &1.name) ++
            Enum.map(spec.states, & &1.name) ++
            for(%{as: :slot, name: n} = child <- spec.children, child[:side] != :end, do: n) ++
            for(%{as: :list, item: item} <- spec.children, do: item)

        for name <- names, name in @reserved do
          fail(env, "#{inspect(spec.name)}: #{inspect(name)} is an attribute of every component")
        end

        case names -- Enum.uniq(names) do
          [] ->
            :ok

          [name | _] ->
            fail(env, "#{inspect(spec.name)}: two attributes are named #{inspect(name)}")
        end

        spec
      end
    end

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

      flags =
        for f <- spec.flags do
          doc = "While true, adds `#{f.class}`#{only_doc(f)}."

          quote do:
                  Phoenix.Component.attr(unquote(f.name), :boolean,
                    default: unquote(f.default),
                    doc: unquote(doc)
                  )
        end

      positions =
        for p <- spec.positions do
          doc = "The #{p.part} part's side of the content: `:start` or `:end`."

          quote do:
                  Phoenix.Component.attr(unquote(p.name), :atom,
                    values: [:start, :end],
                    default: unquote(p.default),
                    doc: unquote(doc)
                  )
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
                    values: unquote(Elements.as()),
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

      # A part whose side the app picks is there twice; it is one slot.
      slots =
        for child <- spec.children,
            child[:side] != :end,
            slot <- slots(child),
            do: slot

      axes ++ flags ++ positions ++ states ++ as ++ value ++ common ++ slots
    end

    defp only_doc(%{only: nil}), do: ""

    defp only_doc(%{only: only}) do
      " with " <>
        Enum.map_join(only, " or ", fn {axis, values} ->
          "#{axis} #{Enum.map_join(values, " or ", &"`#{inspect(&1)}`")}"
        end)
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
