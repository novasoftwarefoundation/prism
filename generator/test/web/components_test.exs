defmodule Prism.Generator.Web.ComponentsTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{ExampleDesign, Web}

  defp css(design) do
    {_, body, _} = design |> Web.files() |> List.keyfind("css/components.css", 0)
    body
  end

  # The example design with its tag changed by `fun`.
  defp with_tag(fun) do
    design = ExampleDesign.__schema__()
    %{design | components: Enum.map(design.components, fun)}
  end

  defp compile(body) do
    [{mod, _}] =
      Code.compile_string("""
      defmodule WebDesign#{System.unique_integer([:positive])} do
        use Prism.Generator.Schema, tokens: Prism.Generator.TokensOnly
      #{body}
      end
      """)

    mod.__schema__()
  end

  test "the web reads its own binding: a web property replaces the shared one there" do
    [tag] = ExampleDesign.__schema__().components
    assert tag.style[:radius] == :default
    assert tag.web[:radius] == 2

    assert css(ExampleDesign.__schema__()) =~
             ".acme-tag {\n  display: inline-flex;\n  align-items: center;\n  justify-content: center;\n  border-radius: 2px;\n"

    without = with_tag(&%{&1 | web: Keyword.delete(&1.web, :radius)})
    assert css(without) =~ "  border-radius: 4px;\n"
  end

  test "the web never reads another target's binding" do
    other = with_tag(&%{&1 | ios: [radius: 40, opacity: 0.1], android: [radius: 9]})
    assert css(other) == css(ExampleDesign.__schema__())
  end

  test "a new variant reaches the CSS without a change to the web target" do
    extra = %{
      name: :bold,
      axis: :variant,
      aliases: [],
      style: [],
      parts: [%{name: :inner, style: [weight: 700], states: [], web: [], ios: [], android: []}],
      states: [],
      web: [doc: "A bold tag"],
      ios: [],
      android: []
    }

    css = css(with_tag(&%{&1 | variants: &1.variants ++ [extra]}))
    assert css =~ "/* A bold tag */\n.acme-tag-bold .acme-tag-inner {\n  font-weight: 700;\n}\n"
  end

  test "a value the web doesn't write fails, so nothing in the design is ignored" do
    design = with_tag(&%{&1 | style: &1.style ++ [transition: {200, :ease_out}]})

    assert_raise ArgumentError, ~r/the web target writes nothing for tag transition/, fn ->
      css(design)
    end
  end

  test "a web key the web doesn't write fails" do
    design =
      with_tag(fn tag ->
        [accent | rest] = tag.variants
        [inner] = accent.parts
        %{tag | variants: [%{accent | parts: [%{inner | web: [doc: "Lost"]}]} | rest]}
      end)

    assert_raise ArgumentError, ~r/writes nothing for tag.accent.inner web: doc/, fn ->
      css(design)
    end
  end

  test "a part the component's web mechanics don't know fails" do
    part = %{
      name: :icon,
      component: nil,
      style: [gap: 4],
      states: [],
      web: [],
      ios: [],
      android: []
    }

    assert_raise ArgumentError, ~r/writes nothing for tag.icon, tag.icon gap/, fn ->
      css(with_tag(&%{&1 | parts: &1.parts ++ [part]}))
    end
  end

  test "a component the web doesn't know fails" do
    design = with_tag(&%{&1 | name: :badge})

    assert_raise ArgumentError, ~r/the web target has no component :badge; it knows :btn/, fn ->
      css(design)
    end
  end

  describe "the spinner's color" do
    test "white and black are written as filters; another color needs a web filter" do
      design =
        compile("""
          component :spinner do
            style size: 24, rotation: {1000, :linear}
            variant :light, foreground: "#FFFFFF"
            variant :dark, foreground: "#000000"
          end
        """)

      assert css(design) =~ ".only-spinner-light {\n  filter: brightness(0) invert(1);\n}"
      assert css(design) =~ ".only-spinner-dark {\n  filter: brightness(0);\n}"

      design = compile("  component :spinner do\n    variant :ink, foreground: :ink\n  end")

      assert_raise ArgumentError, ~r/give it web: \[filter: \[color: "#101010"/, fn ->
        css(design)
      end
    end

    test "a web filter is used only for the color it was made for, and wrapped at 80 columns" do
      filter = String.duplicate("sepia(10%) ", 10) |> String.trim()

      design =
        compile("""
          component :spinner do
            variant :ink, foreground: :ink, web: [filter: [color: "#101010", value: "#{filter}"]]
          end
        """)

      [first, second] = css(design) |> String.split("\n") |> Enum.filter(&(&1 =~ "sepia"))
      assert String.length(first) <= 80
      assert first =~ ~r/\A  filter: sepia/
      assert second =~ ~r/\A    sepia\(10%\).*;\z/

      design =
        compile("""
          component :spinner do
            variant :ink, foreground: :ink, web: [filter: [color: "#202020", value: "x"]]
          end
        """)

      assert_raise ArgumentError,
                   ~r/its web filter was made for #202020, but its color is #101010/,
                   fn ->
                     css(design)
                   end
    end
  end

  test "the check mark takes the checked state's foreground" do
    design =
      compile("""
        component :checkbox do
          state :checked, background: :ink, foreground: "#123456"
        end
      """)

    assert css(design) =~ "fill='%23123456'"
    refute css(design) =~ "color: #123456"
  end

  test "a loading state hides its parts and centers a spinner part by half its size" do
    design =
      compile("""
        component :btn do
          part :label
          part :spinner, component: :spinner
          state :loading do
            part :label, opacity: 0
          end
        end
        component :spinner do
          style size: 20
        end
      """)

    css = css(design)
    assert css =~ ".only-btn-loading {\n  position: relative;\n}"
    assert css =~ ".only-btn-loading .only-btn-label {\n  opacity: 0;\n}"
    assert css =~ ".only-btn-loading .only-spinner {\n"
    assert css =~ "  margin-top: -10px;\n  margin-left: -10px;\n"
  end
end
