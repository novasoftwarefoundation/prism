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
      assert opts[:values] == [:primary, :quiet, :subtle]
      assert opts[:default] == :primary

      # A default without a look of its own is a value, first.
      assert attr.(:button, :tone).opts[:values] == [:accent, :danger]
      assert attr.(:button, :tone).opts[:default] == :accent
      assert attr.(:spinner, :size).opts[:values] == [:medium, :small]

      # Without a default in the design, there is none.
      refute Keyword.has_key?(attr.(:spinner, :variant).opts, :default)
      refute Keyword.has_key?(attr.(:step_indicator, :status).opts, :default)
    end

    test "every value adds its variant's class; a default without a look adds none" do
      assigns = %{}

      for {rendered, class} <- [
            {~H"<Kit.button variant={:quiet}>x</Kit.button>", "kit-button kit-button--quiet"},
            {~H"<Kit.button variant={:subtle}>x</Kit.button>", "kit-button kit-button--subtle"},
            {~H"<Kit.button tone={:accent}>x</Kit.button>", "kit-button kit-button--primary"},
            {~H"<Kit.button tone={:danger}>x</Kit.button>",
             "kit-button kit-button--primary kit-button--danger"},
            {~H"<Kit.text_field variant={:inverse} />", "kit-text-field kit-text-field--inverse"},
            {~H"<Kit.spinner size={:medium} />", "kit-spinner"},
            {~H"<Kit.spinner size={:small} variant={:accent} />",
             "kit-spinner kit-spinner--accent kit-spinner--small"},
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
               ~s(attribute "variant" in component Prism.Generator.PhoenixTest.Kit.button/1 must be one of [:primary, :quiet, :subtle], got: :primray)
    end
  end

  describe "states" do
    test "a state the CSS writes as a class adds it, on the component or its part" do
      assigns = %{}

      assert html(~H"<Kit.text_field invalid />") ==
               norm(~s(<input class="kit-text-field kit-text-field--invalid"/>))

      assert html(~H"<Kit.button loading>Save</Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary kit-button--loading"><span class="kit-button__label">Save</span><span class="kit-spinner"></span></button>)
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

      # pressed and focused are the browser's on a button and a text field.
      assert states.(:button) == [:disabled, :loading]
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

  describe "parts" do
    test "an icon is a slot whose presence adds the look with it" do
      assigns = %{}

      assert html(~H"<Kit.button>Save<:icon class='i'>*</:icon></Kit.button>") ==
               norm(
                 ~s(<button class="kit-button kit-button--primary kit-button--with-icon">) <>
                   ~s(<span class="kit-button__label">Save</span><span class="kit-button__icon i">*</span></button>)
               )
    end

    test "the spinner, a part that is another component, is there only while loading" do
      assigns = %{}
      refute html(~H"<Kit.button>Save</Kit.button>") =~ "kit-spinner"

      assert html(~H"<Kit.button loading>Save</Kit.button>") =~
               norm(~s(<span class="kit-spinner"></span>))
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
      <Kit.spinner size={:small} variant={:accent} />
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
