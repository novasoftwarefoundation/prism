defmodule Prism.Generator.Swift.Components do
  @moduledoc """
  The Swift target's components: one file per design component, each in
  SwiftUI's own form for its kind. `M` is the `swift` declaration's module.

  | Component | Swift | Use |
  |---|---|---|
  | `button` | `MButtonStyle: ButtonStyle` | `.buttonStyle(.m(.primary, tone: .danger))` |
  | `spinner` | `MSpinnerStyle: ProgressViewStyle` | `.progressViewStyle(.m(.accent, size: .size16))` |
  | `checkbox` | `MCheckboxStyle: ToggleStyle` | `.toggleStyle(.m())` |
  | `text_field`, `text_area` | a `ViewModifier` | `.mTextField(focused: focused, invalid: invalid)` on a `TextField`, `.mTextArea()` on a `TextEditor` |
  | `select` | `MSelect`, a `Menu` | `MSelect { items } label: { Text(choice) }` |
  | `field`, `radio_group`, `radio`, `tag`, `message_bar`, `step_indicator` | a view each | `MTag(tone: .success) { Text("Done") }` |

  Like the web target, it knows the components by name, and their parts: the
  button's `label` and `icon`, the field's `label` and `error_message`, the
  radio's `control` and `label`, the select's `field`, `icon`, `listbox` and
  `option`, the tag's `label`, a part that is a spinner, and the spinner's
  `progress` value. A component, part or value it doesn't know fails
  generation.

  ## Looks

  Each component also has `MComponentLooks`: its look and each part's in one
  choice of variants, flags, parts, values and states, as `MLook`s, laid over
  each other as on the web (`Prism.Generator.Swift.Looks`). The styles and
  views draw from it; an app can read it too, for a view of its own.

  ## The API

  - **Each axis** is an enum of the design's values (`MButtonVariant`,
    `MButtonTone`), its default when that is a name without a look of its own
    included; an alias is a static property of the enum. A variant named by a
    number has the axis's name in front (`size16`). The `:variant` axis is
    the first argument, without a label; an axis without a default is
    optional, `nil` by default.
  - **Each flag** is a `Bool` with the design's default.
  - **A part the app fills** (an icon, a field's label) is there or not: the
    button's icon is `icon:`, the side of the label it goes at (`.start` or
    `.end`, `nil` without an icon; `Bool` for a part without a side), which
    the button lays out on a `Label`'s icon. The views take a field's label
    and error message as `Text?` and a select's icon as `Image?`. While the
    part is there, the component has its look with that part.
  - **The states SwiftUI knows come from SwiftUI:** pressed from the button's
    `configuration.isPressed`, checked from the toggle, disabled from
    `.disabled(_:)` (`isEnabled`), hovered from the pointer (a button and a
    checkbox). Every other state the design gives is a `Bool` the app sets
    (`loading`, `invalid`, a text field's `focused`, which the app has from
    its `@FocusState`).
  - **A value** is a `Double?` from 0 to 100; a spinner takes its progress
    from the `ProgressView`'s fraction.

  ## Mechanics

  What the web does in CSS, this target does in SwiftUI: a button is a
  `ButtonStyle` whose spinner shows while it is loading, in the label's place;
  a spinner draws its ring (a quarter of it, at a quarter's opacity around)
  and turns, or with a progress value its track and an arc from the top; a
  checkbox draws its check mark; a select's list is the system's menu, so the
  listbox and option looks are only in its looks, for an app's own list, and
  its icon takes the text color around it, not the menu's tint; a spinner
  keeps the `ProgressView`'s label and value for VoiceOver; a
  text field's placeholder color is in its modifier's `prompt(_:)`, since a
  modifier can't reach a `TextField`'s prompt; a step indicator has tabular
  numbers; a field, a text field and a message bar take the width they are
  given, as the web's block elements do.
  """

  alias Prism.Generator.Swift
  alias Prism.Generator.Swift.Looks

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
    :step_indicator
  ]

  @parts %{
    button: [:label, :icon],
    field: [:label, :error_message],
    radio: [:control, :label],
    select: [:field, :icon, :listbox, :option],
    tag: [:label]
  }

  @values %{spinner: [:progress]}

  # The states SwiftUI gives each kind, as Swift expressions in its body.
  @platform %{
    button: %{pressed: "configuration.isPressed", hovered: "hovered", disabled: "!isEnabled"},
    checkbox: %{checked: "configuration.isOn", hovered: "hovered", disabled: "!isEnabled"}
  }

  @doc "The components the Swift target knows."
  def kinds, do: @kinds

  @doc false
  # `[{file_name, body}]`, one per design component.
  def files(design, ctx) do
    check!(design)
    for c <- design.components, do: {Swift.pascal(c.name), file(ctx, design, c)}
  end

  defp check!(design) do
    for c <- design.components do
      unless c.name in @kinds,
        do:
          raise(
            ArgumentError,
            "the Swift target has no component #{inspect(c.name)}; it knows #{Enum.map_join(@kinds, ", ", &inspect/1)}"
          )

      for p <- c.parts do
        known = Map.get(@parts, c.name, [])

        cond do
          p.component == :spinner ->
            :ok

          p.component != nil ->
            raise ArgumentError,
                  "the Swift target draws a part that is another component only for a spinner; #{inspect(c.name)}'s #{inspect(p.name)} is a #{inspect(p.component)}"

          p.name not in known ->
            raise ArgumentError,
                  "the Swift target has no part #{inspect(p.name)} of #{inspect(c.name)}; " <>
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
              "the Swift target has no value #{inspect(v.name)} of #{inspect(c.name)}; it draws only the spinner's :progress"
      end
    end
  end

  # ------------------------------------------------------------ a component's file

  defp file(ctx, design, c) do
    spec = spec(ctx, c)

    [
      "import SwiftUI\n",
      Enum.map_join(spec.axes, "\n", &axis_enum(ctx, c, &1)),
      looks_struct(ctx, c, spec),
      kind(ctx, design, c, spec)
    ]
    |> Enum.join("\n")
    |> tidy()
  end

  # The templates' empty parts: an empty argument list is `()`, an empty body `{}`;
  # no blank line after `{` or before `}`, and never two blank lines.
  defp tidy(code) do
    code
    |> String.replace(~r/\(\n\s*\n\s*\)/, "()")
    |> String.replace(~r/\(\) \{\n\s*\}/, "() {}")
    |> String.replace(~r/\{\n\n+/, "{\n")
    |> String.replace(~r/\n\n+(\s*\})/, "\n\\1")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  # The component's arguments, in order: `%{name, type, default, label, kind}`.
  defp spec(ctx, c) do
    axes =
      for {axis, default} <- axes(c) do
        variants = for v <- c.variants, v.axis == axis, do: v
        names = Enum.map(variants, & &1.name)
        cases = if default && default not in names, do: [default | names], else: names
        type = "#{ctx.m}#{Swift.pascal(c.name)}#{Swift.pascal(axis)}"

        %{
          axis: axis,
          name: if(axis == :variant, do: "variant", else: Swift.ident(axis)),
          label: axis != :variant,
          type: if(default, do: type, else: type <> "?"),
          enum: type,
          default: if(default, do: "." <> case_name(axis, default), else: "nil"),
          cases: Enum.map(cases, &case_name(axis, &1)),
          aliases:
            for(v <- variants, a <- v.aliases, do: {case_name(axis, a), case_name(axis, v.name)}),
          kind: :axis
        }
      end

    flags =
      for f <- c.flags,
          do: %{
            name: Swift.ident(f.name),
            type: "Bool",
            default: "#{f.default}",
            label: true,
            kind: :flag
          }

    withs =
      for part <- with_parts(c),
          do: %{
            name: "with#{Swift.pascal(part)}",
            type: "Bool",
            default: "false",
            label: true,
            kind: {:with, part}
          }

    values =
      for v <- c.values,
          do: %{
            name: Swift.ident(v.name),
            type: "Double?",
            default: "nil",
            label: true,
            kind: {:value, v.name}
          }

    states = Looks.states(c)

    states =
      for s <- states do
        %{name: state_name(s, states), type: "Bool", default: "false", label: true, kind: s}
      end

    %{axes: axes, args: axes ++ flags ++ withs ++ values ++ states, states: states}
  end

  # The axes: the `:variant` axis first when it has variants or a default.
  defp axes(c) do
    own = Enum.any?(c.variants, &(&1.axis == :variant)) or c.default != nil
    if(own, do: [{:variant, c.default}], else: []) ++ Enum.map(c.axes, &{&1.name, &1.default})
  end

  defp case_name(axis, n) when is_integer(n), do: "#{Swift.camel(axis)}#{n}"
  defp case_name(_axis, name), do: Swift.ident(name)

  # The parts the component has a look with, in the design's order.
  defp with_parts(c) do
    withs = Enum.map(c.with_parts ++ Enum.flat_map(c.variants, & &1.with_parts), & &1.part)
    for p <- c.parts, p.name in withs, do: p.name
  end

  # A part's state is named by the state alone, unless the component or another part
  # has a state of that name too.
  defp state_name({:state, s}, _), do: Swift.ident(s)

  defp state_name({:part_state, part, s}, states) do
    same = Enum.count(states, &(elem(&1, tuple_size(&1) - 1) == s))
    if same > 1, do: Swift.ident(:"#{part}_#{s}"), else: Swift.ident(s)
  end

  defp axis_enum(_ctx, c, a) do
    aliases =
      for {name, of} <- a.aliases,
          do:
            "\n    /// Another name of `#{of}`.\n    public static var #{name}: Self { .#{of} }\n"

    """
    /// The #{words(a.axis)} of #{article(c.name)}.
    public enum #{a.enum}: Sendable, Hashable, CaseIterable {
        case #{Enum.join(a.cases, ", ")}
    #{Enum.join(aliases)}}
    """
    |> String.replace("\n\n}", "\n}")
  end

  # ------------------------------------------------------------ the looks

  defp looks_struct(ctx, c, spec) do
    type = "#{ctx.m}#{Swift.pascal(c.name)}Looks"
    parts = for p <- c.parts, do: "    public var #{Swift.ident(p.name)} = #{ctx.m}Look()\n"
    params = spec.args |> Enum.map(&param/1) |> wrap("        ", ",")

    statements =
      for layer <- Looks.layers(c) do
        target = if layer.part, do: Swift.ident(layer.part), else: "root"
        fields = look_fields(ctx, c, layer)

        case Enum.map(layer.conditions, &condition(&1, spec)) do
          [] ->
            Swift.fill("        ", "#{target}.apply(#{ctx.m}Look(", fields, "))") <> "\n"

          conditions ->
            "        if #{Enum.join(conditions, " && ")} {\n" <>
              Swift.fill("            ", "#{target}.apply(#{ctx.m}Look(", fields, "))") <>
              "\n        }\n"
        end
      end

    """
    /// The look of #{article(c.name)} and of each of its parts in one choice of its
    /// variants, flags, parts and states, laid over each other as on the web.
    public struct #{type}: Sendable, Hashable {
        public var root = #{ctx.m}Look()
    #{Enum.join(parts)}
        public init(
    #{params}
        ) {
    #{Enum.join(statements)}    }
    }
    """
    |> String.replace(
      "    public var root = #{ctx.m}Look()\n\n",
      "    public var root = #{ctx.m}Look()\n"
    )
    |> String.replace("\n    ) {\n    }\n", "\n    ) {}\n")
  end

  defp param(%{label: false} = a), do: "_ #{a.name}: #{a.type} = #{a.default}"
  defp param(a), do: "#{a.name}: #{a.type} = #{a.default}"

  defp condition({:axis, axis, name}, spec) do
    a = Enum.find(spec.axes, &(&1.axis == axis))
    "#{a.name} == .#{case_name(axis, name)}"
  end

  defp condition({:value, name}, _), do: "#{Swift.ident(name)} != nil"
  defp condition({:flag, name}, _), do: Swift.ident(name)
  defp condition({:with, part}, _), do: "with#{Swift.pascal(part)}"
  defp condition(state, spec), do: Enum.find(spec.states, &(&1.kind == state)).name

  # A look as `MLook(…)`, its fields in the struct's order.
  @order ~w(background foreground placeholder borderWidth borderColor outlineWidth outlineColor
            outlineOffset radius padding margin inset gap size height minHeight maxHeight
            typography weight decoration shadow opacity transition rotation stroke track)

  defp look_fields(ctx, c, layer) do
    where = "#{inspect(c.name)}#{if layer.part, do: "'s #{inspect(layer.part)}"}"

    fields =
      layer.style
      |> Enum.flat_map(fn {key, value} -> Swift.fields(ctx, key, value, where) end)
      |> Enum.reverse()
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.sort_by(&Enum.find_index(@order, fn f -> f == elem(&1, 0) end))

    Enum.map(fields, fn
      {k, {:call, head, args}} -> {"#{k}: ", head, args}
      {k, v} -> "#{k}: #{v}"
    end)
  end

  # The Looks for the view's own properties: `platform` gives the states SwiftUI
  # gives, `given` other arguments' expressions.
  defp looks_call(ctx, c, spec, given) do
    platform = Map.get(@platform, c.name, %{disabled: "!isEnabled"})

    args =
      for a <- spec.args do
        value =
          case a.kind do
            {:state, s} -> Map.get(given, a.name) || Map.get(platform, s, a.name)
            _ -> Map.get(given, a.name, a.name)
          end

        if a.label, do: "#{a.name}: #{value}", else: value
      end

    {"#{ctx.m}#{Swift.pascal(c.name)}Looks(", args}
  end

  # `let looks = MComponentLooks(…)` at `indent`, wrapped at 100 columns.
  defp let_looks(ctx, c, spec, given, indent, name \\ "let looks", tail \\ ")") do
    {head, args} = looks_call(ctx, c, spec, given)
    Swift.fill(indent, "#{name} = #{head}", args, tail) |> String.trim_leading()
  end

  # The arguments the app gives the view: not the states SwiftUI gives, nor those
  # `except` names.
  defp own(c, spec, except) do
    platform = Map.get(@platform, c.name, %{disabled: "!isEnabled"})

    Enum.reject(spec.args, fn a ->
      a.name in except or match?({:with, _}, a.kind) or
        (match?({:state, _}, a.kind) and Map.has_key?(platform, elem(a.kind, 1)))
    end)
  end

  defp uses_enabled?(c, spec) do
    platform = Map.get(@platform, c.name, %{disabled: "!isEnabled"})
    Enum.any?(spec.states, &(&1.kind == {:state, :disabled})) and platform[:disabled] != nil
  end

  defp uses_hover?(c, spec),
    do:
      Enum.any?(spec.states, &(&1.kind == {:state, :hovered})) and
        Map.get(@platform, c.name, %{})[:hovered] != nil

  defp stored(args), do: Enum.map_join(args, "", &"    public var #{&1.name}: #{&1.type}\n")
  defp assigns(args), do: Enum.map_join(args, "", &"        self.#{&1.name} = #{&1.name}\n")
  defp params(args, extra \\ []), do: Enum.map(args, &param/1) ++ extra

  defp env(c, spec) do
    if(uses_enabled?(c, spec),
      do: "    @Environment(\\.isEnabled) private var isEnabled\n",
      else: ""
    ) <>
      if uses_hover?(c, spec), do: "    @State private var hovered = false\n", else: ""
  end

  defp hover(c, spec),
    do: if(uses_hover?(c, spec), do: "\n            .onHover { hovered = $0 }", else: "")

  # ------------------------------------------------------------ the kinds

  defp kind(ctx, design, %{name: :button} = c, spec) do
    m = ctx.m
    type = "#{m}ButtonStyle"
    icon = Enum.find(c.parts, &(&1.name == :icon))
    label? = Enum.any?(c.parts, &(&1.name == :label))
    spinner = Enum.find(c.parts, &(&1.component == :spinner))
    loading? = Enum.any?(spec.states, &(&1.kind == {:state, :loading}))
    with_icon? = Enum.any?(spec.args, &(&1.kind == {:with, :icon}))

    icon_arg =
      case icon do
        nil -> []
        %{position: nil} -> [%{name: "icon", type: "Bool", default: "false", label: true}]
        _ -> [%{name: "icon", type: "#{m}Side?", default: "nil", label: true}]
      end

    args = own(c, spec, []) ++ icon_arg
    given = if with_icon?, do: %{"withIcon" => icon_given(icon)}, else: %{}

    spinner_view =
      case {spinner, loading?} do
        {nil, _} ->
          ""

        {part, true} ->
          style = spinner_style(ctx, design, part, "looks.#{Swift.ident(part.name)}")

          "            .overlay {\n                if style.loading {\n" <>
            "                    ProgressView().progressViewStyle(\n" <>
            "                        #{style})\n" <>
            "                }\n            }\n"

        {part, false} ->
          style = spinner_style(ctx, design, part, "looks.#{Swift.ident(part.name)}")
          "            .overlay { ProgressView().progressViewStyle(#{style}) }\n"
      end

    label_part = if label?, do: "looks.label", else: "#{m}Look()"
    icon_part = if icon, do: "looks.icon", else: "#{m}Look()"

    content =
      if icon do
        cond_expr = if icon.position, do: "let side = style.icon", else: "style.icon"
        side = if icon.position, do: "side", else: ".#{icon.position || :start}"

        """
            @ViewBuilder private func content(_ looks: #{m}ButtonLooks) -> some View {
                if #{cond_expr} {
                    configuration.label.labelStyle(
                        #{m}ButtonLabelStyle(
                            label: #{label_part}, icon: #{icon_part}, gap: looks.root.gap, side: #{side}))
                } else {
                    configuration.label.#{ctx.lower}Look(#{label_part})
                }
            }
        """
      else
        """
            private func content(_ looks: #{m}ButtonLooks) -> some View {
                configuration.label.#{ctx.lower}Look(#{label_part})
            }
        """
      end

    label_style =
      if icon do
        """

        /// A `Label` in a button with an icon: the icon at its side of the title, the
        /// gap between them.
        private struct #{m}ButtonLabelStyle: LabelStyle {
            var label: #{m}Look
            var icon: #{m}Look
            var gap: CGFloat?
            var side: #{m}Side

            func makeBody(configuration: Configuration) -> some View {
                HStack(spacing: gap ?? 0) {
                    if side == .start { configuration.icon.#{ctx.lower}Look(icon) }
                    configuration.title.#{ctx.lower}Look(label)
                    if side == .end { configuration.icon.#{ctx.lower}Look(icon) }
                }
            }
        }
        """
      else
        ""
      end

    """
    /// #{String.capitalize(article(c.name))}'s look as a `ButtonStyle`:
    /// `Button("Save", action: save).buttonStyle(.#{ctx.lower}(#{example(spec)}))`. The action stays
    /// with the `Button`; pressed comes from it, disabled from `.disabled(_:)`.
    public struct #{type}: ButtonStyle {
    #{stored(args)}
        public init(
    #{wrap(params(args), "        ", ",")}
        ) {
    #{assigns(args)}    }

        public func makeBody(configuration: Configuration) -> some View {
            #{m}ButtonBody(style: self, configuration: configuration)
        }
    }

    extension ButtonStyle where Self == #{type} {
        /// #{String.capitalize(article(c.name))}'s look.
        public static func #{ctx.lower}(
    #{wrap(params(args), "        ", ",")}
        ) -> #{type} {
    #{Swift.fill("        ", "#{type}(", forward(args), ")")}
        }
    }

    private struct #{m}ButtonBody: View {
        var style: #{type}
        var configuration: ButtonStyleConfiguration
    #{env(c, spec)}
        var body: some View {
            #{let_looks(ctx, c, spec, prefixed(args, "style.", given), "        ")}
            content(looks)
    #{spinner_view}            .#{ctx.lower}Text(looks.root)
                .#{ctx.lower}Box(looks.root)#{hover(c, spec)}
                .animation(looks.root.transition?.animation, value: looks)
        }

    #{content}}
    #{label_style}
    """
  end

  defp kind(ctx, _design, %{name: :spinner} = c, spec) do
    m = ctx.m
    type = "#{m}SpinnerStyle"
    progress? = Enum.any?(c.values, &(&1.name == :progress))
    args = own(c, spec, ["progress"])
    given = if progress?, do: %{"progress" => "progress"}, else: %{}

    progress =
      if progress?,
        do: """
                let progress = configuration.fractionCompleted.map { min(max($0 * 100, 0), 100) }
        """,
        else: "        let progress: Double? = nil\n"

    """
    /// #{String.capitalize(article(c.name))}'s look as a `ProgressViewStyle`:
    /// `ProgressView().progressViewStyle(.#{ctx.lower}(#{example(spec)}))`. Without a value it turns;
    /// with one (`ProgressView(value: 0.4)`) it also draws the value from the top.
    public struct #{type}: ProgressViewStyle {
    #{stored(args)}    /// A component's changes to it, as its part.
        var look = #{m}Look()

        public init(
    #{wrap(params(args), "        ", ",")}
        ) {
    #{assigns(args)}    }

        init(
    #{wrap(params(args, ["look: #{m}Look"]), "        ", ",")}
        ) {
    #{assigns(args)}        self.look = look
        }

        public func makeBody(configuration: Configuration) -> some View {
            #{m}SpinnerBody(style: self, configuration: configuration)
        }
    }

    extension ProgressViewStyle where Self == #{type} {
        /// #{String.capitalize(article(c.name))}'s look.
        public static func #{ctx.lower}(
    #{wrap(params(args), "        ", ",")}
        ) -> #{type} {
    #{Swift.fill("        ", "#{type}(", forward(args), ")")}
        }
    }

    private struct #{m}SpinnerBody: View {
        var style: #{type}
        var configuration: ProgressViewStyleConfiguration
    #{env(c, spec)}
        var body: some View {
    #{progress}        #{let_looks(ctx, c, spec, prefixed(args, "style.", given), "        ", "var look", ").root")}
            look.apply(style.look)
            return #{m}Ring(look: look, progress: progress)
                .#{ctx.lower}Text(look)
                .#{ctx.lower}Box(look)
                .accessibilityRepresentation {
                    ProgressView(configuration).progressViewStyle(.automatic)
                }
        }
    }

    /// The spinner's ring, turning once per its rotation: without a value a quarter of
    /// it, at a quarter's opacity around; with one, the track and the value's arc from
    /// the top, in the look's stroke.
    private struct #{m}Ring: View {
        var look: #{m}Look
        var progress: Double?

        var body: some View {
            TimelineView(.animation(paused: look.rotation == nil)) { context in
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    ring(side: side)
                        .rotationEffect(.degrees(turn(at: context.date) * 360))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }

        @ViewBuilder private func ring(side: CGFloat) -> some View {
            if let progress {
                let width = look.stroke?.width(in: side) ?? side / 6
                ZStack {
                    Circle().inset(by: width / 2).stroke(look.track ?? .clear, lineWidth: width)
                    if progress > 0 {
                        Circle().inset(by: width / 2).trim(from: 0, to: progress / 100)
                            .stroke(.foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
            } else {
                // The web's image: a ring of 10 in a box of 24, 4 wide.
                let width = side / 6
                ZStack {
                    Circle().inset(by: width / 2).stroke(.foreground, lineWidth: width).opacity(0.25)
                    Circle().inset(by: width / 2).trim(from: 0.75, to: 1)
                        .stroke(.foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
        }

        private func turn(at date: Date) -> Double {
            guard let rotation = look.rotation, rotation.duration > 0 else { return 0 }
            let turns = date.timeIntervalSinceReferenceDate / rotation.duration
            return rotation.curve.value(at: turns - turns.rounded(.down))
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :checkbox} = c, spec) do
    m = ctx.m
    type = "#{m}CheckboxStyle"
    args = own(c, spec, [])

    """
    /// #{String.capitalize(article(c.name))}'s look as a `ToggleStyle`:
    /// `Toggle("Remember me", isOn: $remember).toggleStyle(.#{ctx.lower}())`. The box is
    /// checked while the toggle is on, its label beside it.
    public struct #{type}: ToggleStyle {
    #{stored(args)}
        public init(
    #{wrap(params(args), "        ", ",")}
        ) {
    #{assigns(args)}    }

        public func makeBody(configuration: Configuration) -> some View {
            #{m}CheckboxBody(style: self, configuration: configuration)
        }
    }

    extension ToggleStyle where Self == #{type} {
        /// #{String.capitalize(article(c.name))}'s look.
        public static func #{ctx.lower}(
    #{wrap(params(args), "        ", ",")}
        ) -> #{type} {
    #{Swift.fill("        ", "#{type}(", forward(args), ")")}
        }
    }

    private struct #{m}CheckboxBody: View {
        var style: #{type}
        var configuration: ToggleStyleConfiguration
    #{env(c, spec)}
        var body: some View {
            #{let_looks(ctx, c, spec, prefixed(args, "style.", %{}), "        ")}
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack {
                    Color.clear
                        .overlay {
                            if configuration.isOn {
                                #{m}CheckMark().stroke(.foreground, style: #{m}CheckMark.line)
                            }
                        }
                        .#{ctx.lower}Text(looks.root)
                        .#{ctx.lower}Box(looks.root)#{hover(c, spec)}
                        .animation(looks.root.transition?.animation, value: looks)
                    configuration.label
                }
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        }
    }

    /// The web's check mark: a tick in a box of 16, 2 wide with round ends.
    private struct #{m}CheckMark: Shape {
        static let line = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

        func path(in rect: CGRect) -> Path {
            let unit = min(rect.width, rect.height) / 16
            let point = { (x: CGFloat, y: CGFloat) in
                CGPoint(x: rect.midX + (x - 8) * unit, y: rect.midY + (y - 8) * unit)
            }
            var path = Path()
            path.move(to: point(4.5, 8.5))
            path.addLine(to: point(6.5, 10.5))
            path.addLine(to: point(11.5, 5.5))
            return path
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: k} = c, spec) when k in [:text_field, :text_area] do
    m = ctx.m
    pascal = Swift.pascal(k)
    type = "#{m}#{pascal}Modifier"
    args = own(c, spec, [])
    on = if k == :text_field, do: "TextField", else: "TextEditor"
    hidden = if k == :text_area, do: "\n            .scrollContentBackground(.hidden)", else: ""

    """
    /// #{String.capitalize(article(c.name))}'s look on a `#{on}`:
    /// `#{on}(…).#{ctx.lower}#{pascal}(#{example(spec)})`. Disabled comes from
    /// `.disabled(_:)`; the app gives focused from its `@FocusState`.
    public struct #{type}: ViewModifier {
    #{stored(args)}#{env(c, spec)}
        public init(
    #{wrap(params(args), "        ", ",")}
        ) {
    #{assigns(args)}    }

        public func body(content: Content) -> some View {
            #{let_looks(ctx, c, spec, %{}, "        ")}
            content#{hidden}
                .#{ctx.lower}Text(looks.root)
                .frame(maxWidth: .infinity, alignment: .leading)
                .#{ctx.lower}Box(looks.root)
                .animation(looks.root.transition?.animation, value: looks)
        }

        /// A prompt in the placeholder's color of `looks`, for the `#{on}`'s `prompt:`.
        public static func prompt(
            _ text: Text, looks: #{m}#{pascal}Looks = #{m}#{pascal}Looks()
        ) -> Text {
            looks.root.placeholder.map { text.foregroundStyle($0) } ?? text
        }
    }

    extension View {
        /// #{String.capitalize(article(c.name))}'s look.
        public func #{ctx.lower}#{pascal}(
    #{wrap(params(args), "        ", ",")}
        ) -> some View {
    #{Swift.fill("        ", "modifier(#{type}(", forward(args), "))")}
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :field} = c, spec) do
    m = ctx.m
    parts = for p <- c.parts, do: p.name
    slots = for p <- [:label, :error_message], p in parts, do: p
    args = own(c, spec, [])

    slot_args =
      for p <- slots, do: %{name: Swift.ident(p), type: "Text?", default: "nil", label: true}

    given = Map.new(slots, &{"with#{Swift.pascal(&1)}", "#{Swift.ident(&1)} != nil"})

    rows =
      Enum.map_join(parts, "", fn p ->
        "            if let #{Swift.ident(p)} { #{Swift.ident(p)}.#{ctx.lower}Look(looks.#{Swift.ident(p)}) }\n"
      end)

    [before, after_] = split_rows(rows, parts, :label)

    """
    /// #{String.capitalize(article(c.name))}: its label and error message around a control.
    /// `#{m}Field(label: Text("Email"), errorMessage: error.map(Text.init)) { TextField(…) }`
    public struct #{m}Field<Content: View>: View {
    #{stored(args ++ slot_args)}    var content: Content
    #{env(c, spec)}
        public init(
    #{wrap(params(args ++ slot_args, ["@ViewBuilder content: () -> Content"]), "        ", ",")}
        ) {
    #{assigns(args ++ slot_args)}        self.content = content()
        }

        public var body: some View {
            #{let_looks(ctx, c, spec, given, "        ")}
            VStack(alignment: .leading, spacing: 0) {
    #{before}            content
    #{after_}        }
            .#{ctx.lower}Look(looks.root)
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :radio_group} = c, spec) do
    m = ctx.m
    args = own(c, spec, [])

    """
    /// #{String.capitalize(article(c.name))}: its radios in a row.
    /// `#{m}RadioGroup { #{m}Radio(checked: true) { Text("Yes") } }`
    public struct #{m}RadioGroup<Content: View>: View {
    #{stored(args)}    var content: Content
    #{env(c, spec)}
        public init(
    #{wrap(params(args, ["@ViewBuilder content: () -> Content"]), "        ", ",")}
        ) {
    #{assigns(args)}        self.content = content()
        }

        public var body: some View {
            #{let_looks(ctx, c, spec, %{}, "        ")}
            HStack(spacing: looks.root.gap) {
                content
            }
            .#{ctx.lower}Look(looks.root)
            .accessibilityElement(children: .contain)
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :radio} = c, spec) do
    m = ctx.m
    args = own(c, spec, [])
    control? = Enum.any?(c.parts, &(&1.name == :control))
    label? = Enum.any?(c.parts, &(&1.name == :label))
    checked = Enum.find(args, &(&1.kind == {:part_state, :control, :checked}))

    control =
      if control?,
        do: "            Color.clear.#{ctx.lower}Box(looks.control)\n",
        else: ""

    label = if label?, do: "label.#{ctx.lower}Look(looks.label)", else: "label"

    selected =
      if checked,
        do: "\n        .accessibilityAddTraits(#{checked.name} ? .isSelected : [])",
        else: ""

    """
    /// #{String.capitalize(article(c.name))}: its control and its label in a row. It looks
    /// checked while the app says so; the app makes the choice, in a `Button` around it.
    /// `#{m}Radio(checked: choice == .yes) { Text("Yes") }`
    public struct #{m}Radio<Label: View>: View {
    #{stored(args)}    var label: Label
    #{env(c, spec)}
        public init(
    #{wrap(params(args, ["@ViewBuilder label: () -> Label"]), "        ", ",")}
        ) {
    #{assigns(args)}        self.label = label()
        }

        public var body: some View {
            #{let_looks(ctx, c, spec, %{}, "        ")}
            HStack(spacing: looks.root.gap) {
    #{control}            #{label}
            }
            .#{ctx.lower}Look(looks.root)
            .animation(looks.control.transition?.animation, value: looks)
            .accessibilityElement(children: .combine)#{selected}
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: :select} = c, spec) do
    m = ctx.m
    parts = for p <- c.parts, do: p.name
    icon? = :icon in parts
    field = if :field in parts, do: "looks.field", else: "#{m}Look()"
    # The system draws the list, so the list's and the options' states aren't the view's.
    listed =
      for a <- spec.states,
          match?({:part_state, p, _} when p in [:listbox, :option], a.kind),
          do: a.name

    args = own(c, spec, listed)
    slot = if icon?, do: [%{name: "icon", type: "Image?", default: "nil", label: true}], else: []
    given = Map.new(listed, &{&1, "false"})
    given = if icon?, do: Map.put(given, "withIcon", "icon != nil"), else: given

    icon =
      if icon?,
        do: """
                        .overlay(alignment: looks.icon.inset.alignment) {
                            if let icon {
                                icon.#{ctx.lower}Look(looks.icon)
                                    .foregroundStyle(looks.root.foreground ?? Color.primary)
                                    .padding(looks.icon.inset.edgeInsets())
                            }
                        }
        """,
        else: ""

    """
    /// #{String.capitalize(article(c.name))}: a `Menu` whose label has the field's look; its
    /// list is the system's menu.
    /// `#{m}Select(icon: Image(systemName: "chevron.down")) { Picker(…) } label: { Text(choice) }`
    public struct #{m}Select<Label: View, Content: View>: View {
    #{stored(args ++ slot)}    var content: Content
        var label: Label
    #{env(c, spec)}
        public init(
    #{wrap(params(args ++ slot, ["@ViewBuilder content: () -> Content", "@ViewBuilder label: () -> Label"]), "        ", ",")}
        ) {
    #{assigns(args ++ slot)}        self.content = content()
            self.label = label()
        }

        public var body: some View {
            #{let_looks(ctx, c, spec, given, "        ")}
            Menu {
                content
            } label: {
                label
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .#{ctx.lower}Look(#{field})
    #{icon}        }
            .menuIndicator(.hidden)
            .#{ctx.lower}Look(looks.root)
        }
    }
    """
  end

  defp kind(ctx, _design, %{name: k} = c, spec) when k in [:tag, :message_bar, :step_indicator] do
    m = ctx.m
    pascal = Swift.pascal(k)
    args = own(c, spec, [])
    label? = k == :tag and Enum.any?(c.parts, &(&1.name == :label))

    content =
      case k do
        :tag when label? -> "content.#{ctx.lower}Look(looks.label)"
        :message_bar -> "content.multilineTextAlignment(.center).frame(maxWidth: .infinity)"
        :step_indicator -> "content.monospacedDigit()"
        _ -> "content"
      end

    doc =
      case k do
        :tag -> "a label on a colored background"
        :message_bar -> "a line of text on a colored band, as wide as it is given"
        :step_indicator -> "the numbered circle of one step"
      end

    """
    /// #{String.capitalize(article(c.name))}: #{doc}.
    /// `#{m}#{pascal}(#{example(spec)}) { Text("…") }`
    public struct #{m}#{pascal}<Content: View>: View {
    #{stored(args)}    var content: Content
    #{env(c, spec)}
        public init(
    #{wrap(params(args, ["@ViewBuilder content: () -> Content"]), "        ", ",")}
        ) {
    #{assigns(args)}        self.content = content()
        }

        public var body: some View {
            #{let_looks(ctx, c, spec, %{}, "        ")}
            #{content}
                .#{ctx.lower}Look(looks.root)
        }
    }
    """
  end

  # ------------------------------------------------------------ helpers

  defp icon_given(nil), do: "false"
  defp icon_given(%{position: nil}), do: "style.icon"
  defp icon_given(_), do: "style.icon != nil"

  # The spinner style a part draws, with the variants it picks.
  defp spinner_style(ctx, design, part, look) do
    spinner = Enum.find(design.components, &(&1.name == :spinner))

    picks =
      for {axis, default} <- axes(spinner) do
        picked = Keyword.get(part.variants, axis, default)
        value = if picked, do: "." <> case_name(axis, picked), else: "nil"
        if axis == :variant, do: value, else: "#{Swift.ident(axis)}: #{value}"
      end

    "#{ctx.m}SpinnerStyle(#{Enum.join(picks ++ ["look: #{look}"], ", ")})"
  end

  defp prefixed(args, prefix, given) do
    Enum.reduce(args, given, fn a, acc -> Map.put_new(acc, a.name, prefix <> a.name) end)
  end

  defp forward(args) do
    Enum.map(args, fn
      %{label: false} = a -> a.name
      a -> "#{a.name}: #{a.name}"
    end)
  end

  defp example(spec) do
    spec.axes
    |> Enum.filter(&(&1.cases != []))
    |> Enum.take(1)
    |> Enum.map_join(fn a ->
      value = "." <> Enum.at(a.cases, -1)
      if a.label, do: "#{a.name}: #{value}", else: value
    end)
  end

  defp split_rows(rows, parts, first) do
    lines = String.split(rows, "\n", trim: true) |> Enum.map(&(&1 <> "\n"))
    {before, after_} = Enum.split_with(Enum.zip(parts, lines), fn {p, _} -> p == first end)
    [Enum.map_join(before, &elem(&1, 1)), Enum.map_join(after_, &elem(&1, 1))]
  end

  # Arguments one per line, `indent` before each, `sep` after all but the last.
  defp wrap([], _indent, _sep), do: ""
  defp wrap(items, indent, sep), do: Enum.map_join(items, sep <> "\n", &(indent <> &1))

  defp words(name), do: name |> to_string() |> String.replace("_", " ")

  defp article(name) do
    w = words(name)
    if String.first(w) in ~w(a e i o u), do: "an #{w}", else: "a #{w}"
  end
end
