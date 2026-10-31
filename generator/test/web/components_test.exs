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
      parts: [%{name: :label, style: [weight: 700], states: [], web: [], ios: [], android: []}],
      with_parts: [],
      states: [],
      web: [doc: "A bold tag"],
      ios: [],
      android: []
    }

    css = css(with_tag(&%{&1 | variants: &1.variants ++ [extra]}))
    assert css =~ "/* A bold tag */\n.acme-tag--bold .acme-tag__label {\n  font-weight: 700;\n}\n"
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
        [label] = accent.parts
        %{tag | variants: [%{accent | parts: [%{label | web: [doc: "Lost"]}]} | rest]}
      end)

    assert_raise ArgumentError, ~r/writes nothing for tag.accent.label web: doc/, fn ->
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

    assert_raise ArgumentError,
                 ~r/the web target has no part :icon of :tag; it knows :label/,
                 fn ->
                   css(with_tag(&%{&1 | parts: &1.parts ++ [part]}))
                 end
  end

  # A misspelled part without a look of its own, which only a variant changes, is
  # written nowhere as itself, so it fails too.
  test "a part the web doesn't know fails, also when only a variant changes it" do
    design =
      compile("""
        component :tag do
          part :lable
          variant :accent do
            part :lable, foreground: :ink
          end
        end
      """)

    assert_raise ArgumentError,
                 ~r/the web target has no part :lable of :tag; it knows :label/,
                 fn ->
                   css(design)
                 end

    design = compile("  component :message_bar do\n    part :icon\n  end")

    assert_raise ArgumentError,
                 ~r/no part :icon of :message_bar; it writes only parts that are other components/,
                 fn -> css(design) end
  end

  test "a component the web doesn't know fails" do
    design = with_tag(&%{&1 | name: :badge})

    assert_raise ArgumentError,
                 ~r/the web target has no component :badge; it knows :button/,
                 fn ->
                   css(design)
                 end
  end

  describe "the spinner" do
    test "is the spinner image as a mask over its color, any color" do
      design =
        compile("""
          component :spinner do
            style size: 24, rotation: {1000, :linear}
            variant :ink, foreground: {:ink, 0.5}
          end
        """)

      [_, mask] =
        Regex.run(
          ~r/\n  mask: (url\("data:image\/svg\+xml,[^"]+"\)) center \/ contain no-repeat;\n/,
          css(design)
        )

      assert css(design) =~
               ".only-spinner {\n  display: inline-block;\n  width: 24px;\n  height: 24px;\n" <>
                 "  background-color: currentColor;\n" <>
                 "  -webkit-mask: #{mask} center / contain no-repeat;\n" <>
                 "  mask: #{mask} center / contain no-repeat;\n" <>
                 "  animation: only-spin 1s linear infinite;\n}\n"

      assert mask =~ "%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'"
      assert css(design) =~ ".only-spinner--ink {\n  color: rgba(16, 16, 16, 0.5);\n}\n"
      refute css(design) =~ "filter"
    end

    # An app imports the CSS into its own stylesheet, where a relative URL would
    # resolve against the app; the web target ships no image files.
    test "its image is inline: no URL in the CSS is relative" do
      design =
        compile("""
          component :spinner
          component :checkbox do
            state :checked, foreground: "#FFFFFF"
          end
        """)

      urls = Regex.scan(~r/url\(([^)]*)\)/, css(design), capture: :all_but_first)
      assert length(urls) == 3
      assert Enum.all?(urls, fn [url] -> String.starts_with?(url, ~s("data:)) end)

      assert Enum.map(Web.files(design), &elem(&1, 0)) ==
               ["tailwind.preset.js", "css/base.css", "css/components.css"]
    end
  end

  # The component body below `compile/1`'s module and use lines starts on line 3.
  defp assert_compile_error(body, message, line) do
    error = assert_raise CompileError, fn -> compile(body) end
    assert Exception.message(error) =~ message
    assert error.line == line
  end

  test "a spinner has no tint filter: its color is its foreground" do
    assert_compile_error(
      "  component :spinner do\n    variant :ink, foreground: :ink, web: [filter: [color: \"#101010\", value: \"sepia(10%)\"]]\n  end",
      "variant :ink: web: unknown key :filter; the web target knows :doc and the properties here",
      4
    )
  end

  test "the check mark's color can't have alpha, and a spinner has no background" do
    assert_compile_error(
      "  component :checkbox do\n    state :checked, foreground: {:ink, 0.5}\n  end",
      "component :checkbox, state :checked: foreground: the check mark is an image in this color, so it has no alpha",
      4
    )

    # Also when the web binding gives the color.
    assert_compile_error(
      "  component :checkbox do\n    state :checked, foreground: :ink, web: [foreground: {:ink, 0.2}]\n  end",
      "web: foreground: the check mark is an image",
      4
    )

    assert_compile_error(
      "  component :spinner do\n    variant :ink, background: :ink\n  end",
      "variant :ink: background: a spinner is drawn in its foreground color",
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
        component :button do
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
          part :label do
            state :invalid, background: :ink
          end

          variant :primary, radius: :default do
            state :invalid, opacity: 0.5
          end
        end
      """)

    css = css(design)
    assert css =~ "\n.only-tag__label--invalid {\n  background-color: #101010;\n}\n"
    assert css =~ "\n.only-tag--primary.only-tag--invalid {\n  opacity: 0.5;\n}\n"
    refute css =~ "\n.only-tag--invalid {"
  end

  test "a state's part change follows every name of a variant, without empty rules" do
    design =
      compile("""
        component :tag do
          part :label
          variant :red, aliases: [:danger], radius: :default do
            state :hovered do
              part :label, background: :ink
            end
          end
        end
      """)

    css = css(design)

    assert css =~
             "\n.only-tag--red:hover .only-tag__label,\n.only-tag--danger:hover .only-tag__label {\n  background-color: #101010;\n}\n"

    refute css =~ ~r/\{\n\}/
    refute css =~ ".only-tag--danger:hover {"
  end

  test "a variant's change to a part that is another component has that component's class" do
    design =
      compile("""
        component :button do
          part :spinner, component: :spinner
          variant :primary, radius: :default do
            part :spinner, opacity: 0.5
          end
        end
        component :spinner
      """)

    assert css(design) =~ "\n.only-button--primary .only-spinner {\n  opacity: 0.5;\n}\n"
    refute css(design) =~ "only-button__spinner"
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
        component :button do
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
    assert css =~ ".only-button--loading {\n  position: relative;\n}"
    assert css =~ ".only-button--loading .only-button__label {\n  opacity: 0;\n}"
    assert css =~ ".only-button--loading .only-spinner {\n"
    assert css =~ "  margin-top: -10px;\n  margin-left: -10px;\n"
    # While not loading, the spinner is hidden.
    assert css =~ ".only-button:not(.only-button--loading) .only-spinner {\n  display: none;\n}"
  end

  test "classes: a part is __part, a variant and a state --name, so they never read alike" do
    design =
      compile("""
        component :select do
          part :field do
            state :focused, background: :ink
          end
          part :option do
            state :hovered, background: :ink
            state :selected, foreground: :ink
          end
        end
        component :radio do
          state :disabled, opacity: 0.5
          part :control do
            state :checked, background: :ink
          end
        end
      """)

    css = css(design)
    # The select's field and the radio's control are form controls: the browser's states.
    assert css =~ "\n.only-select__field:focus {\n  background-color: #101010;\n}\n"
    assert css =~ "\n.only-radio__control:checked {\n  background-color: #101010;\n}\n"
    assert css =~ "\n.only-radio__control:disabled {\n  cursor: not-allowed;\n}\n"
    # Any other part is an element: a state is a modifier of the part's class.
    assert css =~ "\n.only-select__option:hover {\n  background-color: #101010;\n}\n"
    assert css =~ "\n.only-select__option--selected {\n  color: #101010;\n}\n"
    assert css =~ "\n.only-radio--disabled {\n  opacity: 0.5;\n  cursor: not-allowed;\n}\n"
  end

  # The icon part being there changes the padding: `--with-icon`, which the app (or
  # a component library, given an icon) sets with the part.
  test "a look with a part is --with-<part>, on its own or on a variant" do
    design =
      compile("""
        component :button do
          part :label
          part :icon
          with_part :icon, gap: 4

          variant :primary, padding: [y: 15, x: 16] do
            state :pressed, padding: [top: 16, bottom: 14]

            with_part :icon, padding: [y: 4, x: 16], gap: 12 do
              state :pressed, padding: [top: 5, bottom: 3]
            end
          end
        end
      """)

    css = css(design)
    assert css =~ "\n.only-button--with-icon {\n  gap: 4px;\n}\n"

    assert css =~
             "\n.only-button--primary:active {\n  padding-top: 16px;\n  padding-bottom: 14px;\n}\n"

    assert css =~
             "\n.only-button--primary.only-button--with-icon {\n  padding: 4px 16px;\n  gap: 12px;\n}\n"

    assert css =~
             "\n.only-button--primary.only-button--with-icon:active {\n  padding-top: 5px;\n  padding-bottom: 3px;\n}\n"

    # The variant's own rules come first, so the look with the icon wins.
    [before, _] = String.split(css, ".only-button--primary.only-button--with-icon {")
    assert before =~ ".only-button--primary:active"
    refute css =~ "only-button__icon"
  end
end
