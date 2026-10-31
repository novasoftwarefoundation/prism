defmodule Prism.Design.PhoenixTest.UI do
  use Prism.Generator.Phoenix, design: Prism.Design.Components
end

defmodule Prism.Design.PhoenixTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Prism.Design.PhoenixTest.UI

  @css File.read!(Path.join(__DIR__, "../../targets/web/css/components.css"))
  @design Prism.Design.Components.__schema__()

  defp classes(rendered) do
    for [_, list] <- Regex.scan(~r/class="([^"]*)"/, rendered_to_string(rendered)),
        class <- String.split(list),
        uniq: true,
        do: class
  end

  defp in_css?(class), do: @css =~ ~r/\.#{Regex.escape(class)}(?![\w-])/

  test "Prism's design compiles into a component per design component" do
    assert Enum.sort(Map.keys(UI.__components__())) ==
             Enum.sort(Enum.map(@design.components, & &1.name))
  end

  test "a button's classes are classes of the generated components.css" do
    assigns = %{}

    rendered = ~H"""
    <UI.button variant={:secondary} tone={:danger} loading>
      Save <:icon>+</:icon>
    </UI.button>
    """

    assert classes(rendered) == [
             "prism-button",
             "prism-button--secondary",
             "prism-button--danger",
             "prism-button--loading",
             "prism-button--with-icon",
             "prism-button__icon",
             "prism-button__label",
             "prism-spinner",
             "prism-spinner--20"
           ]

    # The icon part has no look of its own, so no rule: its class is a hook for the app.
    assert Enum.reject(classes(rendered), &in_css?/1) == ["prism-button__icon"]
  end

  test "the icon is at the start of the label, or at its end with icon_position={:end}" do
    assigns = %{}

    start =
      rendered_to_string(~H"""
      <UI.button variant={:plain}>Back<:icon>←</:icon></UI.button>
      """)

    finish =
      rendered_to_string(~H"""
      <UI.button variant={:plain} icon_position={:end}>Next<:icon>→</:icon></UI.button>
      """)

    assert start =~ ~r/prism-button__icon">←<\/span>\s*<span class="prism-button__label">Back/
    assert finish =~ ~r/prism-button__label">Next<\/span>\s*<span class="prism-button__icon">→/
  end

  test "plain and text buttons are padded unless padded={false}; other variants get no class" do
    assigns = %{}

    rendered = ~H"""
    <UI.button variant={:text}>A</UI.button>
    <UI.button variant={:plain} padded={false}>B</UI.button>
    <UI.button variant={:primary}>C</UI.button>
    """

    [text, plain, primary] =
      Regex.scan(~r/<button class="([^"]*)"/, rendered_to_string(rendered),
        capture: :all_but_first
      )

    assert text == ["prism-button prism-button--text prism-button--padded"]
    assert plain == ["prism-button prism-button--plain"]
    assert primary == ["prism-button prism-button--primary"]
    assert @css =~ ".prism-button--text.prism-button--padded {\n  padding: 15px 16px;\n}"
  end

  test "every variant and tone the app can pick is a class of the CSS" do
    for variant <- [:primary, :secondary, :plain, :link, :text, :soft, :icon],
        tone <- [:success, :warning, :danger, :neutral, :highlight] do
      assigns = %{variant: variant, tone: tone}

      rendered = ~H"""
      <UI.button variant={@variant} tone={@tone}>A</UI.button>
      """

      assert Enum.all?(classes(rendered), &in_css?/1), "#{variant} #{tone}"
    end
  end

  # The example in the README.
  test "an app's page" do
    assigns = %{saving: true, errors: ["can't be blank"]}

    rendered = ~H"""
    <UI.button variant={:primary} tone={:danger} loading={@saving} phx-click="save">
      Save
      <:icon><span class="hero-check"></span></:icon>
    </UI.button>

    <UI.field>
      <:label for="email">Email</:label>
      <UI.text_field id="email" name="email" invalid={@errors != []} />
      <:error_message :for={error <- @errors}>{error}</:error_message>
    </UI.field>

    <UI.tag tone={:success}>Done</UI.tag>
    """

    html = rendered_to_string(rendered)

    assert html =~
             ~s(class="prism-button prism-button--primary prism-button--danger prism-button--loading prism-button--with-icon")

    assert html =~ ~s(<label for="email" class="prism-field__label">Email</label>)
    assert html =~ ~s(class="prism-text-field prism-text-field--invalid")
    assert html =~ ~s(<p class="prism-field__error-message">can&#39;t be blank</p>)
    assert html =~ ~s(class="prism-tag prism-tag--success")
  end

  test "every axis value and state of every component renders a class of the CSS" do
    assigns = %{}

    rendered = [
      for variant <- [:primary, :secondary, :plain, :link, :text],
          tone <- [:accent, :success, :warning, :danger] do
        assigns = %{variant: variant, tone: tone}

        ~H"""
        <UI.button variant={@variant} tone={@tone} loading disabled>x<:icon>+</:icon></UI.button>
        """
      end,
      ~H"""
      <UI.text_field variant={:inverse} invalid disabled />
      <UI.text_area value="x" />
      <UI.field><:label>x</:label>x<:error_message>x</:error_message></UI.field>
      <UI.radio_group><UI.radio checked disabled>x</UI.radio></UI.radio_group>
      <UI.select>x<:icon>v</:icon><:option selected>x</:option></UI.select>
      <UI.checkbox checked disabled />
      """,
      for size <- [16, 20, 24, 32], variant <- [:accent, :inverse], progress <- [nil, 40] do
        assigns = %{size: size, variant: variant, progress: progress}
        ~H"<UI.spinner size={@size} variant={@variant} progress={@progress} />"
      end,
      for tone <- [:accent, :success, :warning, :danger, :neutral] do
        assigns = %{tone: tone}
        ~H"<UI.tag tone={@tone}>x</UI.tag>"
      end,
      for tone <- [:info, :success, :warning, :danger] do
        assigns = %{tone: tone}
        ~H"<UI.message_bar tone={@tone}>x</UI.message_bar>"
      end,
      for status <- [:incomplete, :current, :complete] do
        assigns = %{status: status}
        ~H"<UI.step_indicator status={@status}>1</UI.step_indicator>"
      end
    ]

    classes = rendered |> List.flatten() |> Enum.flat_map(&classes/1) |> Enum.uniq()
    assert length(classes) > 50

    # Without a look of their own, the button's icon and the field have no rule.
    assert Enum.reject(classes, &in_css?/1) == ["prism-button__icon", "prism-field"]
  end
end
