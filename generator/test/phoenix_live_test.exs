defmodule Prism.Generator.PhoenixLiveTest.Kit do
  use Prism.Generator.Phoenix, design: Prism.Generator.ExampleComponents
end

defmodule Prism.Generator.PhoenixLiveTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :prism_generator
end

defmodule Prism.Generator.PhoenixLiveTest.Live do
  use Phoenix.LiveView

  alias Prism.Generator.PhoenixLiveTest.Kit

  def mount(_params, _session, socket), do: {:ok, assign(socket, text: "before")}

  def handle_event("change", _params, socket), do: {:noreply, assign(socket, text: "after")}

  def render(assigns) do
    ~H"""
    <div id="label"><Kit.button as="div">{@text}</Kit.button></div>
    <div id="icon"><Kit.button as="div">x<:icon>{@text}</:icon></Kit.button></div>
    <div id="inner-block"><Kit.message_bar>{@text}</Kit.message_bar></div>
    <div id="option"><Kit.select>x<:option>{@text}</:option></Kit.select></div>
    """
  end
end

defmodule Prism.Generator.PhoenixLiveTest do
  # A LiveView sends only what changed. These tests render a page, change the
  # content the app gives a component's parts, and read the page the client has
  # then, which `rendered_to_string/1` (all at once, without changes) can't show.
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.LiveViewTest

  alias Prism.Generator.PhoenixLiveTest.{Endpoint, Live}

  @endpoint Endpoint

  setup_all do
    Application.put_env(:prism_generator, Endpoint,
      secret_key_base: String.duplicate("prism", 13),
      live_view: [signing_salt: "prism-live-test"]
    )

    start_supervised!(Endpoint)
    :ok
  end

  setup do
    {:ok, view, _html} = live_isolated(build_conn(), Live)
    render_click(view, "change")
    %{view: view}
  end

  for {part, id} <- [label: "label", icon: "icon", inner_block: "inner-block", option: "option"] do
    test "a change in the #{part}'s content reaches the page", %{view: view} do
      html = view |> element("##{unquote(id)}") |> render()

      assert html =~ "after"
      refute html =~ "before"
    end
  end
end
