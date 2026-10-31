defmodule Prism.Generator.Schema.ComponentsTest do
  use ExUnit.Case, async: true

  # Tokens for the components below; the component body starts on line 12.
  @tokens """
    web prefix: "t", fonts_url: "f"
    color :ink, "#101010"
    shadow :card, y: 5, blur: 20, color: {:ink, 0.1}
    radius :round, 4
    max_height :menu, 100
    family :f, doc: "F", web: [name: "F", fallback: "serif", faces: [[file: "F", weights: {200, 900}, style: :normal]]], ios: :system, android: :system
    font :b, :f, 700
    text :t, 16, 20
    typography :body, font: :b, text: :t
  """

  defp compile(body, tokens \\ @tokens) do
    module = "Design#{System.unique_integer([:positive])}"

    [{mod, _}] =
      Code.compile_string(
        "defmodule #{module} do\n  use Prism.Generator.Schema\n#{tokens}#{body}\nend\n",
        "design.ex"
      )

    mod.__schema__()
  end

  defp assert_compile_error(body, message, line) do
    error = assert_raise CompileError, fn -> compile(body) end
    assert Exception.message(error) =~ message
    assert error.line == line
  end

  test "the example design's component compiles into plain data" do
    [tag] = Prism.Generator.ExampleDesign.__schema__().components

    assert %{
             name: :tag,
             style: [radius: :default, background: :paper],
             parts: [%{name: :label, component: nil, states: [], web: [], ios: []}],
             axes: [%{name: :size, web: [doc: "Sizes"], ios: [], android: []}],
             with_parts: [],
             states: [%{name: :disabled, style: [opacity: 0.4], parts: [%{name: :label}]}],
             web: [section: "Tags", radius: 2],
             ios: [radius: 6],
             android: []
           } = tag

    assert [
             %{
               name: :accent,
               axis: :variant,
               aliases: [],
               style: [],
               web: [doc: "An accent tag"]
             },
             %{name: :muted, axis: :variant, aliases: [:quiet]},
             %{name: :large, axis: :size, style: [padding: [x: 4]]}
           ] = tag.variants

    assert [%{name: :label, style: [background: {:accent, 0.2}, foreground: :link]}] =
             hd(tag.variants).parts
  end

  test "a component without a block, and a look from a module attribute" do
    [c] =
      compile("  @look [radius: :round]\n  component :c do\n    style @look\n  end").components

    assert c.style == [radius: :round]
    assert [%{name: :d}] = compile("  component :d").components
  end

  test "a name that isn't a snake_case atom fails" do
    assert_compile_error("  component :Tag", "component :Tag: name must be a snake_case atom", 12)

    assert_compile_error(
      "  component :c do\n    variant \"v\"\n  end",
      "variant \"v\": name must be a snake_case atom",
      13
    )
  end

  test "a component is defined once" do
    assert_compile_error(
      "  component :c\n  component :c",
      "component :c is defined twice",
      13
    )
  end

  test "an unknown property fails on its line and names it" do
    assert_compile_error(
      "  component :c do\n    variant :v, colour: :ink\n  end",
      "component :c, variant :v: unknown option :colour",
      13
    )

    assert_compile_error(
      "  component :c do\n    style padding: [y: 1], radus: :round\n  end",
      "component :c, style: unknown option :radus",
      13
    )
  end

  # The node's own fields come from the macro, never from its options.
  test "an option can't replace a node's name, kind, group or line" do
    for key <- [:name, :kind, :group, :line, :style, :parts, :variants, :states, :axis] do
      assert_compile_error(
        "  component :c, #{key}: :x",
        "component :c: unknown option #{inspect(key)}",
        12
      )

      assert_compile_error(
        "  component :c do\n    variant :v, #{key}: :x\n  end",
        "component :c, variant :v: unknown option #{inspect(key)}",
        13
      )

      # A part's `variants:` is its own option: the variants of the component it is.
      if key != :variants,
        do:
          assert_compile_error(
            "  component :c do\n    part :p, #{key}: :x\n  end",
            "component :c, part :p: unknown option #{inspect(key)}",
            13
          )

      assert_compile_error(
        "  component :c do\n    state :pressed, #{key}: :x\n  end",
        "component :c, state :pressed: unknown option #{inspect(key)}",
        13
      )

      assert_compile_error(
        "  component :c do\n    variants :a, #{key}: :x do\n      variant :v\n    end\n  end",
        "component :c, variants :a: unknown option #{inspect(key)}",
        13
      )
    end
  end

  test "a property is given once" do
    assert_compile_error(
      "  component :c do\n    variant :v, opacity: 0.5, opacity: 0.4\n  end",
      "option :opacity is given twice",
      13
    )
  end

  test "values are checked against their type and the tokens" do
    cases = [
      {"background: :nope", "background: unknown color :nope"},
      {"background: \"#abcdef\"", "write colors as #RRGGBB"},
      {"background: {:ink, 2}", "is not a number from 0 to 1"},
      {"radius: :card", "radius: unknown radius :card"},
      {"shadow: :round", "shadow: unknown shadow :round"},
      {"max_height: :nope", "max_height: unknown max_height :nope"},
      {"padding: [x: 1, left: 2]", "a side is given twice"},
      {"padding: [middle: 1]", "unknown side :middle"},
      {"padding: [x: -1]", "every side is a length"},
      {"gap: \"4px\"", "is not a length"},
      {"border: [width: 1, style: :dashed]", "is not a keyword list of width:, color:"},
      {"border: [color: :nope]", "unknown color :nope"},
      {"outline: [offset: :x]", "must be lengths"},
      {"typography: :nope", "unknown typography :nope"},
      {"typography: [font: :b]", "is not a typography token or [font: font, text: text]"},
      {"typography: [font: :t, text: :t]", "unknown font :t"},
      {"typography: [font: :b, text: {0, 1}]", "is not a text size or {size, line_height}"},
      {"weight: 450", "450 is not one of 100, 200, …, 1000"},
      {"decoration: :overline", "is not :underline or :none"},
      {"opacity: 1.5", "1.5 is not a number from 0 to 1"},
      {"transition: {150, :bounce}", "is not {milliseconds, easing}"}
    ]

    for {property, message} <- cases do
      assert_compile_error("  component :c do\n    variant :v, #{property}\n  end", message, 13)
    end
  end

  test "literals: :transparent, #RRGGBB, {color, alpha}, lengths and typography pairs" do
    [c] =
      compile("""
        component :c do
          style background: :transparent, foreground: "#666666", radius: {50, :percent}
          variant :v, background: {:ink, 0.2}, typography: [font: :b, text: {12, 12}]
        end
      """).components

    assert c.style == [background: :transparent, foreground: "#666666", radius: {50, :percent}]
  end

  test "a color token can't be named :transparent, which components use for no color" do
    assert_compile_error(~s(  color :transparent, "#000000"), "the name is taken", 12)
  end

  test "each node goes in its place" do
    cases = [
      {"  variant :v", "variant :v can't be declared outside a component", 12},
      {"  state :pressed", "state :pressed can't be declared outside a component", 12},
      {"  component :c do\n    component :d\n  end",
       "component :d can't be declared inside component :c", 13},
      {"  component :c do\n    part :p do\n      part :q\n    end\n  end",
       "part :q can't be declared inside part :p", 14},
      {"  component :c do\n    state :pressed do\n      state :focused\n    end\n  end",
       "state :focused can't be declared inside state :pressed", 14},
      {"  component :c do\n    part :p\n    state :pressed do\n      part :p do\n        state :focused\n      end\n    end\n  end",
       "state :focused can't be declared inside part :p", 16},
      {"  component :c do\n    part :p\n    part :q do\n      state :checked do\n        part :p, opacity: 0\n      end\n    end\n  end",
       "part :p can't be declared inside state :checked: a part's state changes only that part; a state of the component changes others",
       16},
      {"  component :c do\n    variant :v do\n      style opacity: 1\n    end\n  end",
       "style can't be declared inside variant :v", 14},
      {"  component :c do\n    variant :v do\n      variant :w\n    end\n  end",
       "variant :w can't be declared inside variant :v", 14},
      {"  component :c do\n    color :x, \"#000000\"\n  end",
       "color :x inside component :c: it goes at the top of the design", 13},
      {"  component :c do\n    web prefix: \"x\"\n  end", "web inside component :c", 13},
      {"  group \"G\" do\n    component :c\n  end",
       "component :c inside group \"G\": groups are for tokens", 13}
    ]

    for {body, message, line} <- cases, do: assert_compile_error(body, message, line)
  end

  test "style is given once" do
    assert_compile_error(
      "  component :c do\n    style opacity: 1\n    style opacity: 0\n  end",
      "component :c: style is given twice",
      14
    )
  end

  test "states have a fixed meaning" do
    assert_compile_error(
      "  component :c do\n    state :presed\n  end",
      "state :presed: unknown state; the states are :pressed, :hovered",
      13
    )

    assert Keyword.keys(Prism.Generator.Schema.Components.states()) ==
             [:pressed, :hovered, :focused, :disabled, :checked, :selected, :loading, :invalid]
  end

  test "variants, aliases, parts, flags and states of a component share one set of names" do
    assert_compile_error(
      "  component :c do\n    part :x\n    state :pressed\n    flag :pressed\n  end",
      "component :c: :pressed is both a state and a flag",
      12
    )

    assert_compile_error(
      "  component :c do\n    part :x\n    flag :x\n  end",
      "component :c: :x is both a part and a flag",
      12
    )

    assert_compile_error(
      "  component :c do\n    variant :x\n    flag :x\n  end",
      "component :c: :x is both a variant and a flag",
      12
    )

    assert_compile_error(
      "  component :c do\n    variant :x\n    variant :y, aliases: [:x]\n  end",
      ":x is both a variant and a variant alias",
      12
    )

    assert_compile_error(
      "  component :c do\n    variant :x\n    variant :x\n  end",
      ":x is both a variant and a variant",
      12
    )
  end

  # Their classes can't be confused: `__icon` and `--icon`.
  test "a variant may have the name of a part" do
    [c] =
      compile("  component :c do\n    part :icon\n    variant :icon, size: 24\n  end").components

    assert [%{name: :icon}] = c.parts
    assert [%{name: :icon, style: [size: 24]}] = c.variants
  end

  test "a variant or state changes only a part the component declares" do
    assert_compile_error(
      "  component :c do\n    variant :v do\n      part :p, opacity: 0\n    end\n  end",
      "component :c, variant :v, part :p: component :c has no part :p",
      14
    )
  end

  describe "a look with a variant" do
    test "is the look with a variant of another axis, in a variant or a flag" do
      [c] =
        compile("""
          component :c do
            variant :solid, background: :ink
            variant :outlined, aliases: [:framed]

            variants :tone do
              variant :alert do
                with_variant :solid, background: :ink, web: [doc: "Alert"]

                with_variant [:outlined], border: [color: :ink] do
                  state :pressed, opacity: 0.5
                end
              end
            end

            flag :tight, default: true do
              with_variant [:solid, :alert], padding: [x: 1]
            end
          end
        """).components

      alert = Enum.find(c.variants, &(&1.name == :alert))

      assert [
               %{name: :solid, style: [background: :ink], states: [], web: [doc: "Alert"]},
               %{name: :outlined, style: [border: [color: :ink]], states: [%{name: :pressed}]}
             ] = alert.with_variants

      assert Enum.find(c.variants, &(&1.name == :solid)).with_variants == []

      assert [%{name: :tight, default: true, style: [], with_variants: [solid, tone]}] = c.flags
      assert {solid.name, tone.name} == {:solid, :alert}
    end

    test "names a variant of another axis, once, by its name" do
      assert_compile_error(
        "  component :c do\n    variant :a\n    variant :b do\n      with_variant :a\n    end\n  end",
        "with_variant :a: :a is a variant of the same axis, :variant",
        15
      )

      assert_compile_error(
        "  component :c do\n    variant :a, aliases: [:x]\n    variants :tone do\n      variant :t do\n        with_variant :x\n      end\n    end\n  end",
        ":x is an alias of :a; name the variant",
        16
      )

      assert_compile_error(
        "  component :c do\n    flag :f do\n      with_variant :nope\n    end\n  end",
        "component :c, flag :f, with_variant :nope: the component has no variant :nope",
        14
      )

      assert_compile_error(
        "  component :c do\n    variant :a\n    flag :f do\n      with_variant [:a, :a]\n    end\n  end",
        "component :c, flag :f: :a is both a look with a variant and a look with a variant",
        14
      )

      assert_compile_error(
        "  component :c do\n    flag :f do\n      with_variant []\n    end\n  end",
        "with_variant []: name at least one variant",
        14
      )
    end

    test "is declared only in a variant or a flag" do
      assert_compile_error(
        "  component :c do\n    variant :a\n    with_variant :a\n  end",
        "with_variant :a can't be declared inside component :c",
        14
      )
    end
  end

  describe "a flag" do
    test "is off by default, or on with default: true" do
      [c] = compile("  component :c do\n    flag :f, opacity: 0.5\n  end").components
      assert [%{name: :f, default: false, style: [opacity: 0.5], with_variants: []}] = c.flags

      assert_compile_error(
        "  component :c do\n    flag :f, default: :yes\n  end",
        "component :c, flag :f: default: must be true or false",
        13
      )
    end
  end

  describe "a part's position" do
    test "is the side of the content the part has when the app picks none" do
      [c] = compile("  component :c do\n    part :icon, position: :end\n  end").components
      assert [%{name: :icon, position: :end}] = c.parts

      [c] = compile("  component :c do\n    part :icon\n  end").components
      assert [%{name: :icon, position: nil}] = c.parts
    end

    test "is :start or :end, on a part the app fills" do
      assert_compile_error(
        "  component :c do\n    part :icon, position: :left\n  end",
        "position: :left is not :start or :end",
        13
      )

      assert_compile_error(
        "  component :s\n  component :c do\n    part :spinner, component: :s, position: :end\n  end",
        "position: is for a part the app fills, not another component",
        14
      )
    end
  end

  describe "a look with a part" do
    test "is the look while the component has the part, in the component or a variant" do
      [c] =
        compile("""
          component :c do
            part :icon
            with_part :icon, padding: [x: 4], web: [doc: "With an icon"]

            variant :v do
              with_part :icon, gap: 12 do
                state :pressed, padding: [top: 5]
              end
            end
          end
        """).components

      assert [%{name: :with_icon, part: :icon, style: [padding: [x: 4]], states: []} = own] =
               c.with_parts

      assert own.web == [doc: "With an icon"]

      assert [%{name: :with_icon, part: :icon, style: [gap: 12], states: [pressed]}] =
               hd(c.variants).with_parts

      assert %{name: :pressed, style: [padding: [top: 5]], parts: []} = pressed
    end

    test "names a part the component declares, once" do
      assert_compile_error(
        "  component :c do\n    variant :v do\n      with_part :icon, gap: 4\n    end\n  end",
        "component :c, variant :v, with_part :icon: component :c has no part :icon",
        14
      )

      assert_compile_error(
        "  component :c do\n    part :icon\n    with_part :icon\n    with_part :icon\n  end",
        "component :c: :icon is both a look with a part and a look with a part",
        12
      )
    end

    test "its class name is taken: no variant may be called with_<part>" do
      assert_compile_error(
        "  component :c do\n    part :icon\n    variant :with_icon\n    with_part :icon\n  end",
        "component :c: :with_icon is both a variant and a look with a part",
        12
      )
    end

    test "holds only states" do
      assert_compile_error(
        "  component :c do\n    part :icon\n    with_part :icon do\n      part :icon, gap: 2\n    end\n  end",
        "part :icon can't be declared inside with_part :icon",
        15
      )
    end
  end

  test "a part that is a component names another component, declared anywhere" do
    [c, _] =
      compile("  component :c do\n    part :s, component: :spinner\n  end\n  component :spinner").components

    assert hd(c.parts).component == :spinner

    assert_compile_error(
      "  component :c do\n    part :s, component: :nope\n  end",
      "component: :nope is not another component",
      13
    )

    assert_compile_error(
      "  component :c do\n    part :s, component: :c\n  end",
      "component: :c is not another component",
      13
    )

    # Only a part the component declares can be one.
    assert_compile_error(
      "  component :c do\n    part :s\n    variant :v do\n      part :s, component: :d\n    end\n  end\n  component :d",
      "unknown option :component",
      15
    )
  end

  test "a part that is another component has no state the app sets, in a variant or not" do
    message =
      ": the web shows :selected with a modifier class, which a part that is another component doesn't get; give the state to :spinner or :c"

    assert_compile_error(
      "  component :c do\n    part :s, component: :spinner do\n      state :selected, opacity: 0.5\n    end\n  end\n  component :spinner",
      "component :c, part :s, state :selected" <> message,
      14
    )

    assert_compile_error(
      "  component :c do\n    part :s, component: :spinner\n    variants :size do\n      variant :v do\n        part :s do\n          state :selected, opacity: 0.5\n        end\n      end\n    end\n  end\n  component :spinner",
      "component :c, variants :size, variant :v, part :s, state :selected" <> message,
      17
    )

    assert_compile_error(
      "  component :c do\n    part :s, component: :spinner\n    variant :v do\n      part :s do\n        state :invalid\n      end\n    end\n  end\n  component :spinner",
      "component :c, variant :v, part :s, state :invalid: the web shows :invalid",
      16
    )

    # A pseudo-class state of the part is the browser's.
    [c, _] =
      compile(
        "  component :c do\n    part :s, component: :spinner\n    variant :v do\n      part :s do\n        state :hovered, opacity: 0.5\n      end\n    end\n  end\n  component :spinner"
      ).components

    assert [%{parts: [%{states: [%{name: :hovered}]}]}] = c.variants
  end

  test "axes: variants outside a block are :variant, a block names another axis" do
    assert_compile_error(
      "  component :c do\n    variants :variant do\n      variant :v\n    end\n  end",
      "variants outside a variants block are the :variant axis",
      13
    )

    assert_compile_error(
      "  component :c do\n    variants :size do\n    end\n  end",
      "component :c, variants :size has no variants",
      13
    )
  end

  describe "an axis's default" do
    test "is one of its variants, a name without a look of its own, or none" do
      %{components: [c]} =
        compile("""
          component :c, default: :plain do
            variant :plain
            variant :bold
            variants :tone, default: :accent do
              variant :danger
            end
            variants :size do
              variant :small
            end
          end
        """)

      assert c.default == :plain

      assert [%{name: :tone, default: :accent}, %{name: :size, default: nil}] = c.axes
      assert [%{default: nil}] = compile("  component :d do\n    variant :v\n  end").components
    end

    test "is a snake_case name, not an alias, and not another name of the component" do
      assert_compile_error(
        "  component :c, default: \"plain\" do\n    variant :plain\n  end",
        ~s(component :c: default: "plain" must be a snake_case atom),
        12
      )

      assert_compile_error(
        "  component :c, default: :quiet do\n    variant :muted, aliases: [:quiet]\n  end",
        "component :c: default: :quiet is an alias of :muted; name the variant",
        12
      )

      assert_compile_error(
        "  component :c do\n    variant :danger\n    variants :tone, default: :danger do\n      variant :success\n    end\n  end",
        ":danger is both a variant and a default",
        12
      )

      assert_compile_error(
        "  component :c do\n    part :label\n    variants :tone, default: :label do\n      variant :success\n    end\n  end",
        ":label is both a part and a default",
        12
      )
    end

    test "of the :variant axis needs variants outside a block" do
      assert_compile_error(
        "  component :c, default: :plain do\n    variants :tone do\n      variant :plain\n    end\n  end",
        "component :c: default: :plain is the default of the :variant axis, which has no variants",
        12
      )
    end
  end

  describe "a variant named by a number" do
    test "is a whole number above 0, as are its axis's other variants and default" do
      %{components: [c]} =
        compile("""
          component :c do
            variants :size, default: 24 do
              variant 16, size: 16
              variant 32, size: 32, aliases: [30]
            end
            variant :bold do
              with_variant 16, weight: 700
            end
          end
        """)

      assert [%{name: :size, default: 24}] = c.axes
      assert [%{name: 16, axis: :size}, %{name: 32, aliases: [30]}, %{name: :bold}] = c.variants
      assert [%{with_variants: [%{name: 16, style: [weight: 700]}]}] = Enum.drop(c.variants, 2)
    end

    test "fails as any other name: zero, negative, a float, or mixed with names" do
      for name <- ["0", "-16", "16.5"] do
        assert_compile_error(
          "  component :c do\n    variant #{name}\n  end",
          "variant #{name}: name must be a snake_case atom or a whole number above 0",
          13
        )
      end

      # Only variants: a part, state or component has a name.
      assert_compile_error(
        "  component :c do\n    part 16\n  end",
        "part 16: name must be a snake_case atom",
        13
      )

      assert_compile_error(
        "  component :c do\n    variants :size do\n      variant 16\n      variant :large\n    end\n  end",
        "component :c, variants :size, variant :large: the :size axis's variants are all names or all numbers, and 16 is a number",
        15
      )

      assert_compile_error(
        "  component :c do\n    variants :size, default: :medium do\n      variant 16\n    end\n  end",
        "component :c, variants :size: default: :medium must be a whole number above 0, as the axis's variants are",
        13
      )

      assert_compile_error(
        "  component :c do\n    variants :size, default: 24 do\n      variant :small\n    end\n  end",
        "component :c, variants :size: default: 24 must be a snake_case atom",
        13
      )

      assert_compile_error(
        "  component :c do\n    variants :size do\n      variant 16, aliases: [:small]\n    end\n  end",
        "variant 16: aliases: must be a list of whole numbers above 0, as the variant's name is",
        14
      )
    end
  end

  describe "a value" do
    test "is a number the app gives, with its look while it gives it" do
      [c] =
        compile(
          "  component :c do\n    value :progress, stroke: {16, :percent}, track: :ink, web: [doc: \"With progress\"]\n  end"
        ).components

      assert [
               %{
                 name: :progress,
                 style: [stroke: {16, :percent}, track: :ink],
                 web: [doc: "With progress"],
                 ios: [],
                 android: []
               }
             ] = c.values

      assert [%{values: []}] = compile("  component :d").components
    end

    test "is declared in a component, has no block, and shares the component's names" do
      assert_compile_error(
        "  component :c do\n    variant :v do\n      value :progress\n    end\n  end",
        "value :progress can't be declared inside variant :v",
        14
      )

      assert_compile_error(
        "  component :c do\n    value :progress, track: :nope\n  end",
        "component :c, value :progress: track: unknown color :nope",
        13
      )

      assert_compile_error(
        "  component :c do\n    value :progress, max: 10\n  end",
        "component :c, value :progress: unknown option :max",
        13
      )

      assert_compile_error(
        "  component :c do\n    state :loading\n    value :loading\n  end",
        ":loading is both a state and a value",
        12
      )

      assert_compile_error(
        "  component :c do\n    part :progress\n    value :progress\n  end",
        ":progress is both a part and a value",
        12
      )
    end
  end

  describe "a part's variants" do
    @spinner "  component :spinner do\n    variants :size, default: 24 do\n      variant 16, size: 16\n      variant 20, size: 20, aliases: [21]\n    end\n    variant :accent\n  end\n"

    test "pick the variants of the component the part is, one per axis" do
      [c, _] =
        compile(
          "  component :c do\n    part :s, component: :spinner, variants: [size: 20, variant: :accent]\n  end\n" <>
            @spinner
        ).components

      assert [%{name: :s, variants: [size: 20, variant: :accent]}] = c.parts

      assert [%{variants: []}] =
               compile("  component :d do\n    part :p\n  end").components
               |> Enum.map(&hd(&1.parts))
    end

    test "name an axis of that component and one of its variants, not an alias" do
      for {picks, message} <- [
            {"[tone: :danger]", "variants: :spinner has no axis :tone"},
            {"[size: 18]", "variants: 18 is not a variant of :spinner's :size; it has 16, 20"},
            {"[size: 21]", "variants: 21 is an alias of 20; name the variant"},
            {"[size: 16, size: 20]",
             "variants: must be a keyword list of an axis and a variant, each axis once"}
          ] do
        assert_compile_error(
          "  component :c do\n    part :s, component: :spinner, variants: #{picks}\n  end\n" <>
            @spinner,
          "component :c, part :s: " <> message,
          13
        )
      end

      assert_compile_error(
        "  component :c do\n    part :s, variants: [size: 16]\n  end",
        "component :c, part :s: variants: is for a part that is another component",
        13
      )
    end
  end

  describe "bindings" do
    test "a binding may replace a property for its target" do
      [c] =
        compile("""
          component :c, web: [radius: 2], ios: [radius: :round], android: [opacity: 0.5] do
            style radius: :round
          end
        """).components

      assert {c.style, c.web, c.ios, c.android} ==
               {[radius: :round], [radius: 2], [radius: :round], [opacity: 0.5]}
    end

    test "a binding's property is checked like the shared one" do
      assert_compile_error(
        "  component :c, ios: [radius: :nope]",
        "component :c: ios: radius: unknown radius :nope",
        12
      )
    end

    test "a key the target doesn't know fails on its line" do
      assert_compile_error(
        "  component :c, web: [cursor: :pointer]",
        "component :c: web: unknown key :cursor; the web target knows :section, :doc and the properties here",
        12
      )

      assert_compile_error(
        "  component :c do\n    part :p, web: [filter: [color: \"#FFFFFF\", value: \"x\"]]\n  end",
        "web: unknown key :filter",
        13
      )

      # The native targets don't exist yet: they know only the properties.
      assert_compile_error(
        "  component :c, ios: [haptics: :light]",
        "ios: unknown key :haptics; the ios target knows only the properties here",
        12
      )

      assert_compile_error(
        "  component :c, web: [name: :x]",
        "web: unknown key :name",
        12
      )
    end

    test "a known key's value is checked" do
      assert_compile_error(
        "  component :c, web: [doc: \"a */ b\"]",
        "web: doc: must be one line of text without */",
        12
      )
    end

    test "a binding is a keyword list, each key once" do
      assert_compile_error("  component :c, web: :x", "web: must be a keyword list", 12)

      assert_compile_error(
        "  component :c, web: [doc: \"a\", doc: \"b\"]",
        "web: :doc is given twice",
        12
      )
    end

    test "an axis binding has no properties" do
      assert_compile_error(
        "  component :c do\n    variants :a, web: [radius: 2] do\n      variant :v\n    end\n  end",
        "web: unknown key :radius",
        13
      )
    end
  end

  describe "tokens from another design" do
    test "a design can take its tokens and web declaration from another" do
      [{mod, _}] =
        Code.compile_string("""
        defmodule ComponentsOnly#{System.unique_integer([:positive])} do
          use Prism.Generator.Schema, tokens: Prism.Generator.TokensOnly
          web components_doc: "Components"
          component :tag
        end
        """)

      schema = mod.__schema__()
      assert schema.tokens == Prism.Generator.TokensOnly.__schema__().tokens
      assert schema.tokens_file == "test/support/tokens_only.ex"
      assert schema.file == "nofile"
      assert %{prefix: "only", components_doc: "Components"} = schema.web
      assert [%{name: :tag}] = schema.components
    end

    defp compile_taking(body) do
      Code.compile_string(
        "defmodule Taking#{System.unique_integer([:positive])} do\n  use Prism.Generator.Schema, tokens: Prism.Generator.TokensOnly\n#{body}\nend\n",
        "design.ex"
      )
    end

    test "it declares no tokens of its own" do
      error = assert_raise CompileError, fn -> compile_taking(~s(  color :x, "#000000")) end
      assert Exception.message(error) =~ "takes its tokens from Prism.Generator.TokensOnly"
      assert error.line == 3
    end

    test "its web declaration only adds the components doc" do
      error = assert_raise CompileError, fn -> compile_taking(~s(  web prefix: "x")) end
      assert Exception.message(error) =~ "prefix comes with the tokens"
    end

    test "it takes tokens only from a design without components" do
      error =
        assert_raise CompileError, fn ->
          Code.compile_string(
            "defmodule Taking2 do\n  use Prism.Generator.Schema, tokens: Prism.Generator.ExampleDesign\nend\n",
            "design.ex"
          )
        end

      assert Exception.message(error) =~ "has components"

      error =
        assert_raise CompileError, fn ->
          Code.compile_string(
            "defmodule Taking3 do\n  use Prism.Generator.Schema, tokens: Enum\nend\n",
            "design.ex"
          )
        end

      assert Exception.message(error) =~ "tokens: Enum is not a design"
    end
  end
end
