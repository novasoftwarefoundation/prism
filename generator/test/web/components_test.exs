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
            variant :ink, foreground: :ink, web: [filter: [color: "#202020", value: "sepia(10%)"]]
          end
        """)

      assert_raise ArgumentError,
                   ~r/its web filter was made for #202020, but its color is #101010/,
                   fn ->
                     css(design)
                   end
    end
  end

  # The component body below `compile/1`'s module and use lines starts on line 3.
  defp assert_compile_error(body, message, line) do
    error = assert_raise CompileError, fn -> compile(body) end
    assert Exception.message(error) =~ message
    assert error.line == line
  end

  test "a spinner's filter is CSS filter functions with numeric arguments only" do
    for value <- [
          "brightness(0);} body { color: red",
          "url(x)",
          "blur(2px)",
          "sepia(10%)  invert(1)",
          ""
        ] do
      assert_compile_error(
        "  component :spinner do\n    variant :ink, foreground: :ink, web: [filter: [color: \"#101010\", value: #{inspect(value)}]]\n  end",
        "web: filter: must be [color: \"#RRGGBB\", value: \"a CSS filter\"], the filter one or more of brightness",
        4
      )
    end
  end

  test "a color the web draws into an image or a filter can't have alpha" do
    assert_compile_error(
      "  component :checkbox do\n    state :checked, foreground: {:ink, 0.5}\n  end",
      "component :checkbox, state :checked: foreground: the check mark is an image in this color, so it has no alpha",
      4
    )

    assert_compile_error(
      "  component :spinner do\n    variant :ink, foreground: :transparent\n  end",
      "variant :ink: foreground: the spinner is tinted to this color with a CSS filter, so it has no alpha",
      4
    )

    # Also when the web binding gives the color.
    assert_compile_error(
      "  component :spinner do\n    variant :ink, foreground: :ink, web: [foreground: {:ink, 0.2}]\n  end",
      "web: foreground: the spinner is tinted",
      4
    )
  end

  test "a spinner's size is px or rem, which a button can halve to center it" do
    assert_compile_error(
      "  component :spinner do\n    style size: {50, :percent}\n  end",
      "component :spinner, style: size: a button centers its spinner by half the spinner's size",
      4
    )

    design =
      compile("""
        component :btn do
          part :spinner, component: :spinner
          state :loading
        end
        component :spinner do
          style size: {1.5, :rem}
        end
      """)

    assert css(design) =~ "  margin-top: -0.75rem;\n  margin-left: -0.75rem;\n"
  end

  test "a state without a pseudo-class is scoped to its variant or part" do
    design =
      compile("""
        component :tag do
          part :inner do
            state :error, background: :ink
          end

          variant :primary, radius: :default do
            state :error, opacity: 0.5
          end
        end
      """)

    css = css(design)
    assert css =~ "\n.only-tag-inner.only-tag-error {\n  background-color: #101010;\n}\n"
    assert css =~ "\n.only-tag-primary.only-tag-error {\n  opacity: 0.5;\n}\n"
    refute css =~ "\n.only-tag-error {"
  end

  test "a state's part change follows every name of a variant, without empty rules" do
    design =
      compile("""
        component :tag do
          part :inner
          variant :error, aliases: [:danger], radius: :default do
            state :hovered do
              part :inner, background: :ink
            end
          end
        end
      """)

    css = css(design)

    assert css =~
             "\n.only-tag-error:hover .only-tag-inner,\n.only-tag-danger:hover .only-tag-inner {\n  background-color: #101010;\n}\n"

    refute css =~ ~r/\{\n\}/
    refute css =~ ".only-tag-danger:hover {"
  end

  test "a variant's change to a part that is another component has that component's class" do
    design =
      compile("""
        component :btn do
          part :spinner, component: :spinner
          variant :primary, radius: :default do
            part :spinner, opacity: 0.5
          end
        end
        component :spinner
      """)

    assert css(design) =~ "\n.only-btn-primary .only-spinner {\n  opacity: 0.5;\n}\n"
    refute css(design) =~ "only-btn-spinner"
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
