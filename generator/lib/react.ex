defmodule Prism.Generator.React do
  @moduledoc """
  Generates React components from a design: one TSX file per component in
  `src/`, a `src/index.ts` that exports them all, and `src/helpers.ts`.
  A package built from them with `tsc` ships ES modules and type declarations;
  the CSS comes from the web target, at the same version.

  A component renders its look, never behaviour: the markup and classes of
  `Prism.Generator.Web.Elements`, the same data the Phoenix components
  (`Prism.Generator.Phoenix`) render from, with class names from
  `Prism.Generator.Web.Classes`, as the CSS has. The classes are literals in
  the generated code, so there is no class logic in TypeScript to drift from
  the CSS.

  ## Props

  - **Each axis** (`variant`, and each `variants` block such as `tone` or
    `size`) is a prop typed as a union of the design's values, its variants
    and their aliases, and its default when that is a name without a look of
    its own, so TypeScript rejects any other value: strings, or numbers when
    the design names them by numbers (`size={16}`). Any other value, from
    code TypeScript doesn't check, throws when it renders; an axis without a
    default also takes `undefined`. Its default is the
    design's; a default that is one of the variants adds that variant's
    class, one without a look adds none. An axis without a default adds no
    class until the app picks a variant.
  - **Each flag** is a boolean prop with the flag's default; while it is
    true, it adds the flag's class. A flag whose only looks are with some
    variants adds it only with those (a padding only some variants have).
  - **A part with `position:`** in the design gets a `<part>Position` prop,
    `"start"` or `"end"` (`iconPosition`), with the design's side as its
    default: the part goes at that side of the content, which follows the
    text's direction. Any other value throws when it renders.
  - **Each value** (a spinner's `progress`) is a number prop from 0 to 100,
    clamped; `null` or `NaN` is no value, as `undefined` is (Phoenix's
    `nil`). While the app gives it, the element gets the value's class
    (`--progress`), `role="progressbar"` with `aria-valuenow`,
    `aria-valuemin` and `aria-valuemax`, and what the value draws (a
    spinner's ring); without it, none of them. The app names a progress
    bar with `aria-label` or `aria-labelledby`, which go on the element.
    Anything else that isn't a number, such as `"40"`, throws when it
    renders, as in Phoenix.
  - **Each state the app sets** is a boolean prop: a state the CSS writes as a
    modifier class adds that class (`loading`, `invalid`, a radio's
    `disabled`); `disabled` and `checked` on a form control set the element's
    own attribute, which the CSS's pseudo-class reads, also on a part that is
    a form control. The browser's states need no prop.
  - **Parts**, in the design's order: the part that holds the content gets
    `children`; a part such as an icon is a prop of its own name (`icon`,
    `errorMessage`), with `<part>Props` for its element's attributes, and
    while it is there its look with a part adds `--with-<part>`; a part that
    is another component (a button's spinner) is rendered while the component
    is `loading`, when it has a loading state, and always otherwise; a list
    part's items (a select's options) are an array prop (`options`) of the
    items' attributes, each with a boolean per item state.
  - A button's element is `as`, one of `Prism.Generator.Web.Elements.as/0`,
    and its other props are that element's.
  - `className` appends the app's classes to the component's own. The other
    props (`onClick`, `id`, `aria-*`, the element's own attributes) go on the
    element, or on the form control of a component that has one (a radio's
    input), which also gets the ref.
  """

  alias Prism.Generator.Web.Elements

  @width 100

  # Names every component's props or code use.
  @reserved ~w(className children as ref key rest element Element classNames present forwardRef)

  @keywords ~w(await break case catch class const continue debugger default delete do else enum
               export extends false finally for function if implements import in instanceof
               interface let new null package private protected public return static super switch
               this throw true try typeof var void while with yield)

  @dom %{
    "a" => "HTMLAnchorElement",
    "button" => "HTMLButtonElement",
    "div" => "HTMLDivElement",
    "input" => "HTMLInputElement",
    "label" => "HTMLLabelElement",
    "li" => "HTMLLIElement",
    "p" => "HTMLParagraphElement",
    "span" => "HTMLSpanElement",
    "textarea" => "HTMLTextAreaElement",
    "ul" => "HTMLUListElement"
  }

  @doc """
  The files of the React target for a design's `__schema__/0`, as
  `[{path, body, design_file}]`, every body made from the design's own file.
  `mix prism.gen` puts a `Prism.Generator.Header` line naming that file above
  each body.
  """
  def files(design) do
    specs = Elements.components(design, "the React target")
    if specs == [], do: raise(ArgumentError, "the design has no components")
    Enum.each(specs, &check!/1)

    components = for spec <- specs, do: {"src/#{pascal(spec.name)}.tsx", component(spec)}

    for {path, body} <-
          components ++ [{"src/helpers.ts", helpers()}, {"src/index.ts", index(specs)}],
        do: {path, body, design.file}
  end

  # ------------------------------------------------------------ props

  # The component's own props, in order: `{name, type, doc, default}`.
  defp props(spec) do
    axes =
      for a <- spec.axes do
        {camel(a.name), type_name(spec, a.name), axis_doc(spec, a),
         a.default && js_value(a.default)}
      end

    flags =
      for f <- spec.flags,
          do: {camel(f.name), "boolean", flag_doc(f), if(f.default, do: "true")}

    positions =
      for p <- spec.positions do
        {camel(p.name), ~s("start" | "end"),
         "The #{words(p.part)} part's side of the content. Default #{js_str(p.default)}.",
         js_str(p.default)}
      end

    states = for s <- spec.states, do: {camel(s.name), "boolean", state_doc(spec, s), nil}

    values =
      for v <- spec.values do
        {camel(v.name), "number | null",
         "#{v.min} to #{v.max} (clamped; null or NaN: none); adds `#{v.class}`, a progressbar.",
         nil}
      end

    # A part whose side the app picks is there twice; it is one prop.
    parts =
      spec.children
      |> Enum.reject(&(&1[:side] == :end))
      |> Enum.flat_map(fn
        %{as: :slot, name: name, element: element} ->
          [
            {camel(name), "ReactNode", slot_doc(spec, name), nil},
            {camel(name) <> "Props", "ComponentPropsWithoutRef<#{js_str(element)}>",
             "Attributes of the #{words(name)} part's `<#{element}>`.", nil}
          ]

        %{as: :list} = list ->
          [{items(list), "#{item_type(spec, list)}[]", list_doc(list), "[]"}]

        _ ->
          []
      end)

    content =
      case Enum.find(spec.children, &(&1.as in [:content, :inner_block])) do
        %{as: :content, name: name} ->
          [{"children", "ReactNode", "The #{words(name)} part's content.", nil}]

        %{as: :inner_block} ->
          [{"children", "ReactNode", "The content.", nil}]

        nil ->
          []
      end

    axes ++
      flags ++
      positions ++
      states ++
      values ++
      parts ++ [{"className", "string", "Classes after the component's own.", nil}] ++ content
  end

  defp flag_doc(f) do
    only =
      case f.only do
        nil ->
          ""

        only ->
          " with " <>
            Enum.map_join(only, " or ", fn {axis, values} ->
              "#{words(axis)} #{Enum.map_join(values, " or ", &js_value/1)}"
            end)
      end

    "Adds `#{f.class}`#{only}. Default #{f.default}."
  end

  defp check!(spec) do
    names = for {name, _, _, _} <- props(spec), do: name
    fixed = ~w(className children)

    # The module's own constants, which a prop of the same name would hide.
    consts =
      [camel(spec.name) <> "Elements" | Enum.map(spec.axes, &classes_const/1)] ++
        Enum.flat_map(spec.values, &[value_const(&1), attributes_const(&1)])

    for name <- names -- fixed, name in @reserved or name in @keywords or name in consts do
      raise ArgumentError,
            "the React target can't name a prop of #{inspect(spec.name)} #{inspect(name)}"
    end

    own_types =
      Enum.map(~w(Props OwnProps Element Attributes OtherAttributes), &(pascal(spec.name) <> &1)) ++
        for(%{as: :list} = list <- spec.children, do: item_type(spec, list))

    for a <- spec.axes, type_name(spec, a.name) in own_types do
      raise ArgumentError,
            "the React target can't name an axis of #{inspect(spec.name)} #{inspect(a.name)}: " <>
              "its type, #{type_name(spec, a.name)}, is one of the component's own types"
    end

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [name | _] ->
        raise ArgumentError, "#{inspect(spec.name)} has two props named #{inspect(name)}"
    end
  end

  defp axis_doc(_spec, %{default: nil}), do: "No default: without one, it adds no class."

  defp axis_doc(_spec, a) do
    if a.classes[a.default],
      do: "Default #{js_value(a.default)}.",
      else: "Default #{js_value(a.default)}, which has no class."
  end

  defp state_doc(spec, s) do
    effects =
      Enum.map(s.effects, fn
        {:class, _part, class} -> "adds `#{class}`"
        {:native, nil, name} -> "sets the element's `#{name}`"
        {:native, part, name} -> "sets `#{name}` on the #{words(part)} part"
      end)

    shows =
      for %{as: :component, while_loading: true, name: name} <- spec.children,
          s.name == :loading,
          do: "shows the #{words(name)} part"

    sentence(effects ++ shows)
  end

  defp slot_doc(spec, name) do
    case spec.withs[name] do
      nil ->
        "The #{words(name)} part."

      class ->
        "The #{words(name)} part; while it is there, the #{words(spec.name)} gets `#{class}`."
    end
  end

  defp list_doc(list) do
    states = for s <- list.item_states, do: "`#{camel(s.name)}`"

    "The #{words(list.item)} parts, in the #{words(list.name)} part" <>
      if(states == [], do: ".", else: "; each takes #{Enum.join(states, ", ")}.")
  end

  defp sentence(clauses) do
    text = Enum.join(clauses, "; ")
    String.upcase(String.first(text)) <> String.slice(text, 1..-1//1) <> "."
  end

  # ------------------------------------------------------------ a component

  defp component(spec) do
    name = pascal(spec.name)
    own = "#{name}OwnProps"
    rest_tag = rest_element(spec)

    as? = match?({:as, _}, spec.element)
    lists = for %{as: :list} = l <- spec.children, do: l
    no_content = not Enum.any?(spec.children, &(&1.as in [:content, :inner_block]))

    body =
      IO.iodata_to_binary([
        Enum.map(spec.axes, &axis_type(spec, &1)),
        if(as?, do: elements_type(spec), else: []),
        Enum.map(lists, &item_type_decl(spec, &1)),
        Enum.map(spec.axes, &axis_classes(spec, &1)),
        own_interface(spec, own),
        props_type(spec, name, own, rest_tag, no_content),
        function(spec, name, rest_tag)
      ])

    types =
      for type <- ~w(ComponentPropsWithoutRef ReactNode Ref),
          body =~ ~r/\b#{type}\b/,
          do: "type #{type}"

    helpers = for helper <- ~w(classNames present), body =~ "#{helper}(", do: helper

    import_line(["forwardRef" | types], "react") <>
      import_line(helpers, "./helpers.js") <> body
  end

  defp import_line(names, from) do
    flat = ~s(import { #{Enum.join(names, ", ")} } from "#{from}";)

    if String.length(flat) <= @width,
      do: flat <> "\n",
      else: "import {\n" <> Enum.map_join(names, "", &"  #{&1},\n") <> ~s(} from "#{from}";\n)
  end

  defp axis_type(spec, a) do
    values = Enum.map_join(a.values, " | ", &js_value/1)

    "\n/** The #{words(spec.name)}'s #{words(a.name)}. */\nexport type #{type_name(spec, a.name)} = #{values};\n"
  end

  defp elements_type(spec) do
    const = camel(spec.name) <> "Elements"
    values = Enum.map_join(Elements.as(), ", ", &js_str/1)

    """

    /** The elements a #{words(spec.name)} can be: \`as\`. */
    export const #{const} = [#{values}] as const;
    export type #{pascal(spec.name)}Element = (typeof #{const})[number];
    """
  end

  defp item_type_decl(spec, list) do
    states = for s <- list.item_states, do: "#{camel(s.name)}?: boolean"
    fields = Enum.uniq(["selected?: boolean" | states])

    head = "export type #{item_type(spec, list)} = { #{Enum.join(fields, "; ")} } &"
    attrs = "ComponentPropsWithoutRef<#{js_str(list.item_element)}>;"

    "\n/** One of the #{words(list.item)} parts: its attributes, and its states. */\n" <>
      wrap(head, attrs) <> "\n"
  end

  defp axis_classes(spec, a) do
    type = type_name(spec, a.name)
    value = if Enum.all?(a.values, &a.classes[&1]), do: "string", else: "string | undefined"

    entries =
      Enum.map(a.values, fn v ->
        "  #{v}: #{if class = a.classes[v], do: js_str(class), else: "undefined"},\n"
      end)

    ["\nconst #{classes_const(a)}: Record<#{type}, #{value}> = {\n", entries, "};\n"]
  end

  defp own_interface(spec, own) do
    fields =
      for {name, type, doc, _default} <- props(spec) do
        "  /** #{doc} */\n  #{name}?: #{type};\n"
      end

    ["\nexport interface #{own} {\n", fields, "}\n"]
  end

  defp props_type(spec, name, own, rest_tag, no_content) do
    omit = if no_content, do: "keyof #{own} | \"children\"", else: "keyof #{own}"

    case spec.element do
      # One member per element. Without `as`, the default member can't be told
      # apart from the others, so it refuses their own attributes (`never`).
      {:as, default} ->
        attrs = "#{name}Attributes"
        others = "#{name}OtherAttributes"
        keys = for tag <- Elements.as(), tag != default, do: "keyof #{attrs}<#{js_str(tag)}>"

        members =
          for tag <- Elements.as() do
            if tag == default,
              do:
                "    | ({ as?: #{js_str(tag)} } & #{attrs}<#{js_str(tag)}> & { [K in #{others}]?: never })\n",
              else: "    | ({ as: #{js_str(tag)} } & #{attrs}<#{js_str(tag)}>)\n"
          end

        [
          "\n/** The attributes of one of the elements a #{words(spec.name)} can be. */\n",
          wrap(
            "type #{attrs}<E extends #{name}Element> =",
            "Omit<ComponentPropsWithoutRef<E>, #{omit} | \"as\">;"
          ),
          "\n",
          "\n/** The attributes only the other elements have, which a #{words(spec.name)} without `as` refuses. */\n",
          "type #{others} = Exclude<\n  #{Enum.join(keys, " | ")},\n  keyof #{attrs}<#{js_str(default)}>\n>;\n",
          "\nexport type #{name}Props = #{own} &\n  (\n",
          members,
          "  );\n"
        ]

      _ ->
        head = "export type #{name}Props = #{own} &"
        omitted = "Omit<ComponentPropsWithoutRef<#{js_str(rest_tag)}>, #{omit}>;"
        "\n" <> wrap(head, omitted) <> "\n"
    end
  end

  # A type on one line, or wrapped after its `=` or `&` when that is past the width.
  defp wrap(head, rest) do
    if String.length("#{head} #{rest}") <= @width,
      do: "#{head} #{rest}",
      else: "#{head}\n  #{rest}"
  end

  defp function(spec, name, rest_tag) do
    ref_type =
      case spec.element do
        {:as, _} when spec.rest == :root -> "HTMLElement"
        _ -> Map.fetch!(@dom, rest_tag)
      end

    bindings =
      case spec.element do
        {:as, default} -> ["as: element = #{js_str(default)}"]
        _ -> []
      end ++
        for(
          {prop, _, _, default} <- props(spec),
          do: if(default, do: "#{prop} = #{default}", else: prop)
        ) ++
        ["...rest"]

    pattern = bindings_pattern(bindings, 2)

    guard =
      case spec.element do
        {:as, default} ->
          const = camel(spec.name) <> "Elements"
          list = Enum.map_join(Elements.as(), ", ", &js_str/1)

          """
            if (!#{const}.includes(element)) {
              throw new Error(`as: ${JSON.stringify(element)} is not one of #{list}`);
            }
            // Typed as a #{default}: #{name}Props has checked the props for the element the app picked.
            const Element = element as #{js_str(default)};
          """

        _ ->
          ""
      end

    # An axis's value is one of the design's, or undefined for an axis without a
    # default; any other value would add no class.
    axes = Enum.map(spec.axes, &axis_check/1)

    # A part's side is "start" or "end"; any other value would drop the part.
    positions =
      for p <- spec.positions do
        prop = camel(p.name)

        """
          if (#{prop} !== "start" && #{prop} !== "end") {
            throw new Error(`#{prop}: ${JSON.stringify(#{prop})} is not one of "start", "end"`);
          }
        """
      end

    root = root(spec)

    [
      "\n/** The design's `#{spec.name}` component. */\n",
      "export const #{name} = forwardRef<#{ref_type}, #{name}Props>(function #{name}(\n",
      pattern,
      ",\n  ref,\n) {\n",
      guard,
      axes,
      positions,
      Enum.map(spec.values, &value_consts/1),
      "  return (\n",
      render(root, 4),
      "\n  );\n});\n"
    ]
  end

  defp axis_check(a) do
    prop = camel(a.name)
    values = Enum.map_join(a.values, ", ", &js_value/1)
    known = "[#{values}].includes(#{prop})"
    test = if a.default, do: ["!" <> known], else: ["#{prop} !== undefined", "!" <> known]
    message = "`#{prop}: ${JSON.stringify(#{prop})} is not one of #{values}`"

    condition =
      if String.length("  if (#{Enum.join(test, " && ")}) {") <= @width,
        do: "  if (#{Enum.join(test, " && ")}) {\n",
        else: "  if (\n" <> Enum.map_join(test, " &&\n", &"    #{&1}") <> "\n  ) {\n"

    [condition, js_throw(message), "  }\n"]
  end

  # `throw new Error(message)` inside an `if`, wrapped when it is past the width.
  defp js_throw(message) do
    if String.length("    throw new Error(#{message});") <= @width,
      do: "    throw new Error(#{message});\n",
      else: "    throw new Error(\n      #{message},\n    );\n"
  end

  defp bindings_pattern(bindings, indent) do
    pad = String.duplicate(" ", indent)
    flat = "#{pad}{ #{Enum.join(bindings, ", ")} }"

    if String.length(flat) <= @width,
      do: flat,
      else: "#{pad}{\n" <> Enum.map_join(bindings, ",\n", &"#{pad}  #{&1}") <> "\n#{pad}}"
  end

  # A value's number, clamped to its range, and the attributes it adds. Without a
  # finite number (`undefined`, `null`, `NaN`) there is none, as with Phoenix's `nil`.
  defp value_consts(v) do
    prop = camel(v.name)
    clamp = "Math.min(#{v.max}, Math.max(#{v.min}, #{prop}))"

    entries =
      Enum.map(v.attrs, fn {name, value} ->
        key = if String.contains?(to_string(name), "-"), do: js_str(name), else: to_string(name)
        "          #{key}: #{js_expr(v, value)},\n"
      end)

    [
      "  // A #{words(v.name)} that isn't a number would be no value.\n",
      "  if (#{prop} != null && typeof #{prop} !== \"number\") {\n",
      js_throw(
        "`#{prop}: ${JSON.stringify(#{prop})} is not a number from #{v.min} to #{v.max}, or null`"
      ),
      "  }\n",
      "  // The #{words(v.name)}, within #{v.min} and #{v.max}, and its attributes while the app gives it:\n",
      "  // none without a finite number (undefined, null, NaN).\n",
      "  const #{value_const(v)} =\n",
      "    #{prop} == null || !Number.isFinite(#{prop})\n",
      "      ? undefined\n",
      "      : #{clamp};\n",
      "  const #{attributes_const(v)} =\n",
      "    #{value_const(v)} === undefined\n",
      "      ? {}\n",
      "      : {\n",
      entries,
      "        };\n\n"
    ]
  end

  # A value's attribute in TypeScript: text, or the number with what follows it.
  defp js_expr(_v, text) when is_binary(text), do: js_str(text)
  defp js_expr(_v, n) when is_integer(n), do: Integer.to_string(n)
  defp js_expr(v, {:value, ""}), do: value_const(v)
  defp js_expr(v, {:value, suffix}), do: "`${#{value_const(v)}}#{suffix}`"

  defp value_const(v), do: camel(v.name) <> "Value"
  defp attributes_const(v), do: camel(v.name) <> "Attributes"

  # ------------------------------------------------------------ the markup

  # The root element as a JSX node.
  defp root(spec) do
    tag =
      case spec.element do
        {:as, _} -> "Element"
        tag -> tag
      end

    on_root = spec.rest == :root

    axes =
      for a <- spec.axes do
        lookup = "#{classes_const(a)}[#{camel(a.name)}]"
        if a.default, do: lookup, else: "#{camel(a.name)} && #{lookup}"
      end

    flags =
      for f <- spec.flags do
        only =
          for {axis, values} <- f.only || [],
              value <- values,
              do: "#{camel(axis)} === #{js_value(value)}"

        case only do
          [] -> "#{camel(f.name)} && #{js_str(f.class)}"
          [one] -> "#{camel(f.name)} && #{one} && #{js_str(f.class)}"
          many -> "#{camel(f.name)} && (#{Enum.join(many, " || ")}) && #{js_str(f.class)}"
        end
      end

    states =
      for {name, {:class, nil, class}} <- effects(spec), do: "#{camel(name)} && #{js_str(class)}"

    withs =
      for {part, class} <- spec.withs, test = present_test(spec, part), test != "false" do
        if test == "true", do: js_str(class), else: "#{test} && #{js_str(class)}"
      end

    values = for v <- spec.values, do: "#{value_const(v)} !== undefined && #{js_str(v.class)}"
    classes = [js_str(spec.class)] ++ axes ++ flags ++ states ++ values ++ withs ++ ["className"]

    # An element the app picks is typed as its default (`function/3`).
    {ref, rest} =
      case spec.element do
        {:as, default} ->
          {"ref={ref as Ref<#{Map.fetch!(@dom, default)}>}",
           "{...(rest as ComponentPropsWithoutRef<#{js_str(default)}>)}"}

        _ ->
          {"ref={ref}", "{...rest}"}
      end

    attrs =
      if(on_root, do: [ref], else: []) ++
        fixed_attrs(spec.attrs) ++
        natives(spec, nil) ++
        Enum.map(spec.values, &"{...#{attributes_const(&1)}}") ++
        if(on_root, do: [rest], else: []) ++ [class_attr(classes)]

    # What a value draws, after the other children, while the app gives it.
    drawn =
      for v <- spec.values, tree <- v.children do
        {:cond, "#{value_const(v)} !== undefined", jsx(tree, v)}
      end

    children = Enum.flat_map(spec.children, &child(&1, spec)) ++ drawn

    {:el, tag, attrs, children}
  end

  # A value's markup tree as a JSX node: attributes by React's names.
  defp jsx({:above_min, tree}, v), do: {:cond, "#{value_const(v)} > #{v.min}", jsx(tree, v)}

  defp jsx({tag, attrs, children}, v) do
    attrs =
      for {name, value} <- attrs do
        case value do
          text when is_binary(text) -> "#{jsx_name(name)}=#{js_str(text)}"
          expr -> "#{jsx_name(name)}={#{js_expr(v, expr)}}"
        end
      end

    {:el, tag, attrs, Enum.map(children, &jsx(&1, v))}
  end

  defp jsx_name(:class), do: "className"

  defp jsx_name(name) do
    case to_string(name) do
      "aria-" <> _ = aria ->
        aria

      "data-" <> _ = data ->
        data

      other ->
        [first | rest] = String.split(other, "-")
        Enum.join([first | Enum.map(rest, &String.capitalize/1)])
    end
  end

  defp child(%{as: :inner_block}, _spec), do: [{:expr, "{children}"}]
  defp child(%{as: :value}, _spec), do: []

  defp child(%{as: :content} = p, spec) do
    attrs =
      fixed_attrs(p.attrs) ++
        natives(spec, p.name) ++ [class_attr([js_str(p.class) | part_classes(spec, p.name)])]

    [{:cond, "present(children)", {:el, p.element, attrs, [{:expr, "{children}"}]}}]
  end

  defp child(%{as: :slot} = p, spec) do
    prop = camel(p.name)
    props = prop <> "Props"

    attrs =
      fixed_attrs(p.attrs) ++
        [
          "{...#{props}}",
          class_attr([js_str(p.class) | part_classes(spec, p.name)] ++ ["#{props}?.className"])
        ]

    test =
      case p do
        %{side: side} -> "#{camel(p.position)} === #{js_str(side)} && present(#{prop})"
        _ -> "present(#{prop})"
      end

    [{:cond, test, {:el, p.element, attrs, [{:expr, "{#{prop}}"}]}}]
  end

  defp child(%{as: :control} = p, spec) do
    attrs =
      ["type=#{js_str(p.type)}", "ref={ref}"] ++
        natives(spec, p.name) ++
        ["{...rest}", class_attr([js_str(p.class) | part_classes(spec, p.name)])]

    [{:el, p.element, attrs, []}]
  end

  defp child(%{as: :component} = p, _spec) do
    el = {:el, p.element, ["className=#{js_str(Enum.join(p.class, " "))}"], []}
    if p.while_loading, do: [{:cond, "loading", el}], else: [el]
  end

  defp child(%{as: :list} = p, _spec) do
    items = items(p)
    states = for s <- p.item_states, do: camel(s.name)
    bindings = Enum.uniq(["key", "selected" | states]) ++ ["className: itemClassName", "...item"]

    classes =
      [js_str(p.item_class)] ++
        for(s <- p.item_states, do: "#{camel(s.name)} && #{js_str(s.class)}") ++ ["itemClassName"]

    item =
      {:el, p.item_element,
       [
         "key={key ?? index}",
         ~s(role="option"),
         "aria-selected={selected}",
         "{...item}",
         class_attr(classes)
       ], []}

    list =
      {:el, p.element, [~s(role="listbox"), "className=#{js_str(p.class)}"],
       [{:map, "#{items}.map(({ #{Enum.join(bindings, ", ")} }, index) =>", item}]}

    [{:cond, "#{items}.length > 0", list}]
  end

  defp effects(spec), do: for(s <- spec.states, e <- s.effects, do: {s.name, e})

  defp natives(spec, part),
    do: for({name, {:native, ^part, _}} <- effects(spec), do: "#{camel(name)}={#{camel(name)}}")

  defp part_classes(spec, part),
    do:
      for(
        {name, {:class, ^part, class}} <- effects(spec),
        do: "#{camel(name)} && #{js_str(class)}"
      )

  defp fixed_attrs(attrs), do: for({name, value} <- attrs, do: "#{name}=#{js_str(value)}")

  # Whether a part is there, as a TypeScript test, `"true"` or `"false"`.
  defp present_test(spec, part) do
    case Enum.find(spec.children, &(&1[:name] == part)) do
      %{as: :content} -> "present(children)"
      %{as: :slot} -> "present(#{camel(part)})"
      %{as: :list} = list -> "#{items(list)}.length > 0"
      %{as: :component, while_loading: true} -> "loading"
      %{as: :component} -> "true"
      _ -> "false"
    end
  end

  # `className=…`: a literal when no class depends on a prop.
  defp class_attr(classes) do
    if Enum.all?(classes, &String.starts_with?(&1, "\"")),
      do: "className=#{js_str(Enum.map_join(classes, " ", &JSON.decode!/1))}",
      else: {:call, "className={classNames(", classes, ")}"}
  end

  # Renders a JSX node at `indent`, as lines without a trailing newline.
  defp render(node, indent) do
    pad = String.duplicate(" ", indent)
    flat = flat(node)

    if flat && String.length(pad <> flat) <= @width,
      do: pad <> flat,
      else: broken(node, indent)
  end

  defp broken({:el, tag, attrs, children}, indent) do
    pad = String.duplicate(" ", indent)
    flat_open = "<#{tag}" <> Enum.map_join(attrs, "", &(" " <> flat_attr(&1)))

    open =
      if Enum.all?(attrs, &flat_attr/1) and
           String.length(pad <> flat_open <> if(children == [], do: " />", else: ">")) <= @width,
         do: pad <> flat_open,
         else:
           pad <>
             "<#{tag}\n" <>
             Enum.map_join(attrs, "\n", &attr(&1, indent + 2)) <> "\n" <> pad

    broke? = String.contains?(open, "\n")

    case children do
      [] ->
        open <> if(broke?, do: "/>", else: " />")

      _ ->
        open <>
          ">\n" <>
          Enum.map_join(children, "\n", &render(&1, indent + 2)) <> "\n#{pad}</#{tag}>"
    end
  end

  defp broken({:cond, test, el}, indent) do
    pad = String.duplicate(" ", indent)
    "#{pad}{#{test} && (\n" <> render(el, indent + 2) <> "\n#{pad})}"
  end

  defp broken({:map, head, el}, indent) do
    pad = String.duplicate(" ", indent)
    "#{pad}{#{head} (\n" <> render(el, indent + 2) <> "\n#{pad}))}"
  end

  defp broken({:expr, code}, indent), do: String.duplicate(" ", indent) <> code

  # A node on one line, or nil when it has more than one line.
  defp flat({:expr, code}), do: code
  defp flat({:map, _, _}), do: nil

  defp flat({:cond, test, el}) do
    if flat = flat(el), do: "{#{test} && #{flat}}"
  end

  defp flat({:el, tag, attrs, children}) do
    open = "<#{tag}" <> Enum.map_join(attrs, "", &(" " <> flat_attr(&1)))

    case children do
      [] -> open <> " />"
      [{:expr, code}] -> "#{open}>#{code}</#{tag}>"
      _ -> nil
    end
  end

  defp flat_attr({:call, head, args, tail}), do: head <> Enum.join(args, ", ") <> tail
  defp flat_attr(text), do: text

  defp attr(attr, indent) do
    pad = String.duplicate(" ", indent)
    flat = pad <> flat_attr(attr)

    case attr do
      {:call, head, args, tail} when byte_size(flat) > @width ->
        pad <> head <> "\n" <> Enum.map_join(args, "", &"#{pad}  #{&1},\n") <> pad <> tail

      _ ->
        flat
    end
  end

  # ------------------------------------------------------------ the other files

  defp helpers do
    """
    import type { ReactNode } from "react";

    /** A class name, or nothing when a prop doesn't add one. */
    export type ClassName = string | false | null | undefined;

    /** The class names that are there, separated by spaces. */
    export function classNames(...names: ClassName[]): string {
      return names.filter((name) => typeof name === "string" && name !== "").join(" ");
    }

    /** Whether the app gave content: anything but nothing, `null` or a boolean. */
    export function present(node: ReactNode): boolean {
      return node !== undefined && node !== null && typeof node !== "boolean";
    }
    """
  end

  defp index(specs) do
    Enum.map_join(specs, "", &~s(export * from "./#{pascal(&1.name)}.js";\n))
  end

  # ------------------------------------------------------------ names

  defp rest_element(%{rest: :control, children: children}),
    do: Enum.find_value(children, &(&1.as == :control && &1.element))

  defp rest_element(%{element: {:as, default}}), do: default
  defp rest_element(%{element: element}), do: element

  defp items(list), do: camel(list.item) <> "s"
  defp item_type(spec, list), do: pascal(spec.name) <> pascal(list.item)
  defp type_name(spec, axis), do: pascal(spec.name) <> pascal(axis)
  defp classes_const(a), do: camel(a.name) <> "Classes"

  defp pascal(name), do: name |> Atom.to_string() |> Macro.camelize()

  defp camel(name) do
    [first | rest] = name |> Atom.to_string() |> String.split("_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end

  defp words(name), do: name |> Atom.to_string() |> String.replace("_", " ")

  defp js_str(value), do: JSON.encode!(to_string(value))

  # A design value in TypeScript: a number as it is, a name as a string.
  defp js_value(value) when is_integer(value), do: Integer.to_string(value)
  defp js_value(value), do: js_str(value)
end
