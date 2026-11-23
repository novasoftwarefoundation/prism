defmodule Prism.Generator.Kotlin.Components do
  @moduledoc """
  The Kotlin target's components: one file per design component, each a
  composable in Compose's own form for its kind. `M` is the `kotlin`
  declaration's name.

  | Component | Compose | Use |
  |---|---|---|
  | `button` | `MButton`, on `Modifier.clickable` | `MButton(onClick = save, variant = MButtonVariant.Primary) { Text("Save") }` |
  | `spinner` | `MSpinner`, a `Canvas` with progress semantics | `MSpinner(variant = MSpinnerVariant.Accent, progress = 0.4f)` |
  | `checkbox` | `MCheckbox`, on `Modifier.toggleable` | `MCheckbox(checked, onCheckedChange = { checked = it })` |
  | `text_field`, `text_area` | `MTextField`, `MTextArea`, a `BasicTextField` with a decorator | `MTextField(state, invalid = invalid, prefix = { Text("€") })` |
  | `field` | `MField`, a column around the app's control | `MField(label = { Text("Email") }) { MTextField(state) }` |
  | `radio_group`, `radio` | `MRadioGroup` (`Modifier.selectableGroup`), `MRadio` (`Modifier.selectable`) | `MRadio(checked, onClick = { … }) { Text("Yes") }` |
  | `select` | `MSelect`, on Material's `ExposedDropdownMenuBox` | `MSelect(expanded, onExpandedChange, label = { Text(choice) }) { Option(…) { … } }` |
  | `image_picker` | `MImagePicker`, a row | `MImagePicker(preview = { Image(…) }, button = { MButton(…) { … } })` |
  | `tag`, `message_bar`, `step_indicator` | a box each | `MTag(tone = MTagTone.Success) { Text("Done") }` |

  Like the Swift target, it knows the components by name, and their parts; a
  component, part or value it doesn't know fails generation.

  ## Looks

  Each component also has `MComponentLooks`: its look and each part's in one
  choice of variants, flags, parts, values and states, as `MLook`s, laid over
  each other as on the web (`Prism.Generator.Looks`, with the `android:`
  bindings). The composables draw from it; an app can read it too, for a
  composable of its own.

  ## The API

  The parameters follow Compose's order: what the component can't do without
  (`onClick`, `checked`, a text field's `state`), then `modifier`, then the
  design's choices, `enabled`, the parts the app fills, the
  `interactionSource`, and the content last.

  - **Each axis** is an enum class of the design's values (`MButtonVariant`,
    `MButtonTone`), its default when that is a name without a look of its own
    included; an alias is a property of its companion object. Cases are
    UpperCamelCase; a variant named by a number has the axis's name in front
    (`Size16`). An axis without a default is nullable, `null` by default.
  - **Each flag** is a `Boolean` with the design's default.
  - **A part the app fills** is a composable slot: the button's `icon` (with
    `iconSide`, `MSide.Start` or `MSide.End`, for a part the app may put at
    either side), a text field's `prefix`, a field's `label` and
    `errorMessage`, a select's `icon`. While the part is there, the component
    has its look with that part.
  - **The states Compose knows come from Compose:** pressed, hovered and
    focused from the `interactionSource` (a field's focus from its control's,
    a select's while its menu is open or its field has focus), disabled from
    `enabled`. Every other state is a `Boolean` the app sets (`loading`,
    `invalid`), and a checkbox's or radio's `checked` is the control's value,
    as Compose's own controls take it.
  - **A value** is a `Float?`: a spinner's progress from 0 to 1, as Compose's
    progress indicators take it; its looks take the design's 0 to 100.

  ## Mechanics

  What the web does in CSS, this target does in Compose: a button is
  `Modifier.clickable` with the button role and the app's indication
  (`LocalIndication`, Material's ripple under a `MaterialTheme`), and shows its
  spinner over its label while it is loading; a spinner draws its ring (a
  quarter of it, at a quarter's opacity around) and turns, or with a progress
  value its track and an arc from the top, with progress semantics for
  TalkBack; a checkbox draws its check mark; a text field and a text area are
  Compose's `BasicTextField` with a decorator that draws the box, its prefix
  and its placeholder; a select's list is Material's exposed dropdown menu with
  the listbox's look, its options the app's, in `Option`; a step indicator has
  tabular numbers; a field, a text field, a select and a message bar take the
  width they are given, as the web's block elements do. A look's colors and
  opacity animate over its transition; a move in the same update happens at
  once, as Compose lays out.
  """

  alias Prism.Generator.Kotlin
  alias Prism.Generator.Looks

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
    :step_indicator,
    :image_picker
  ]

  @parts %{
    button: [:label, :icon],
    text_field: [:prefix],
    field: [:label, :error_message],
    radio: [:control, :label],
    select: [:field, :icon, :listbox, :option],
    tag: [:label],
    image_picker: [:preview]
  }

  # The parts that are another component the app draws itself, in the part's place.
  @given %{image_picker: [:button]}

  @values %{spinner: [:progress]}

  # The kinds whose pressed, hovered and focused come from their interaction source.
  @interactive [:button, :checkbox, :radio, :text_field, :text_area]

  # The kinds that are a control, so take `enabled` whether or not the design gives
  # them a disabled look.
  @controls [:button, :checkbox, :radio, :text_field, :text_area, :select]

  @doc "The components the Kotlin target knows."
  def kinds, do: @kinds

  @doc false
  # `[{file_name, body}]`, one per design component.
  def files(design, ctx) do
    check!(design)
    for c <- design.components, do: {Kotlin.pascal(c.name), file(ctx, design, c)}
  end

  defp check!(design) do
    for c <- design.components do
      unless c.name in @kinds,
        do:
          raise(
            ArgumentError,
            "the Kotlin target has no component #{inspect(c.name)}; it knows #{Enum.map_join(@kinds, ", ", &inspect/1)}"
          )

      for p <- c.parts do
        known = Map.get(@parts, c.name, [])

        cond do
          p.component == :spinner ->
            :ok

          p.name in Map.get(@given, c.name, []) and p.component != nil ->
            :ok

          p.name in Map.get(@given, c.name, []) ->
            raise ArgumentError,
                  "#{inspect(c.name)}'s #{inspect(p.name)} is the app's own component, in the part's place; give it component: (part #{inspect(p.name)}, component: …)"

          p.component != nil ->
            raise ArgumentError,
                  "the Kotlin target draws a part that is another component only for a spinner; #{inspect(c.name)}'s #{inspect(p.name)} is a #{inspect(p.component)}"

          p.name not in known ->
            raise ArgumentError,
                  "the Kotlin target has no part #{inspect(p.name)} of #{inspect(c.name)}; " <>
                    if(known == [],
                      do: "it draws only a spinner part there",
                      else: "it knows #{Enum.map_join(known, ", ", &inspect/1)}"
                    )

          true ->
            :ok
        end
      end

      for v <- c.values, v.name not in Map.get(@values, c.name, []) do
        raise ArgumentError,
              "the Kotlin target has no value #{inspect(v.name)} of #{inspect(c.name)}; it draws only the spinner's :progress"
      end
    end
  end

  # ------------------------------------------------------------ a component's file

  defp file(ctx, design, c) do
    spec = spec(ctx, c)
    body = Enum.join([looks_class(ctx, c, spec), kind(ctx, design, c, spec)], "\n")
    enums = Enum.map_join(spec.axes, "\n", &axis_enum(c, &1))
    code = Enum.join(Enum.reject([enums, body], &(&1 == "")), "\n")

    "package #{ctx.package}\n\n#{imports(code)}\n#{code}" |> tidy()
  end

  # No blank line after `{` or before `}`, never two blank lines.
  defp tidy(code) do
    code
    |> String.replace(~r/\{\n\n+/, "{\n")
    |> String.replace(~r/\n\n+(\s*[\}\)])/, "\n\\1")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  # The imports a file's code uses, each once, in order.
  @imports [
    {~r/\bLocalIndication\b/, "androidx.compose.foundation.LocalIndication"},
    {~r/\bCanvas\(/, "androidx.compose.foundation.Canvas"},
    {~r/\.clickable\(/, "androidx.compose.foundation.clickable"},
    {~r/\bMutableInteractionSource\b/,
     "androidx.compose.foundation.interaction.MutableInteractionSource"},
    {~r/collectIsPressedAsState/,
     "androidx.compose.foundation.interaction.collectIsPressedAsState"},
    {~r/collectIsHoveredAsState/,
     "androidx.compose.foundation.interaction.collectIsHoveredAsState"},
    {~r/collectIsFocusedAsState/,
     "androidx.compose.foundation.interaction.collectIsFocusedAsState"},
    {~r/\bArrangement\b/, "androidx.compose.foundation.layout.Arrangement"},
    {~r/\bBox\(/, "androidx.compose.foundation.layout.Box"},
    {~r/\bColumn\(/, "androidx.compose.foundation.layout.Column"},
    {~r/\bColumnScope\b/, "androidx.compose.foundation.layout.ColumnScope"},
    {~r/\bIntrinsicSize\b/, "androidx.compose.foundation.layout.IntrinsicSize"},
    {~r/\bRow\(/, "androidx.compose.foundation.layout.Row"},
    {~r/\.fillMaxHeight\(/, "androidx.compose.foundation.layout.fillMaxHeight"},
    {~r/\.fillMaxWidth\(/, "androidx.compose.foundation.layout.fillMaxWidth"},
    {~r/\.height\(IntrinsicSize/, "androidx.compose.foundation.layout.height"},
    {~r/\.padding\(/, "androidx.compose.foundation.layout.padding"},
    {~r/\.progressSemantics\(/, "androidx.compose.foundation.progressSemantics"},
    {~r/\.selectable\(/, "androidx.compose.foundation.selection.selectable"},
    {~r/\.selectableGroup\(/, "androidx.compose.foundation.selection.selectableGroup"},
    {~r/\.toggleable\(/, "androidx.compose.foundation.selection.toggleable"},
    {~r/\bBasicTextField\(/, "androidx.compose.foundation.text.BasicTextField"},
    {~r/\bKeyboardActionHandler\b/,
     "androidx.compose.foundation.text.input.KeyboardActionHandler"},
    {~r/\bKeyboardOptions\b/, "androidx.compose.foundation.text.KeyboardOptions"},
    {~r/\bInputTransformation\b/, "androidx.compose.foundation.text.input.InputTransformation"},
    {~r/\bTextFieldLineLimits\b/, "androidx.compose.foundation.text.input.TextFieldLineLimits"},
    {~r/\bTextFieldState\b/, "androidx.compose.foundation.text.input.TextFieldState"},
    {~r/\bExposedDropdownMenuAnchorType\b/,
     "androidx.compose.material3.ExposedDropdownMenuAnchorType"},
    {~r/\bExposedDropdownMenuBox\(/, "androidx.compose.material3.ExposedDropdownMenuBox"},
    {~r/\bExposedDropdownMenu\(/, "androidx.compose.material3.ExposedDropdownMenu"},
    {~r/\bLocalContentColor\b/, "androidx.compose.material3.LocalContentColor"},
    {~r/\bLocalTextStyle\b/, "androidx.compose.material3.LocalTextStyle"},
    {~r/\bMenuDefaults\b/, "androidx.compose.material3.MenuDefaults"},
    {~r/@Composable/, "androidx.compose.runtime.Composable"},
    {~r/\bCompositionLocalProvider\b/, "androidx.compose.runtime.CompositionLocalProvider"},
    {~r/\bImmutable\b/, "androidx.compose.runtime.Immutable"},
    {~r/ by /, "androidx.compose.runtime.getValue"},
    {~r/\bmutableStateOf\b/, "androidx.compose.runtime.mutableStateOf"},
    {~r/\bremember \{/, "androidx.compose.runtime.remember"},
    {~r/\brememberInfiniteTransition\b/,
     "androidx.compose.animation.core.rememberInfiniteTransition"},
    {~r/\banimateFloat\(/, "androidx.compose.animation.core.animateFloat"},
    {~r/\binfiniteRepeatable\(/, "androidx.compose.animation.core.infiniteRepeatable"},
    {~r/\btween[(<]/, "androidx.compose.animation.core.tween"},
    {~r/var [a-z]+ by remember/, "androidx.compose.runtime.setValue"},
    {~r/\bAlignment\b/, "androidx.compose.ui.Alignment"},
    {~r/\bModifier\b/, "androidx.compose.ui.Modifier"},
    {~r/\.clip\(/, "androidx.compose.ui.draw.clip"},
    {~r/\.onFocusChanged\b/, "androidx.compose.ui.focus.onFocusChanged"},
    {~r/\bOffset\(/, "androidx.compose.ui.geometry.Offset"},
    {~r/\bSize\(/, "androidx.compose.ui.geometry.Size"},
    {~r/\bColor\b/, "androidx.compose.ui.graphics.Color"},
    {~r/\bPath\(\)/, "androidx.compose.ui.graphics.Path"},
    {~r/\bSolidColor\(/, "androidx.compose.ui.graphics.SolidColor"},
    {~r/\bStrokeCap\b/, "androidx.compose.ui.graphics.StrokeCap"},
    {~r/\bStrokeJoin\b/, "androidx.compose.ui.graphics.StrokeJoin"},
    {~r/\bStroke\(/, "androidx.compose.ui.graphics.drawscope.Stroke"},
    {~r/\brotate\(/, "androidx.compose.ui.graphics.drawscope.rotate"},
    {~r/\btakeOrElse\b/, "androidx.compose.ui.graphics.takeOrElse"},
    {~r/\bRole\b/, "androidx.compose.ui.semantics.Role"},
    {~r/\.dp\b/, "androidx.compose.ui.unit.dp"},
    {~r/\.sp\b/, "androidx.compose.ui.unit.sp"}
  ]

  defp imports(code) do
    @imports
    |> Enum.filter(fn {pattern, _} -> Regex.match?(pattern, code) end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map_join("", &"import #{&1}\n")
  end

  # The component's arguments, in order: `%{name, type, default, kind}`.
  defp spec(ctx, c) do
    axes =
      for {axis, default} <- axes(c) do
        variants = for v <- c.variants, v.axis == axis, do: v
        names = Enum.map(variants, & &1.name)
        cases = if default && default not in names, do: [default | names], else: names
        type = "#{ctx.m}#{Kotlin.pascal(c.name)}#{Kotlin.pascal(axis)}"

        %{
          axis: axis,
          name: Kotlin.ident(axis),
          type: if(default, do: type, else: type <> "?"),
          enum: type,
          default: if(default, do: "#{type}.#{case_name(axis, default)}", else: "null"),
          cases: Enum.map(cases, &case_name(axis, &1)),
          aliases:
            for(v <- variants, a <- v.aliases, do: {case_name(axis, a), case_name(axis, v.name)}),
          kind: :axis
        }
      end

    flags =
      for f <- c.flags,
          do: %{name: Kotlin.ident(f.name), type: "Boolean", default: "#{f.default}", kind: :flag}

    withs =
      for part <- with_parts(c),
          do: %{
            name: "with#{Kotlin.pascal(part)}",
            type: "Boolean",
            default: "false",
            kind: {:with, part}
          }

    values =
      for v <- c.values,
          do: %{
            name: Kotlin.ident(v.name),
            type: "Float?",
            default: "null",
            kind: {:value, v.name}
          }

    states = Looks.states(c, :android)

    states =
      for s <- states do
        %{name: state_name(s, states), type: "Boolean", default: "false", kind: s}
      end

    %{axes: axes, args: axes ++ flags ++ withs ++ values ++ states, states: states}
  end

  # The axes: the `:variant` axis first when it has variants or a default.
  defp axes(c) do
    own = Enum.any?(c.variants, &(&1.axis == :variant)) or c.default != nil
    if(own, do: [{:variant, c.default}], else: []) ++ Enum.map(c.axes, &{&1.name, &1.default})
  end

  defp case_name(axis, n) when is_integer(n), do: "#{Kotlin.pascal(axis)}#{n}"
  defp case_name(_axis, name), do: Kotlin.pascal(name)

  # The parts the component has a look with, in the design's order.
  defp with_parts(c) do
    withs = Enum.map(c.with_parts ++ Enum.flat_map(c.variants, & &1.with_parts), & &1.part)
    for p <- c.parts, p.name in withs, do: p.name
  end

  # A part's state is named by the state alone, unless the component or another part
  # has a state of that name too.
  defp state_name({:state, s}, _), do: Kotlin.ident(s)

  defp state_name({:part_state, part, s}, states) do
    same = Enum.count(states, &(elem(&1, tuple_size(&1) - 1) == s))
    if same > 1, do: Kotlin.ident(:"#{part}_#{s}"), else: Kotlin.ident(s)
  end

  defp axis_enum(c, a) do
    aliases =
      for {name, of} <- a.aliases,
          do:
            "        /** Another name of [#{of}]. */\n        public val #{name}: #{a.enum} get() = #{of}\n"

    companion =
      if aliases == [],
        do: "",
        else: ";\n\n    public companion object {\n#{Enum.join(aliases)}    }"

    """
    /** The #{words(a.axis)} of #{article(c.name)}. */
    public enum class #{a.enum} {
        #{Enum.join(a.cases, ", ")}#{companion}
    }
    """
  end

  # ------------------------------------------------------------ the looks

  defp looks_class(ctx, c, spec) do
    type = "#{ctx.m}#{Kotlin.pascal(c.name)}Looks"
    layers = Looks.layers(c, :android)

    # A part the app draws with its own component has no look here.
    parts =
      [{"root", nil}] ++
        for p <- c.parts,
            p.name not in Map.get(@given, c.name, []),
            do: {Kotlin.ident(p.name), p.name}

    changed = MapSet.new(layers, &(&1.part && Kotlin.ident(&1.part)))

    changed =
      if Enum.any?(layers, &(&1.part == nil)), do: MapSet.put(changed, "root"), else: changed

    vars =
      for {name, _} <- parts do
        if name in changed,
          do: "        var #{name} = #{ctx.m}Look()\n",
          else: "        val #{name} = #{ctx.m}Look()\n"
      end

    statements =
      for layer <- layers do
        target = if layer.part, do: Kotlin.ident(layer.part), else: "root"
        fields = look_fields(ctx, c, layer)

        case Enum.map(layer.conditions, &condition(&1, spec)) do
          [] ->
            Kotlin.fill("        ", "#{target} += #{ctx.m}Look(", fields, ")") <> "\n"

          conditions ->
            "        if (#{Enum.join(conditions, " && ")}) {\n" <>
              Kotlin.fill("            ", "#{target} += #{ctx.m}Look(", fields, ")") <>
              "\n        }\n"
        end
      end

    props =
      Enum.map_join(parts, "", fn {name, part} ->
        doc = if part, do: "The #{words(part)}'s look.", else: "The look of the component itself."
        "    /** #{doc} */\n    public val #{name}: #{ctx.m}Look\n"
      end)

    assigns = Enum.map_join(parts, "", fn {name, _} -> "        this.#{name} = #{name}\n" end)

    params =
      if spec.args == [],
        do: "",
        else: "(\n" <> Enum.map_join(spec.args, "", &"    #{param(&1)},\n") <> ")"

    """
    /**
     * The look of #{article(c.name)} and of each of its parts in one choice of its variants,
     * flags, parts and states, laid over each other as on the web.
     */
    @Immutable
    public class #{type}#{params} {
    #{props}
        init {
    #{Enum.join(vars)}#{Enum.join(statements)}#{assigns}    }
    }
    """
  end

  defp param(a), do: "#{a.name}: #{a.type} = #{a.default}"

  defp condition({:axis, axis, name}, spec) do
    a = Enum.find(spec.axes, &(&1.axis == axis))
    "#{a.name} == #{a.enum}.#{case_name(axis, name)}"
  end

  defp condition({:value, name}, _), do: "#{Kotlin.ident(name)} != null"
  defp condition({:flag, name}, _), do: Kotlin.ident(name)
  defp condition({:with, part}, _), do: "with#{Kotlin.pascal(part)}"
  defp condition(state, spec), do: Enum.find(spec.states, &(&1.kind == state)).name

  # A look as `MLook(…)`, its fields in the class's order.
  @order ~w(background foreground placeholder borderWidth borderColor borderSides outlineWidth outlineColor
            outlineOffset radius padding margin inset gap size width height minHeight maxHeight
            typography emphasis decoration shadow opacity transition rotation stroke track)

  defp look_fields(ctx, c, layer) do
    where = "#{inspect(c.name)}#{if layer.part, do: "'s #{inspect(layer.part)}"}"

    fields =
      layer.style
      |> Enum.flat_map(fn {key, value} -> Kotlin.fields(ctx, key, value, where) end)
      |> Enum.reverse()
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.sort_by(&Enum.find_index(@order, fn f -> f == elem(&1, 0) end))

    Enum.map(fields, fn
      {k, {:call, head, args}} -> {"#{k} = ", head, args}
      {k, v} -> "#{k} = #{v}"
    end)
  end

  # ------------------------------------------------------------ states and arguments

  # The Kotlin expression of a state Compose gives the kind, or `nil` for one the app
  # gives.
  defp platform(c, {:state, :disabled}) when c.name != :select, do: "!enabled"

  defp platform(c, {:state, s})
       when c.name in @interactive and s in [:pressed, :hovered, :focused],
       do: Atom.to_string(s)

  defp platform(%{name: :field}, {:state, :focused}), do: "focused"
  defp platform(%{name: :radio}, {:part_state, :control, :disabled}), do: "!enabled"
  defp platform(%{name: :select}, {:part_state, :field, :disabled}), do: "!enabled"
  defp platform(%{name: :select}, {:part_state, :field, :focused}), do: "focused || expanded"
  defp platform(%{name: :select}, {:state, :disabled}), do: "!enabled"
  defp platform(_c, _state), do: nil

  # The states the composable reads from its interaction source.
  defp interactions(c, spec) do
    if c.name in @interactive,
      do: for(%{kind: {:state, s}} <- spec.states, s in [:pressed, :hovered, :focused], do: s),
      else: []
  end

  defp collect(states) do
    Enum.map_join(states, "", fn s ->
      "    val #{s} by interactions.collectIs#{Kotlin.pascal(s)}AsState()\n"
    end)
  end

  # Whether the composable takes `enabled`.
  defp enabled?(c, spec),
    do: c.name in @controls or Enum.any?(spec.states, &(platform(c, &1.kind) == "!enabled"))

  # The arguments the app gives the composable: not the states Compose gives, nor the
  # looks with a part (the part's slot says it), nor those `except` names.
  defp own(c, spec, except) do
    Enum.reject(spec.args, fn a ->
      a.name in except or match?({:with, _}, a.kind) or platform(c, a.kind) != nil
    end)
  end

  # `MComponentLooks(…)` with the arguments as named arguments: `given` maps an
  # argument's name to its expression, the states Compose gives are theirs.
  defp looks_call(ctx, c, spec, given) do
    args =
      for a <- spec.args do
        value = Map.get(given, a.name) || platform(c, a.kind) || a.name
        "#{a.name} = #{value}"
      end

    {"#{ctx.m}#{Kotlin.pascal(c.name)}Looks(", args}
  end

  defp val_looks(ctx, c, spec, given, indent \\ "    ") do
    {head, args} = looks_call(ctx, c, spec, given)
    Kotlin.fill(indent, "val looks = #{head}", args, ")") <> "\n"
  end

  defp params(head, own, tail) do
    Enum.map_join(head ++ Enum.map(own, &param/1) ++ tail, "", &"    #{&1},\n")
  end

  defp enabled_param(c, spec),
    do: if(enabled?(c, spec), do: ["enabled: Boolean = true"], else: [])

  defp interaction_param, do: "interactionSource: MutableInteractionSource? = null"

  defp interaction_val,
    do: "    val interactions = interactionSource ?: remember { MutableInteractionSource() }\n"

  defp part?(c, name), do: Enum.any?(c.parts, &(&1.name == name))

  # A part's look in code: its look, or none for a part the design doesn't have.
  defp part_look(ctx, c, name),
    do: if(part?(c, name), do: "looks.#{Kotlin.ident(name)}", else: "#{ctx.m}Look()")

  # ------------------------------------------------------------ the kinds

  defp kind(ctx, design, %{name: :button} = c, spec) do
    m = ctx.m
    icon = Enum.find(c.parts, &(&1.name == :icon))
    spinner = Enum.find(c.parts, &(&1.component == :spinner))
    loading? = Enum.any?(spec.states, &(&1.kind == {:state, :loading}))
    with_icon? = Enum.any?(spec.args, &(&1.kind == {:with, :icon}))
    args = own(c, spec, [])

    slots =
      case icon do
        nil ->
          []

        %{position: nil} ->
          ["icon: (@Composable () -> Unit)? = null"]

        %{position: side} ->
          [
            "icon: (@Composable () -> Unit)? = null",
            "iconSide: #{m}Side = #{m}Side.#{Kotlin.pascal(side)}"
          ]
      end

    given = if with_icon?, do: %{"withIcon" => "icon != null"}, else: %{}

    side = fn s ->
      if icon.position, do: "icon != null && iconSide == #{m}Side.#{s}", else: "icon != null"
    end

    icon_box = fn s ->
      "                if (#{side.(s)}) #{m}LookBox(#{part_look(ctx, c, :icon)}) { icon() }\n"
    end

    {before, after_} =
      cond do
        icon == nil -> {"", ""}
        icon.position -> {icon_box.("Start"), icon_box.("End")}
        true -> {icon_box.("Start"), ""}
      end

    label =
      if part?(c, :label),
        do: "                #{m}LookBox(looks.label) { content() }\n",
        else: "                content()\n"

    spinner_code =
      case {spinner, loading?} do
        {nil, _} ->
          ""

        {part, true} ->
          "            if (loading) {\n                val spinner = #{spinner_look(ctx, design, part, "looks.#{Kotlin.ident(part.name)}")}\n                #{m}Ring(spinner, null)\n            }\n"

        {part, false} ->
          "            #{m}Ring(\n                #{spinner_look(ctx, design, part, "looks.#{Kotlin.ident(part.name)}")},\n                null,\n            )\n"
      end

    """
    /**
     * #{String.capitalize(article(c.name))}: the design's look on Compose's `clickable`, which
     * keeps the button's role, focus and keyboard, with the app's indication (Material's ripple
     * under a `MaterialTheme`) inside its shape. Pressed, hovered and focused come from
     * `interactionSource`, disabled from `enabled`.
     *
     * `#{m}Button(onClick = save#{example(spec)}) { Text("Save") }`
     */
    @Composable
    public fun #{m}Button(
    #{params(["onClick: () -> Unit", "modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ slots ++ [interaction_param(), "content: @Composable () -> Unit"])}) {
    #{interaction_val()}#{collect(interactions(c, spec))}#{val_looks(ctx, c, spec, given)}    val root = looks.root.animated()
        // The indication is drawn by the box, inside its shape.
        Box(
            modifier
                .clickable(
                    interactionSource = interactions,
                    indication = null,
                    enabled = enabled,
                    role = Role.Button,
                    onClick = onClick,
                )
                .#{ctx.lower}Box(root, interactions, LocalIndication.current),
            contentAlignment = Alignment.Center,
        ) {
            #{m}Text(root) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(root.gap ?: 0.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
    #{before}#{label}#{after_}            }
    #{spinner_code}        }
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :spinner} = c, spec) do
    m = ctx.m
    progress? = Enum.any?(c.values, &(&1.name == :progress))
    args = own(c, spec, ["progress"])

    {param, value, semantics} =
      if progress?,
        do:
          {["progress: Float? = null"], "    val value = progress?.coerceIn(0f, 1f)\n",
           "value?.let { Modifier.progressSemantics(it) } ?: Modifier.progressSemantics()"},
        else: {[], "", "Modifier.progressSemantics()"}

    given = if progress?, do: %{"progress" => "value?.times(100f)"}, else: %{}
    ring_progress = if progress?, do: "value?.times(100f)", else: "null"

    """
    /**
     * #{String.capitalize(article(c.name))}: a ring that turns, with progress semantics for
     * TalkBack. Without a variant it takes the content color around it. With `progress`, from
     * 0 to 1, it also draws the value from the top.
     *
     * `#{m}Spinner(#{String.trim_leading(example(spec), ", ")})`
     */
    @Composable
    public fun #{m}Spinner(
    #{params(["modifier: Modifier = Modifier"], args, param)}) {
    #{value}#{val_looks(ctx, c, spec, given)}    val semantics = #{semantics}
        #{m}Ring(looks.root, #{ring_progress}, modifier.then(semantics))
    }

    /**
     * The spinner's ring, turning once per its rotation: without a value a quarter of it, at a
     * quarter's opacity around; with one, from 0 to 100, the track and the value's arc from the
     * top, in the look's stroke.
     */
    @Composable
    internal fun #{m}Ring(look: #{m}Look, progress: Float?, modifier: Modifier = Modifier) {
        val color = look.foreground ?: LocalContentColor.current
        val rotation = look.rotation
        val turn = if (rotation != null && rotation.durationMillis > 0) {
            val transition = rememberInfiniteTransition(label = "spinner")
            val turning = tween<Float>(rotation.durationMillis, easing = rotation.curve)
            val angle by transition.animateFloat(
                initialValue = 0f,
                targetValue = 360f,
                animationSpec = infiniteRepeatable(turning),
                label = "turn",
            )
            angle
        } else {
            0f
        }
        Canvas(modifier.#{ctx.lower}Box(look)) {
            val side = size.minDimension
            // The web's image: a ring of 10 in a box of 24, 4 wide.
            val stroke = look.stroke
            val width = when {
                progress == null || stroke == null -> side / 6
                else -> stroke.width(side.toDp()).toPx()
            }
            val ring = Size(side - width, side - width)
            val topLeft = Offset(center.x - ring.width / 2, center.y - ring.height / 2)
            val line = Stroke(width)
            val arc = Stroke(width, cap = StrokeCap.Round)
            rotate(turn) {
                if (progress != null) {
                    val track = look.track ?: Color.Transparent
                    drawArc(track, 0f, 360f, false, topLeft, ring, style = line)
                    if (progress > 0f) {
                        val sweep = 360f * progress.coerceAtMost(100f) / 100f
                        drawArc(color, -90f, sweep, false, topLeft, ring, style = arc)
                    }
                } else {
                    val around = color.copy(alpha = color.alpha * 0.25f)
                    drawArc(around, 0f, 360f, false, topLeft, ring, style = line)
                    drawArc(color, -90f, 90f, false, topLeft, ring, style = arc)
                }
            }
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :checkbox} = c, spec) do
    m = ctx.m
    args = own(c, spec, ["checked"])

    """
    /**
     * #{String.capitalize(article(c.name))}: the design's box on Compose's `toggleable`, with
     * the checkbox role; checked while `checked` is. With `onCheckedChange` `null`, the box
     * only shows the value, for a row that toggles it with its label.
     *
     * `#{m}Checkbox(checked = remember, onCheckedChange = { remember = it })`
     */
    @Composable
    public fun #{m}Checkbox(
    #{params(["checked: Boolean", "onCheckedChange: ((Boolean) -> Unit)?", "modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ [interaction_param()])}) {
    #{interaction_val()}#{collect(interactions(c, spec))}#{val_looks(ctx, c, spec, %{"checked" => "checked"})}    val root = looks.root.animated()
        val mark = root.foreground ?: LocalContentColor.current
        val toggle = if (onCheckedChange == null) {
            Modifier
        } else {
            Modifier.toggleable(
                value = checked,
                interactionSource = interactions,
                indication = null,
                enabled = enabled,
                role = Role.Checkbox,
                onValueChange = onCheckedChange,
            )
        }
        // The indication is drawn by the box, inside its shape.
        val indication = LocalIndication.current.takeIf { onCheckedChange != null }
        Canvas(modifier.then(toggle).#{ctx.lower}Box(root, interactions, indication)) {
            if (checked) {
                // The web's check mark: a tick in a box of 16, 2 wide with round ends.
                val unit = size.minDimension / 16
                val path = Path().apply {
                    moveTo(center.x - 3.5f * unit, center.y + 0.5f * unit)
                    lineTo(center.x - 1.5f * unit, center.y + 2.5f * unit)
                    lineTo(center.x + 3.5f * unit, center.y - 2.5f * unit)
                }
                val line = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                drawPath(path, mark, style = line)
            }
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: k} = c, spec) when k in [:text_field, :text_area] do
    m = ctx.m
    pascal = Kotlin.pascal(k)
    prefix? = part?(c, :prefix)
    args = own(c, spec, [])
    with_prefix? = Enum.any?(spec.args, &(&1.kind == {:with, :prefix}))
    given = if with_prefix?, do: %{"withPrefix" => "prefix != null"}, else: %{}

    {lines, align, doc} =
      if k == :text_field,
        do:
          {"TextFieldLineLimits.SingleLine", "Alignment.CenterStart",
           """
            * a single line of text, and with `prefix` the app's content before it (a currency,
            * or its own picker), the field's box around both.\
           """},
        else:
          {"TextFieldLineLimits.MultiLine()", "Alignment.TopStart",
           """
            * lines of text, as many as the app's height or its text needs.\
           """}

    prefix_slot = if prefix?, do: ["prefix: (@Composable () -> Unit)? = null"], else: []

    prefix_box =
      if prefix?,
        do: """
                            if (prefix != null) {
                                Box(
                                    Modifier.fillMaxHeight().#{ctx.lower}Box(looks.prefix),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    #{m}Text(looks.prefix) { prefix() }
                                }
                            }
        """,
        else: ""

    """
    /**
     * #{String.capitalize(article(c.name))}: Compose's `BasicTextField` on `state`, with a
     * decorator that draws the design's box. It holds
    #{doc}
     * Focused comes from `interactionSource`, disabled from `enabled`; the placeholder shows
     * while the text is empty.
     *
     * `#{m}#{pascal}(state#{example(spec)}, placeholder = { Text("…") })`
     */
    @Composable
    public fun #{m}#{pascal}(
    #{params(["state: TextFieldState", "modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ ["readOnly: Boolean = false", "placeholder: (@Composable () -> Unit)? = null"] ++ prefix_slot ++ ["inputTransformation: InputTransformation? = null", "keyboardOptions: KeyboardOptions = KeyboardOptions.Default", "onKeyboardAction: KeyboardActionHandler? = null", interaction_param()])}) {
    #{interaction_val()}#{collect(interactions(c, spec))}#{val_looks(ctx, c, spec, given)}    val root = looks.root.animated()
        val style = root.textStyle(LocalTextStyle.current)
        BasicTextField(
            state = state,
            modifier = modifier.fillMaxWidth(),
            enabled = enabled,
            readOnly = readOnly,
            inputTransformation = inputTransformation,
            textStyle = style,
            keyboardOptions = keyboardOptions,
            onKeyboardAction = onKeyboardAction,
            lineLimits = #{lines},
            interactionSource = interactions,
            cursorBrush = SolidColor(style.color.takeOrElse { LocalContentColor.current }),
            decorator = { field ->
                #{m}Text(root) {
                    Row(Modifier.#{ctx.lower}Box(root.withoutPadding).height(IntrinsicSize.Min)) {
    #{prefix_box}                    Box(
                            Modifier.weight(1f).padding(root.padding.paddingValues()),
                            contentAlignment = #{align},
                        ) {
                            if (placeholder != null && state.text.isEmpty()) {
                                val hint = root.copy(foreground = root.placeholder ?: root.foreground)
                                #{m}Text(hint) { placeholder() }
                            }
                            field()
                        }
                    }
                }
            },
        )
    }
    """
  end

  defp kind(ctx, _design, %{name: :field} = c, spec) do
    m = ctx.m
    args = own(c, spec, [])
    label? = part?(c, :label)
    error? = part?(c, :error_message)

    slots =
      if(label?, do: ["label: (@Composable () -> Unit)? = null"], else: []) ++
        if(error?, do: ["errorMessage: (@Composable () -> Unit)? = null"], else: [])

    focus? = Enum.any?(spec.states, &(platform(c, &1.kind) == "focused"))

    focus =
      if focus?,
        do: "    var focused by remember { mutableStateOf(false) }\n",
        else: ""

    control =
      if focus?,
        do: "        Box(Modifier.onFocusChanged { focused = it.hasFocus }) { content() }\n",
        else: "        content()\n"

    """
    /**
     * #{String.capitalize(article(c.name))}: a label above the app's control and an error
     * message below it. Its label follows the control's focus, which it reads itself, and
     * `invalid`, which the app gives the control too.
     *
     * `#{m}Field(label = { Text("Email") }) { #{m}TextField(state) }`
     */
    @Composable
    public fun #{m}Field(
    #{params(["modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ slots ++ ["content: @Composable () -> Unit"])}) {
    #{focus}#{val_looks(ctx, c, spec, %{})}    Column(modifier.fillMaxWidth().#{ctx.lower}Box(looks.root.animated())) {
    #{if label?, do: "        if (label != null) #{m}LookBox(looks.label.animated()) { label() }\n", else: ""}#{control}#{if error?, do: "        if (errorMessage != null) #{m}LookBox(looks.errorMessage.animated()) { errorMessage() }\n", else: ""}    }
    }
    """
  end

  defp kind(ctx, _design, %{name: :radio_group} = c, spec) do
    m = ctx.m
    args = own(c, spec, [])

    """
    /**
     * #{String.capitalize(article(c.name))}: its radios one below the other, a selectable
     * group for TalkBack.
     *
     * `#{m}RadioGroup { #{m}Radio(checked = yes, onClick = { yes = true }) { Text("Yes") } }`
     */
    @Composable
    public fun #{m}RadioGroup(
    #{params(["modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ ["content: @Composable ColumnScope.() -> Unit"])}) {
    #{val_looks(ctx, c, spec, %{})}    Column(
            modifier.selectableGroup().#{ctx.lower}Box(looks.root),
            verticalArrangement = Arrangement.spacedBy(looks.root.gap ?: 0.dp),
            content = content,
        )
    }
    """
  end

  defp kind(ctx, _design, %{name: :radio} = c, spec) do
    m = ctx.m

    checked =
      Enum.find(
        spec.states,
        &(&1.kind in [{:part_state, :control, :checked}, {:state, :checked}])
      )

    args = own(c, spec, [checked && checked.name])
    given = if checked, do: %{checked.name => "checked"}, else: %{}
    label? = part?(c, :label)

    """
    /**
     * #{String.capitalize(article(c.name))}: its control and its label in a row, on Compose's
     * `selectable` with the radio button role; checked while `checked` is. With `onClick`
     * `null`, it only shows the choice.
     *
     * `#{m}Radio(checked = choice == Choice.Yes, onClick = { choice = Choice.Yes }) { Text("Yes") }`
     */
    @Composable
    public fun #{m}Radio(
    #{params(["checked: Boolean", "onClick: (() -> Unit)?", "modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ [interaction_param(), "content: @Composable () -> Unit"])}) {
    #{interaction_val()}#{collect(interactions(c, spec))}#{val_looks(ctx, c, spec, given)}    val root = looks.root.animated()
        val select = if (onClick == null) {
            Modifier
        } else {
            Modifier.selectable(
                selected = checked,
                interactionSource = interactions,
                indication = LocalIndication.current,
                enabled = enabled,
                role = Role.RadioButton,
                onClick = onClick,
            )
        }
        Row(
            modifier.then(select).#{ctx.lower}Box(root),
            horizontalArrangement = Arrangement.spacedBy(root.gap ?: 0.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.#{ctx.lower}Box(#{part_look(ctx, c, :control)}.animated()))
            #{if label?, do: "#{m}LookBox(looks.label) { content() }", else: "#{m}Text(root) { content() }"}
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :select} = c, spec) do
    m = ctx.m
    # The list's and the options' states are the options' (in `Option`), not the select's.
    listed =
      for s <- spec.states,
          match?({:part_state, p, _} when p in [:listbox, :option], s.kind),
          do: s

    args = own(c, spec, Enum.map(listed, & &1.name))
    icon? = part?(c, :icon)
    option_states = for s <- listed, match?({:part_state, :option, _}, s.kind), do: s
    field_given = Map.new(listed, &{&1.name, "false"})

    option_given =
      for(
        s <- spec.states,
        platform(c, s.kind) != nil or s in listed,
        into: %{},
        do: {s.name, "false"}
      )
      |> Map.merge(
        Map.new(option_states, fn s ->
          case s.kind do
            {_, _, :hovered} -> {s.name, "hovered"}
            {_, _, :selected} -> {s.name, "selected"}
            {_, _, :disabled} -> {s.name, "!enabled"}
            {_, _, :pressed} -> {s.name, "pressed"}
            {_, _, :focused} -> {s.name, "focused"}
            _ -> {s.name, "false"}
          end
        end)
      )
      |> Map.merge(Map.new(args, &{&1.name, &1.name}))

    option_collect =
      for(
        %{kind: {:part_state, :option, s}} <- option_states,
        s in [:hovered, :pressed, :focused],
        do: s
      )
      |> collect()
      |> String.replace("\n    val", "\n        val")
      |> then(&if(&1 == "", do: "", else: "    " <> &1))

    option_interactions =
      if option_collect == "",
        do: "",
        else: "        val interactions = remember { MutableInteractionSource() }\n"

    scope_props = Enum.map_join(args, "", &"    private val #{&1.name}: #{&1.type},\n")
    scope_args = Enum.map_join(args, ", ", & &1.name)
    {head, option_args} = looks_call(ctx, c, spec, option_given)
    option_looks = Kotlin.fill("        ", "val looks = #{head}", option_args, ")") <> "\n"

    icon_slot = if icon?, do: ["icon: (@Composable () -> Unit)? = null"], else: []

    icon_box =
      if icon?,
        do: """
                        if (icon != null) {
                            Box(
                                Modifier.align(Alignment.CenterEnd)
                                    .padding(looks.icon.inset.paddingValues()),
                            ) {
                                icon()
                            }
                        }
        """,
        else: ""

    selectable =
      if Enum.any?(option_states, &match?({_, _, :hovered}, &1.kind)),
        do: "interactions",
        else: "null"

    listbox = part_look(ctx, c, :listbox)
    option = part_look(ctx, c, :option)

    """
    /**
     * #{String.capitalize(article(c.name))}: the design's field on Material's
     * `ExposedDropdownMenuBox`, which opens its menu, and the list in the menu with the
     * listbox's look. The app fills the field with its choice (`label`) and the list with its
     * options (`Option`). Focused while its menu is open or its field has focus, disabled from
     * `enabled`; its icon takes the field's text color.
     *
     * ```
     * #{m}Select(expanded, onExpandedChange = { expanded = it }, label = { Text(choice) }) {
     *     Option(selected = choice == "Yes", onClick = { choice = "Yes" }) { Text("Yes") }
     * }
     * ```
     */
    @Composable
    public fun #{m}Select(
    #{params(["expanded: Boolean", "onExpandedChange: (Boolean) -> Unit", "modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ icon_slot ++ ["label: @Composable () -> Unit", "content: @Composable #{m}SelectScope.() -> Unit"])}) {
        var focused by remember { mutableStateOf(false) }
    #{val_looks(ctx, c, spec, field_given)}    val field = #{part_look(ctx, c, :field)}.animated()
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = onExpandedChange,
            modifier = modifier,
        ) {
            #{m}Text(field) {
                Box(
                    Modifier
                        .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable, enabled)
                        .onFocusChanged { focused = it.hasFocus }
                        .fillMaxWidth()
                        .#{ctx.lower}Box(field.withoutPadding),
                ) {
                    Box(
                        Modifier.align(Alignment.CenterStart).padding(field.padding.paddingValues()),
                    ) {
                        label()
                    }
    #{icon_box}            }
            }
            val listbox = #{listbox}
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { onExpandedChange(false) },
                shape = listbox.shape,
                containerColor = listbox.background ?: MenuDefaults.containerColor,
                shadowElevation = if (listbox.shadow != null) MenuDefaults.ShadowElevation else 0.dp,
            ) {
                #{m}SelectScope(#{scope_args}).content()
            }
        }
    }

    /** The options of #{article(c.name)}'s list. */
    public class #{m}SelectScope internal constructor(
    #{scope_props}) {
        /**
         * An option: the design's option look on Compose's `selectable`; selected while
         * `selected` is, hovered from the pointer.
         */
        @Composable
        public fun Option(
            selected: Boolean,
            onClick: () -> Unit,
            modifier: Modifier = Modifier,
            enabled: Boolean = true,
            content: @Composable () -> Unit,
        ) {
    #{option_interactions}#{option_collect}#{option_looks}        val option = #{option}.animated()
            Box(
                modifier
                    .fillMaxWidth()
                    .selectable(
                        selected = selected,
                        interactionSource = #{selectable},
                        indication = LocalIndication.current,
                        enabled = enabled,
                        onClick = onClick,
                    )
                    .#{ctx.lower}Box(option),
                contentAlignment = Alignment.CenterStart,
            ) {
                #{m}Text(option) { content() }
            }
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :image_picker} = c, spec) do
    m = ctx.m
    args = own(c, spec, [])
    preview = part_look(ctx, c, :preview)

    """
    /**
     * #{String.capitalize(article(c.name))}: a preview the app fills with its image (cropped to
     * the preview: `Modifier.fillMaxSize()` and `ContentScale.Crop`) or its placeholder, and the
     * app's own button beside it. The app's photo picker and what happens on a pick are the
     * app's.
     *
     * `#{m}ImagePicker(preview = { Image(…) }, button = { #{m}Button(onClick = pick) { … } })`
     */
    @Composable
    public fun #{m}ImagePicker(
    #{params(["modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ ["preview: @Composable () -> Unit", "button: @Composable () -> Unit"])}) {
    #{val_looks(ctx, c, spec, %{})}    Row(
            modifier.#{ctx.lower}Box(looks.root),
            horizontalArrangement = Arrangement.spacedBy(looks.root.gap ?: 0.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.#{ctx.lower}Box(#{preview}).clip(#{preview}.shape),
                contentAlignment = Alignment.Center,
            ) {
                preview()
            }
            button()
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: k} = c, spec) when k in [:tag, :message_bar, :step_indicator] do
    m = ctx.m
    pascal = Kotlin.pascal(k)
    args = own(c, spec, [])

    {doc, box} =
      case k do
        :tag ->
          inner =
            if part?(c, :label),
              do: "#{m}LookBox(looks.label) { content() }",
              else: "content()"

          {"its label on its background", "    #{m}LookBox(looks.root, modifier) { #{inner} }\n"}

        :message_bar ->
          {"a message across the width it is given",
           """
               Box(modifier.fillMaxWidth().#{ctx.lower}Box(looks.root), contentAlignment = Alignment.CenterStart) {
                   #{m}Text(looks.root) { content() }
               }
           """}

        :step_indicator ->
          {"a step's number in its circle, in tabular numbers",
           """
               Box(modifier.#{ctx.lower}Box(looks.root), contentAlignment = Alignment.Center) {
                   #{m}Text(looks.root) {
                       CompositionLocalProvider(
                           LocalTextStyle provides LocalTextStyle.current.copy(fontFeatureSettings = "tnum"),
                           content = content,
                       )
                   }
               }
           """}
      end

    """
    /**
     * #{String.capitalize(article(c.name))}: #{doc}.
     *
     * `#{m}#{pascal}(#{String.trim_leading(example(spec), ", ")}) { Text("…") }`
     */
    @Composable
    public fun #{m}#{pascal}(
    #{params(["modifier: Modifier = Modifier"], args, enabled_param(c, spec) ++ ["content: @Composable () -> Unit"])}) {
    #{val_looks(ctx, c, spec, %{})}#{box}}
    """
  end

  # The look of a part that is a spinner: the spinner's own look with the variants the
  # part picks, and the component's changes to the part over it.
  defp spinner_look(ctx, design, part, look) do
    spinner = Enum.find(design.components, &(&1.name == :spinner))

    picks =
      for {axis, default} <- axes(spinner),
          picked = Keyword.get(part.variants, axis, default),
          picked != nil do
        "#{Kotlin.ident(axis)} = #{ctx.m}Spinner#{Kotlin.pascal(axis)}.#{case_name(axis, picked)}"
      end

    "#{ctx.m}SpinnerLooks(#{Enum.join(picks, ", ")}).root + #{look}"
  end

  defp example(spec) do
    spec.axes
    |> Enum.filter(&(&1.cases != []))
    |> Enum.take(1)
    |> Enum.map_join(fn a -> ", #{a.name} = #{a.enum}.#{Enum.at(a.cases, -1)}" end)
  end

  defp words(name), do: name |> to_string() |> String.replace("_", " ")

  defp article(name) do
    w = words(name)
    if String.first(w) in ~w(a e i o u), do: "an #{w}", else: "a #{w}"
  end
end
