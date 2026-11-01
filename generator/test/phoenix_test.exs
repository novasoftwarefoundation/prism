defmodule Prism.Generator.PhoenixTest.Kit do
  use Prism.Generator.Phoenix, design: Prism.Generator.ExampleComponents
end

defmodule Prism.Generator.PhoenixTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Prism.Generator.{ExampleComponents, Web}
  alias Prism.Generator.Web.Classes
  alias Prism.Generator.PhoenixTest.Kit

  defp html(rendered), do: rendered |> rendered_to_string() |> norm()

  # Markup without the whitespace around tags, each tag's attributes sorted: their
  # order isn't part of what a component renders.
  defp norm(html) do
    html = html |> String.replace(~r/>\s+/, ">") |> String.replace(~r/\s+</, "<")

    Regex.replace(~r/<([a-z]+)((?:\s+[^\s=>\/]+(?:="[^"]*")?)*)\s*(\/?)>/, html, fn _,
                                                                                    tag,
                                                                                    attrs,
                                                                                    close ->
      attrs = ~r/[^\s=]+(?:="[^"]*")?/ |> Regex.scan(attrs) |> List.flatten() |> Enum.sort()
      "<" <> Enum.join([tag | attrs], " ") <> close <> ">"
    end)
  end

  # Compiles `body`, with the warnings as diagnostics instead of on stderr.
  defp compile(body, file \\ "nofile") do
    ExUnit.CaptureIO.with_io(:stderr, fn ->
      Code.with_diagnostics(fn -> Code.compile_string(body, file) end)
    end)
    |> elem(0)
  end

  defp kit(design_body) do
    n = System.unique_integer([:positive])

    {[_, {kit, _}], _} =
      compile("""
      defmodule PhoenixDesign#{n} do
        use Prism.Generator.Schema, tokens: Prism.Generator.TokensOnly
      #{design_body}
      end

      defmodule PhoenixKit#{n} do
        use Prism.Generator.Phoenix, design: PhoenixDesign#{n}
      end
      """)

    kit
  end

  describe "every component" do
    test "renders the element the web's CSS expects, with its defaults" do
      assigns = %{}

      assert html(~H"<Kit.button>Save</Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary"><span class="kit-button__label">Save</span></button>)
               )

      assert html(~H"<Kit.text_field />") == norm(~s(<input class="kit-text-field"/>))

      assert html(~H"<Kit.text_area value='Hi' />") ==
               norm(~s(<textarea class="kit-text-area">Hi</textarea>))

      assert html(~H"<Kit.field><:label>Name</:label>CONTROL</Kit.field>") ==
               norm(
                 ~s(<div class="kit-field"><label class="kit-field__label">Name</label>CONTROL</div>)
               )

      assert html(~H"<Kit.radio_group>RADIOS</Kit.radio_group>") ==
               norm(~s(<div role="radiogroup" class="kit-radio-group">RADIOS</div>))

      assert html(~H"<Kit.radio>One</Kit.radio>") ==
               norm(
                 ~s(<label class="kit-radio"><input type="radio" class="kit-radio__control"/><span class="kit-radio__label">One</span></label>)
               )

      assert html(~H"<Kit.select>Pick</Kit.select>") ==
               norm(
                 ~s(<div class="kit-select"><button type="button" class="kit-select__field">Pick</button></div>)
               )

      assert html(~H"<Kit.spinner />") == norm(~s(<span class="kit-spinner"></span>))
      assert html(~H"<Kit.checkbox />") == norm(~s(<input type="checkbox" class="kit-checkbox"/>))

      assert html(~H"<Kit.tag>New</Kit.tag>") ==
               norm(
                 ~s(<span class="kit-tag kit-tag--neutral"><span class="kit-tag__label">New</span></span>)
               )

      assert html(~H"<Kit.message_bar>Saved</Kit.message_bar>") ==
               norm(~s(<div class="kit-message-bar kit-message-bar--info">Saved</div>))

      assert html(~H"<Kit.step_indicator>1</Kit.step_indicator>") ==
               norm(~s(<span class="kit-step-indicator">1</span>))
    end

    test "is a function of the app's module, one per design component" do
      names = for c <- ExampleComponents.__schema__().components, do: c.name
      assert Enum.sort(Map.keys(Kit.__components__())) == Enum.sort(names)
    end
  end

  describe "axes" do
    test "each is an atom attribute with the design's values, and the design's default" do
      components = Kit.__components__()
      attr = fn component, name -> Enum.find(components[component].attrs, &(&1.name == name)) end

      # The :variant axis's default is one of its variants; aliases are values too.
      assert %{type: :atom, opts: opts} = attr.(:button, :variant)
      assert opts[:values] == [:primary, :quiet, :subtle, :icon]
      assert opts[:default] == :primary

      # A default without a look of its own is a value, first.
      assert attr.(:button, :tone).opts[:values] == [:accent, :danger]
      assert attr.(:button, :tone).opts[:default] == :accent

      # An axis named by numbers is an integer attribute, its values in their order.
      assert %{type: :integer, opts: opts} = attr.(:spinner, :size)
      assert opts[:values] == [16, 24, 32]
      assert opts[:default] == 24

      # Without a default in the design, there is none.
      refute Keyword.has_key?(attr.(:spinner, :variant).opts, :default)
      refute Keyword.has_key?(attr.(:step_indicator, :status).opts, :default)
    end

    test "every value adds its variant's class; a default without a look adds none" do
      assigns = %{}

      for {rendered, class} <- [
            {~H"<Kit.button variant={:quiet} roomy={false}>x</Kit.button>",
             "kit-button kit-button--quiet"},
            {~H"<Kit.button variant={:subtle} roomy={false}>x</Kit.button>",
             "kit-button kit-button--subtle"},
            {~H"<Kit.button variant={:icon}>x</Kit.button>", "kit-button kit-button--icon"},
            {~H"<Kit.button tone={:accent}>x</Kit.button>", "kit-button kit-button--primary"},
            {~H"<Kit.button tone={:danger}>x</Kit.button>",
             "kit-button kit-button--primary kit-button--danger"},
            {~H"<Kit.text_field variant={:inverse} />", "kit-text-field kit-text-field--inverse"},
            {~H"<Kit.spinner size={24} />", "kit-spinner"},
            {~H"<Kit.spinner size={16} variant={:accent} />",
             "kit-spinner kit-spinner--accent kit-spinner--16"},
            {~H"<Kit.tag tone={:accent}>x</Kit.tag>", "kit-tag kit-tag--accent"},
            {~H"<Kit.message_bar tone={:danger}>x</Kit.message_bar>",
             "kit-message-bar kit-message-bar--danger"},
            {~H"<Kit.step_indicator status={:current}>1</Kit.step_indicator>",
             "kit-step-indicator kit-step-indicator--current"}
          ] do
        assert html(rendered) =~ norm(~s(class="#{class}")), "#{class}: #{html(rendered)}"
      end
    end

    test "an unknown value warns at compile time" do
      {_, diagnostics} =
        compile(
          ~S'''
          defmodule PhoenixPage do
            use Phoenix.Component
            alias Prism.Generator.PhoenixTest.Kit
            def page(assigns), do: ~H"<Kit.button variant={:primray}>x</Kit.button>"
          end
          ''',
          "page.ex"
        )

      assert [%{severity: :warning, message: message}] = Enum.uniq_by(diagnostics, & &1.message)

      assert message ==
               ~s(attribute "variant" in component Prism.Generator.PhoenixTest.Kit.button/1 must be one of [:primary, :quiet, :subtle, :icon], got: :primray)
    end

    # A value from an assign, which `values:` doesn't see, such as a size the design no
    # longer has.
    test "a value the axis doesn't have fails when it renders, not renders the default" do
      spinner_size = fn assigns -> ~H"<Kit.spinner size={@value} />" end
      spinner_variant = fn assigns -> ~H"<Kit.spinner variant={@value} />" end
      button_variant = fn assigns -> ~H"<Kit.button variant={@value}>x</Kit.button>" end
      button_tone = fn assigns -> ~H"<Kit.button tone={@value}>x</Kit.button>" end
      tag_tone = fn assigns -> ~H"<Kit.tag tone={@value}>x</Kit.tag>" end
      status = fn assigns -> ~H"<Kit.step_indicator status={@value}>1</Kit.step_indicator>" end

      for {render, value, message} <- [
            {spinner_size, 20, "size: 20 is not one of 16, 24, 32"},
            {spinner_size, "16", ~s(size: "16" is not one of 16, 24, 32)},
            {spinner_size, nil, "size: nil is not one of 16, 24, 32"},
            {spinner_variant, :large, "variant: :large is not one of :accent, :inverse"},
            {button_variant, "primary",
             ~s(variant: "primary" is not one of :primary, :quiet, :subtle, :icon)},
            {button_tone, :loud, "tone: :loud is not one of :accent, :danger"},
            {tag_tone, nil, "tone: nil is not one of :neutral, :accent"},
            {status, :done, "status: :done is not one of :current"}
          ] do
        assert_raise ArgumentError, message, fn ->
          rendered_to_string(render.(%{value: value}))
        end
      end
    end

    test "an axis without a default takes nil" do
      assigns = %{status: nil}

      assert html(~H"<Kit.step_indicator status={@status}>1</Kit.step_indicator>") =~
               norm(~s(class="kit-step-indicator"))
    end
  end

  describe "states" do
    test "a state the CSS writes as a class adds it, on the component or its part" do
      assigns = %{}

      assert html(~H"<Kit.text_field invalid />") ==
               norm(~s(<input class="kit-text-field kit-text-field--invalid"/>))

      assert html(~H"<Kit.button loading>Save</Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary kit-button--loading"><span class="kit-button__label">Save</span><span class="kit-spinner kit-spinner--16"></span></button>)
               )

      # The radio's row is no form control, so its disabled state is a class; it
      # disables the radio's control too.
      assert html(~H"<Kit.radio disabled>One</Kit.radio>") ==
               norm(
                 ~s(<label class="kit-radio kit-radio--disabled"><input type="radio" disabled class="kit-radio__control"/><span class="kit-radio__label">One</span></label>)
               )
    end

    test "disabled and checked on a form control set the element's own attribute" do
      assigns = %{}

      assert html(~H"<Kit.button disabled>x</Kit.button>") =~
               norm(~s(<button disabled class="kit-button kit-button--primary">))

      assert html(~H"<Kit.text_field disabled />") ==
               norm(~s(<input disabled class="kit-text-field"/>))

      assert html(~H"<Kit.checkbox checked disabled />") ==
               norm(~s(<input type="checkbox" disabled checked class="kit-checkbox"/>))

      assert html(~H"<Kit.radio checked>One</Kit.radio>") =~
               norm(~s(<input type="radio" checked class="kit-radio__control"/>))
    end

    test "the app's states are boolean attributes; the browser's need none" do
      states = fn c ->
        Enum.sort(for %{type: :boolean, name: name} <- Kit.__components__()[c].attrs, do: name)
      end

      # pressed and focused are the browser's on a button and a text field; the
      # button's flags are boolean attributes too.
      assert states.(:button) == [:disabled, :loading, :roomy, :strong]
      assert states.(:text_field) == [:disabled, :invalid]
      assert states.(:text_area) == []
      assert states.(:radio) == [:checked, :disabled]
      assert states.(:checkbox) == [:checked, :disabled]
      # The option's hovered state is the browser's, its selected state an attribute of its slot.
      assert states.(:select) == []
    end

    test "a select's option takes selected, which adds its class" do
      assigns = %{}

      rendered = ~H"""
      <Kit.select>
        Pick
        <:option selected phx-click="pick" phx-value-id="a">A</:option>
        <:option class="extra">B</:option>
      </Kit.select>
      """

      assert html(rendered) ==
               norm(
                 ~s(<div class="kit-select"><button type="button" class="kit-select__field">Pick</button>) <>
                   ~s(<ul role="listbox" class="kit-select__listbox">) <>
                   ~s(<li role="option" aria-selected="true" phx-click="pick" phx-value-id="a" class="kit-select__option kit-select__option--selected">A</li>) <>
                   ~s(<li role="option" class="kit-select__option extra">B</li></ul></div>)
               )
    end
  end

  describe "flags" do
    test "a flag is a boolean attribute with the design's default, adding its class while on" do
      assigns = %{}
      attr = fn name -> Enum.find(Kit.__components__()[:button].attrs, &(&1.name == name)) end
      assert attr.(:roomy).opts[:default] == true
      assert attr.(:strong).opts[:default] == false

      assert html(~H"<Kit.button strong>x</Kit.button>") =~
               norm(~s(class="kit-button kit-button--primary kit-button--strong"))

      refute html(~H"<Kit.button>x</Kit.button>") =~ "kit-button--strong"
    end

    test "a state the app sets inside a flag or a look with a variant is an attribute too" do
      [spec] =
        Prism.Generator.Phoenix.components(
          %{
            web: %{prefix: "x"},
            components: [
              %{
                name: :text_field,
                style: [],
                parts: [],
                variants: [
                  %{
                    name: :inverse,
                    axis: :variant,
                    aliases: [],
                    style: [],
                    parts: [],
                    with_parts: [],
                    with_variants: [],
                    states: [],
                    web: [],
                    ios: [],
                    android: []
                  }
                ],
                axes: [],
                default: nil,
                with_parts: [],
                flags: [
                  %{
                    name: :dense,
                    default: false,
                    style: [],
                    with_variants: [
                      %{
                        name: :inverse,
                        style: [],
                        states: [%{name: :invalid, style: [opacity: 0.5], parts: [], web: []}],
                        web: []
                      }
                    ],
                    states: [],
                    web: [],
                    ios: [],
                    android: []
                  }
                ],
                states: [],
                web: [],
                ios: [],
                android: []
              }
            ]
          },
          __ENV__
        )

      assert [%{name: :invalid, effects: [{:class, nil, "x-text-field--invalid"}]}] = spec.states
    end

    # A flag whose only looks are with some variants adds its class only with them,
    # their aliases included.
    test "a flag with looks only with some variants adds its class only with those" do
      assigns = %{}

      assert html(~H"<Kit.button variant={:quiet}>x</Kit.button>") =~
               norm(~s(class="kit-button kit-button--quiet kit-button--roomy"))

      assert html(~H"<Kit.button variant={:subtle}>x</Kit.button>") =~
               norm(~s(class="kit-button kit-button--subtle kit-button--roomy"))

      refute html(~H"<Kit.button variant={:primary}>x</Kit.button>") =~ "kit-button--roomy"
      refute html(~H"<Kit.button variant={:quiet} roomy={false}>x</Kit.button>") =~ "roomy"
    end
  end

  describe "parts" do
    test "an icon is a slot whose presence adds the look with it" do
      assigns = %{}

      assert html(~H"<Kit.button>Save<:icon class='i'>*</:icon></Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary kit-button--with-icon">) <>
                   ~s(<span class="kit-button__icon i">*</span><span class="kit-button__label">Save</span></button>)
               )
    end

    test "a part with position: goes at the side of the content the app picks" do
      assigns = %{}
      attr = Enum.find(Kit.__components__()[:button].attrs, &(&1.name == :icon_position))
      assert %{type: :atom, opts: opts} = attr
      assert opts[:values] == [:start, :end]
      assert opts[:default] == :start

      assert html(~H"<Kit.button icon_position={:end}>Save<:icon>*</:icon></Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary kit-button--with-icon">) <>
                   ~s(<span class="kit-button__label">Save</span><span class="kit-button__icon">*</span></button>)
               )

      # With only a slot, HEEx gives an empty inner block, so the label is empty.
      assert html(~H"<Kit.button variant={:icon}><:icon>*</:icon></Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--icon kit-button--with-icon">) <>
                   ~s(<span class="kit-button__icon">*</span><span class="kit-button__label"></span></button>)
               )
    end

    test "a side that is neither :start nor :end fails when it renders, not drops the part" do
      for side <- [nil, "end", :left] do
        assigns = %{side: side}

        assert_raise ArgumentError,
                     "icon_position: #{inspect(side)} is not one of :start, :end",
                     fn ->
                       rendered_to_string(
                         ~H"<Kit.button icon_position={@side}>Save<:icon>*</:icon></Kit.button>"
                       )
                     end
      end
    end

    test "the spinner, a part that is another component, is there only while loading" do
      assigns = %{}
      refute html(~H"<Kit.button>Save</Kit.button>") =~ "kit-spinner"

      # With the variant the part picks.
      assert html(~H"<Kit.button loading>Save</Kit.button>") =~
               norm(~s(<span class="kit-spinner kit-spinner--16"></span>))
    end

    test "parts come in the design's order" do
      kit =
        kit("""
          component :button do
            part :icon
            part :label
          end
        """)

      [{mod, _}] =
        Code.compile_string("""
        defmodule PhoenixOrder#{System.unique_integer([:positive])} do
          use Phoenix.Component
          def page(assigns), do: ~H"<#{inspect(kit)}.button>Save<:icon>*</:icon></#{inspect(kit)}.button>"
        end
        """)

      assert html(mod.page(%{})) ==
               norm(
                 ~s(<button class="only-button">) <>
                   ~s(<span class="only-button__icon">*</span><span class="only-button__label">Save</span></button>)
               )
    end

    test "a field puts its control between its label and its error message" do
      assigns = %{}

      assert html(
               ~H"<Kit.field><:label for='name'>Name</:label>CONTROL<:error_message>Required</:error_message></Kit.field>"
             ) ==
               norm(
                 ~s(<div class="kit-field"><label for="name" class="kit-field__label">Name</label>CONTROL) <>
                   ~s(<p class="kit-field__error-message">Required</p></div>)
               )
    end
  end

  describe "values" do
    defp ring(value),
      do:
        ~s(<svg viewBox="0 0 100 100" aria-hidden="true">) <>
          ~s(<circle class="kit-spinner__track" cx="50" cy="50" r="44"></circle>) <>
          ~s(<circle class="kit-spinner__indicator" cx="50" cy="50" r="44" pathLength="100" ) <>
          ~s|stroke-dasharray="#{value} 100" transform="rotate(-90 50 50)"></circle></svg>|

    test "a value is an attribute, nil by default" do
      attr = Enum.find(Kit.__components__()[:spinner].attrs, &(&1.name == :progress))
      assert %{type: :any, opts: opts} = attr
      assert opts[:default] == nil
    end

    test "with a number: the class, the progressbar's attributes and the ring" do
      assigns = %{}

      assert html(~H"<Kit.spinner progress={40} />") ==
               norm(
                 ~s(<span role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="40" ) <>
                   ~s(class="kit-spinner kit-spinner--progress">) <>
                   ring(40) <> "</span>"
               )
    end

    test "a number out of range clamps to 0 and 100; a fraction stays" do
      for {given, shown} <- [{140, "100"}, {40.5, "40.5"}] do
        assigns = %{given: given}
        html = html(~H"<Kit.spinner progress={@given} />")
        assert html =~ ~s(aria-valuenow="#{shown}"), html
        assert html =~ ~s(stroke-dasharray="#{shown} 100"), html
      end
    end

    # At 0 the arc's round ends would still draw a dot.
    test "at 0, and below, the track without the arc" do
      for given <- [0, -5] do
        assigns = %{given: given}
        html = html(~H"<Kit.spinner progress={@given} />")
        assert html =~ ~s(aria-valuenow="0"), html
        assert html =~ "kit-spinner__track"
        refute html =~ "kit-spinner__indicator"
      end
    end

    test "without one, the spinner as it is, with no role" do
      assigns = %{}

      assert html(~H"<Kit.spinner size={16} progress={nil} />") ==
               norm(~s(<span class="kit-spinner kit-spinner--16"></span>))
    end

    test "anything but a number or nil fails when it renders" do
      assigns = %{}

      assert_raise ArgumentError, ~s(progress: "40" is not a number from 0 to 100, or nil), fn ->
        html(~H'<Kit.spinner progress="40" />')
      end
    end
  end

  describe "the app's adjustments" do
    test "class appends the app's classes, rest takes globals and the element's own" do
      assigns = %{}

      assert html(
               ~H"<Kit.button class='mt-4' id='save' type='submit' phx-click='save'>Save</Kit.button>"
             ) ==
               norm(
                 ~s(<button id="save" type="submit" phx-click="save" class="kit-button kit-button--primary mt-4">) <>
                   ~s(<span class="kit-button__label">Save</span></button>)
               )

      assert html(~H"<Kit.text_field name='email' placeholder='Email' class='w-1/2' />") ==
               norm(~s(<input name="email" placeholder="Email" class="kit-text-field w-1/2"/>))

      # A radio's rest goes on its control, its class on the row.
      assert html(~H"<Kit.radio name='pick' value='1' class='row'>One</Kit.radio>") ==
               norm(
                 ~s(<label class="kit-radio row"><input type="radio" name="pick" value="1" class="kit-radio__control"/><span class="kit-radio__label">One</span></label>)
               )
    end

    test "a button's element is the app's choice" do
      assigns = %{}

      assert html(~H"<Kit.button as='a' href='/next'>Next</Kit.button>") ==
               norm(
                 ~s(<a href="/next" class="kit-button kit-button--primary"><span class="kit-button__label">Next</span></a>)
               )

      assert html(~H"<Kit.button as='div'>Face</Kit.button>") =~ norm(~s(<div class="kit-button))
    end
  end

  test "every class a component renders is a class of the web target's CSS" do
    {_, css, _} =
      ExampleComponents.__schema__() |> Web.files() |> List.keyfind("css/components.css", 0)

    assigns = %{}

    rendered = [
      ~H"""
      <Kit.button variant={:quiet} tone={:danger} loading>x<:icon>i</:icon></Kit.button>
      <Kit.button variant={:subtle}>x</Kit.button>
      <Kit.text_field variant={:inverse} invalid disabled />
      <Kit.text_area value="x" />
      <Kit.field><:label>x</:label>x<:error_message>x</:error_message></Kit.field>
      <Kit.radio_group><Kit.radio checked disabled>x</Kit.radio></Kit.radio_group>
      <Kit.select>x<:icon>v</:icon><:option selected>x</:option></Kit.select>
      <Kit.spinner size={16} variant={:accent} />
      <Kit.spinner size={32} progress={40} />
      <Kit.spinner variant={:inverse} progress={40} />
      <Kit.checkbox checked disabled />
      <Kit.tag tone={:accent}>x</Kit.tag>
      <Kit.message_bar tone={:danger}>x</Kit.message_bar>
      <Kit.step_indicator status={:current}>1</Kit.step_indicator>
      """
    ]

    classes =
      for r <- rendered,
          [_, list] <- Regex.scan(~r/class="([^"]*)"/, html(r)),
          class <- String.split(list),
          uniq: true,
          do: class

    assert length(classes) > 30

    # A component or part without a look of its own may have a class but no rule
    # (the button's icon, the field): a hook for the app.
    design = ExampleComponents.__schema__()

    changed = fn c, part ->
      Enum.any?(c.variants ++ c.states, &Enum.any?(&1.parts, fn p -> p.name == part end))
    end

    hooks =
      for(c <- design.components, c.style == [], do: Classes.component("kit", c.name)) ++
        for c <- design.components,
            p <- c.parts,
            p.component == nil and p.style == [] and p.states == [] and not changed.(c, p.name),
            do: Classes.part("kit", c, p.name)

    assert "kit-button__icon" in hooks

    for class <- classes -- hooks do
      assert css =~ ~r/\.#{Regex.escape(class)}(?![\w-])/, "#{class} is not in the CSS"
    end
  end

  # A page of the app that renders `heex` with `kit`'s components, as markup.
  defp page(kit, heex, assigns \\ %{}) do
    [{mod, _}] =
      Code.compile_string("""
      defmodule PhoenixPage#{System.unique_integer([:positive])} do
        use Phoenix.Component
        alias #{inspect(kit)}, as: K
        def page(assigns), do: ~H\"\"\"
        #{heex}
        \"\"\"
      end
      """)

    html(mod.page(assigns))
  end

  # Every class in `html` that is not a class of the web target's CSS for `kit`'s design.
  defp unstyled(kit, html) do
    design = Module.concat([String.replace(inspect(kit), "PhoenixKit", "PhoenixDesign")])
    {_, css, _} = design.__schema__() |> Web.files() |> List.keyfind("css/components.css", 0)

    for [_, list] <- Regex.scan(~r/class="([^"]*)"/, html),
        class <- String.split(list),
        not (css =~ ~r/\.#{Regex.escape(class)}(?![\w-])/),
        uniq: true,
        do: class
  end

  describe "designs Prism's doesn't have" do
    test "a state of a slot part is an attribute that adds the part's class" do
      kit =
        kit("""
          component :field do
            part :label, foreground: :ink do
              state :invalid, foreground: "#C62828"
            end
            part :error_message, foreground: :ink
          end
        """)

      assert :invalid in Enum.map(kit.__components__().field.attrs, & &1.name)

      html = page(kit, "<K.field invalid><:label>Name</:label>CONTROL</K.field>")

      assert html ==
               norm(
                 ~s(<div class="only-field"><label class="only-field__label only-field__label--invalid">Name</label>CONTROL</div>)
               )

      assert unstyled(kit, html) == ["only-field"]
    end

    test "a disabled select disables its field, the form control among its parts" do
      kit =
        kit("""
          component :select do
            state :disabled, opacity: 0.5
            part :field, height: 40 do
              state :disabled, opacity: 0.4
            end
            part :listbox
            part :option
          end
        """)

      html = page(kit, "<K.select disabled>Pick</K.select>")

      assert html ==
               norm(
                 ~s(<div class="only-select only-select--disabled"><button type="button" disabled class="only-select__field">Pick</button></div>)
               )

      assert unstyled(kit, html) == []
    end

    test "a part that is another component has the classes of that component's defaults" do
      kit =
        kit("""
          component :spinner do
            style size: 24
            variants :size, default: :small do
              variant :small, size: 16
            end
            variant :accent, foreground: :ink
          end

          component :button do
            part :label
            part :spinner, component: :spinner
            state :loading do
              part :label, opacity: 0
            end
          end
        """)

      html = page(kit, "<K.button loading>Save</K.button>")
      assert html =~ norm(~s(<span class="only-spinner only-spinner--small"></span>))
      assert unstyled(kit, html) == []
    end
  end

  describe "a button's element" do
    test "is one of a few tags, checked at compile time" do
      assert Enum.find(Kit.__components__().button.attrs, &(&1.name == :as)).opts[:values] ==
               ~w(button a span div)

      {_, diagnostics} =
        compile(~S'''
        defmodule PhoenixScriptPage do
          use Phoenix.Component
          alias Prism.Generator.PhoenixTest.Kit
          def page(assigns), do: ~H"<Kit.button as='script'>x</Kit.button>"
        end
        ''')

      assert Enum.any?(
               diagnostics,
               &(&1.message =~ ~s(attribute "as" in component) and &1.message =~ ~s(got: "script"))
             )
    end

    test "is refused at render time when the value only comes then" do
      assigns = %{as: "div onclick=alert(1)"}

      assert_raise ArgumentError,
                   ~r/as: "div onclick=alert\(1\)" is not one of "button", "a", "span", "div"/,
                   fn ->
                     rendered_to_string(~H"<Kit.button as={@as}>x</Kit.button>")
                   end
    end
  end

  describe "a design the target can't render fails at the use line" do
    test "an unknown component or part" do
      assert_raise CompileError, ~r/nofile:\d+: the Phoenix target has no component :badge/, fn ->
        kit("  component :badge do\n  end")
      end

      assert_raise CompileError, ~r/no part :badge of :tag; it knows :label/, fn ->
        kit("  component :tag do\n    part :label\n    part :badge\n  end")
      end

      assert_raise CompileError,
                   ~r/:select: its :option goes in its :listbox, which the design doesn't declare/,
                   fn -> kit("  component :select do\n    part :option\n  end") end
    end

    test "a design without a web declaration, or no design" do
      assert_raise CompileError, ~r/needs design: MyApp.Design/, fn ->
        Code.compile_string("defmodule NoDesign do\n  use Prism.Generator.Phoenix\nend")
      end

      assert_raise CompileError, ~r/design: Enum is not a design/, fn ->
        Code.compile_string(
          "defmodule NotADesign do\n  use Prism.Generator.Phoenix, design: Enum\nend"
        )
      end
    end
  end
end
