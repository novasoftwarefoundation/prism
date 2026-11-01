defmodule Prism.Generator.SwiftTest do
  use ExUnit.Case, async: true

  alias Prism.Generator.{ExampleComponents, ExampleDesign, Header, Swift}

  # The example designs' Swift packages, reviewed and kept in test/fixtures/swift: one
  # with a component of every kind, one with a token of every kind. CI builds both with
  # xcodebuild. A change to what the generator writes fails here until they are updated.
  for {name, design} <- [components: ExampleComponents, design: ExampleDesign] do
    test "the files for #{inspect(design)} equal the fixtures in test/fixtures/swift/#{name}" do
      dir = "test/fixtures/swift/#{unquote(name)}"
      files = Swift.files(unquote(design).__schema__())

      for {path, body, from} <- files do
        assert File.read!(Path.join(dir, path)) == Header.put(path, from, body),
               "#{path} differs from #{dir}/#{path}"
      end

      on_disk =
        for path <- Path.wildcard(Path.join(dir, "**/*.swift")), do: Path.relative_to(path, dir)

      assert Enum.sort(on_disk) == Enum.sort(for {path, _, _} <- files, do: path)
    end
  end

  test "a package, the tokens, the looks and one file per component, each from its design file" do
    files = Swift.files(ExampleComponents.__schema__())

    assert for({path, _, _} <- files, do: path) ==
             ~w(Package.swift Sources/Kit/Tokens.swift Sources/Kit/Look.swift
                Sources/Kit/Button.swift Sources/Kit/TextField.swift Sources/Kit/TextArea.swift
                Sources/Kit/Field.swift Sources/Kit/RadioGroup.swift Sources/Kit/Radio.swift
                Sources/Kit/Select.swift Sources/Kit/Spinner.swift Sources/Kit/Checkbox.swift
                Sources/Kit/Tag.swift Sources/Kit/MessageBar.swift Sources/Kit/StepIndicator.swift)

    assert Enum.uniq(for {_, _, from} <- files, do: from) == [
             "test/support/example_components.ex"
           ]

    {_, package, _} = List.keyfind(files, "Package.swift", 0)
    assert package =~ ~r/\A\/\/ swift-tools-version: 6\.2\n/
    assert package =~ ~s|platforms: [.iOS(.v26)]|
    assert package =~ ~s|.library(name: "Kit", targets: ["Kit"])|
    refute package =~ "resources"
  end

  test "every line is within 100 columns" do
    for design <- [ExampleComponents, ExampleDesign],
        {path, body, _} <- Swift.files(design.__schema__()),
        line <- String.split(body, "\n") do
      assert String.length(line) <= 100, "#{path} has a line of #{String.length(line)}: #{line}"
    end
  end

  describe "tokens" do
    test "names are camelCase, keywords in backquotes where they are declared" do
      tokens = body(ExampleDesign.__schema__(), "Sources/Acme/Tokens.swift")

      assert tokens =~ "public static let `default` = AcmeRadius.points(4)\n"
      assert tokens =~ "public static let link = accent\n"
      assert tokens =~ "public static let step10: CGFloat = 40\n"

      button = body(ExampleComponents.__schema__(), "Sources/Kit/Button.swift")
      assert button =~ "radius: Kit.Radii.default,"
    end

    test "a typography is its family's iOS binding, weight, italic, size and text style" do
      tokens = body(ExampleDesign.__schema__(), "Sources/Acme/Tokens.swift")
      assert tokens =~ "public static let display = AcmeFontFamily.system\n"

      assert tokens =~
               "family: Families.text, weight: 300, italic: true, size: 16, lineHeight: 24"
    end

    test "Dynamic Type scales body text up to 20 pt as a body style, larger text as a title" do
      assert Swift.text_style(10) == :caption2
      assert Swift.text_style(12) == :caption
      assert Swift.text_style(14) == :footnote
      assert Swift.text_style(15) == :subheadline
      assert Swift.text_style(16) == :callout
      assert Swift.text_style(18) == :body
      assert Swift.text_style(20) == :body
      assert Swift.text_style(21) == :title3
      assert Swift.text_style(24) == :title2
      assert Swift.text_style(28) == :title
      assert Swift.text_style(64) == :largeTitle
    end

    test "a shadow with a spread fails, SwiftUI's shadows have none" do
      assert_raise ArgumentError, ~r/shadow :wide: SwiftUI's shadows have no spread/, fn ->
        ~s|shadow :wide, y: 2, spread: 4, color: {:ink, 0.2}| |> tokens_design() |> Swift.files()
      end
    end
  end

  describe "the looks" do
    test "a state the app sets wins over the focus for the properties both set (ADR 0008)" do
      text_field = body(ExampleComponents.__schema__(), "Sources/Kit/TextField.swift")

      # `.kit-text-field:focus` outweighs `.kit-text-field--invalid` on its own, and
      # `.kit-text-field.kit-text-field--invalid:focus` outweighs both.
      assert index(text_field, "if invalid {") < index(text_field, "if focused {")
      assert index(text_field, "if focused {") < index(text_field, "if focused && invalid {")

      assert text_field =~
               "if focused && invalid {\n            root.apply(KitLook(borderColor: Kit.Colors.alarm))"
    end

    test "under the focus, a variant's own look for the app's state wins, as on the web" do
      design =
        schema("""
        component :text_field do
          style border: [width: 1, color: :ink]
          state :focused, border: [color: "#0000FF"], opacity: 0.9
          state :invalid, border: [color: "#FF0000"]

          variant :inverse do
            state :focused, border: [color: "#FFFF00"]
            state :invalid, border: [color: "#FF8800"]
          end
        end
        """)

      {_, css, _} = design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)
      {_, swift, _} = design |> Swift.files() |> List.keyfind("Sources/Only/TextField.swift", 0)

      # The web's added selectors, and the Swift layers that hold when they match.
      for {selector, layer} <- [
            {".only-text-field.only-text-field--invalid:focus", "if focused && invalid {"},
            {".only-text-field.only-text-field--inverse.only-text-field--invalid:focus",
             "if variant == .inverse && focused && invalid {"}
          ] do
        assert css =~ selector
        assert swift =~ layer
      end

      # Only the border: the focus keeps its opacity. The variant's own invalid look
      # comes last, once.
      assert swift =~
               "if focused && invalid {\n            root.apply(OnlyLook(borderColor: Color(onlyHex: 0xFF0000)))"

      assert index(swift, "if focused && invalid {") <
               index(swift, "if variant == .inverse && focused && invalid {")

      assert swift |> String.split("if variant == .inverse && focused && invalid {") |> length() ==
               2

      # Disabled stays outside the rule.
      refute swift =~ "disabled && invalid"
    end

    test "a variant's own look for the app's state takes only its own properties, as on the web" do
      # The variant's own invalid look sets only the background, and its focus look
      # the border: a focused invalid inverse field keeps the component's invalid
      # border. With a background in the component's invalid look too, that stays the
      # variant's.
      for extra <- ["", ~s|, background: "#FFEEEE"|] do
        design =
          schema("""
          component :text_field do
            style border: [width: 1, color: :ink]
            state :focused, border: [color: "#0000FF"]
            state :invalid, border: [color: "#FF0000"]#{extra}

            variant :inverse do
              state :focused, border: [color: "#FFFF00"]
              state :invalid, background: "#330000"
            end
          end
          """)

        {_, css, _} =
          design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)

        {_, swift, _} =
          design |> Swift.files() |> List.keyfind("Sources/Only/TextField.swift", 0)

        # The web: the component's invalid border over the variant's focus, and nothing
        # heavier than the variant's own invalid look for the background.
        assert css =~
                 ".only-text-field.only-text-field--invalid:focus,\n" <>
                   ".only-text-field--inverse.only-text-field--invalid:focus {\n" <>
                   "  border-color: #ff0000;\n}\n"

        assert css =~
                 "\n.only-text-field--inverse.only-text-field--invalid {\n" <>
                   "  background-color: #330000;\n}\n"

        refute css =~ ~r/invalid:focus[^{]*\{[^}]*background/

        # iOS: the same layers.
        assert swift =~
                 "if variant == .inverse && focused && invalid {\n" <>
                   "            root.apply(OnlyLook(borderColor: Color(onlyHex: 0xFF0000)))"

        assert swift =~
                 "if variant == .inverse && invalid {\n" <>
                   "            root.apply(OnlyLook(background: Color(onlyHex: 0x330000)))"

        assert index(swift, "if variant == .inverse && invalid {") <
                 index(swift, "if variant == .inverse && focused && invalid {")
      end

      # On a part: the variant's own selected look doesn't change the label, so the
      # component's selected label still outweighs the variant's hovered label.
      design =
        schema("""
        component :tag do
          part :label

          state :hovered do
            part :label, foreground: "#111111"
          end

          state :selected do
            part :label, foreground: "#222222"
          end

          variant :accent do
            state :hovered do
              part :label, foreground: "#333333"
            end

            state :selected, background: "#444444"
          end
        end
        """)

      {_, css, _} = design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)
      {_, swift, _} = design |> Swift.files() |> List.keyfind("Sources/Only/Tag.swift", 0)

      assert css =~
               ".only-tag.only-tag--selected:hover .only-tag__label,\n" <>
                 ".only-tag--accent.only-tag--selected:hover .only-tag__label {\n" <>
                 "  color: #222222;\n}\n"

      assert swift =~
               "if variant == .accent && hovered && selected {\n" <>
                 "            label.apply(OnlyLook(foreground: Color(onlyHex: 0x222222)))"
    end

    test "a variant's state and a look with a variant weigh the same; the later wins, as in the CSS" do
      design =
        schema("""
        component :button do
          variant :primary, background: :ink do
            state :pressed, opacity: 0.8
          end

          variants :tone, default: :accent do
            variant :danger do
              with_variant(:primary, opacity: 0.5)
            end
          end
        end
        """)

      {_, css, _} = design |> Prism.Generator.Web.files() |> List.keyfind("css/components.css", 0)

      # On the web, `.only-button--primary.only-button--danger` comes after
      # `.only-button--primary:active`, with the same weight, so it wins.
      assert index(css, ".only-button--primary:active {") <
               index(css, ".only-button--primary.only-button--danger {")

      {_, button, _} = design |> Swift.files() |> List.keyfind("Sources/Only/Button.swift", 0)

      assert index(button, "if variant == .primary && pressed {") <
               index(button, "if variant == .primary && tone == .danger {")
    end

    test "a look with a variant comes after the variant's own, a flag's state last" do
      button = body(ExampleComponents.__schema__(), "Sources/Kit/Button.swift")

      assert index(button, "if variant == .quiet {") <
               index(button, "if variant == .quiet && tone == .danger {")

      assert index(button, "if variant == .quiet && roomy {") <
               index(button, "if variant == .quiet && tone == .danger && hovered {")
    end

    test "an ios: binding replaces the shared value, a web: binding doesn't" do
      tag = body(ExampleDesign.__schema__(), "Sources/Acme/Tag.swift")
      assert tag =~ "root.apply(AcmeLook(background: Acme.Colors.paper, radius: .points(6)))"
    end

    test "a variant named by a number is a case with its axis's name, and a value a Double?" do
      spinner = body(ExampleComponents.__schema__(), "Sources/Kit/Spinner.swift")

      assert spinner =~ "case size24, size16, size32\n"
      assert spinner =~ "size: KitSpinnerSize = .size24,\n        progress: Double? = nil\n"
      assert spinner =~ "if variant == .inverse && progress != nil {"
      assert spinner =~ "stroke: .fraction(0.12)"
    end

    test "a part that is a spinner is drawn with the variants the part picks" do
      button = body(ExampleComponents.__schema__(), "Sources/Kit/Button.swift")
      assert button =~ "KitSpinnerStyle(nil, size: .size16, look: looks.spinner)"
    end

    test "the states SwiftUI knows come from it, the others are the app's" do
      button = body(ExampleComponents.__schema__(), "Sources/Kit/Button.swift")

      assert button =~
               ~r/pressed: configuration\.isPressed,\s+hovered: hovered,\s+disabled: !isEnabled/

      assert button =~ "    public var loading: Bool\n"
      refute button =~ "public var pressed"

      text_field = body(ExampleComponents.__schema__(), "Sources/Kit/TextField.swift")
      assert text_field =~ "    public var focused: Bool\n    public var invalid: Bool\n"
    end
  end

  describe "fails" do
    test "without a swift declaration" do
      assert_raise ArgumentError, ~r/needs the design's swift declaration/, fn ->
        Swift.files(Prism.Generator.TokensOnly.__schema__())
      end
    end

    test "on a length in percent that isn't a radius from 50% or a stroke" do
      assert_raise ArgumentError, ~r/:tag: 10% has no size on iOS/, fn ->
        files(~s|component :tag do\n  style padding: [x: {10, :percent}]\nend|)
      end

      assert_raise ArgumentError, ~r/a radius of 25% depends on the box's sides/, fn ->
        files(~s|component :tag do\n  style radius: {25, :percent}\nend|)
      end

      assert files(~s|component :tag do\n  style radius: {50, :percent}\nend|)
             |> List.keyfind("Sources/Only/Tag.swift", 0)
             |> elem(1) =~ "radius: .capsule"
    end

    test "on a component, a part or a value it doesn't know" do
      assert_raise ArgumentError, ~r/no component :card; it knows :button/, fn ->
        files("component :card do\n  style gap: 4\nend")
      end

      assert_raise ArgumentError, ~r/no part :badge of :tag; it knows :label/, fn ->
        files("component :tag do\n  part :badge, gap: 4\nend")
      end

      assert_raise ArgumentError, ~r/only for a spinner; :field's :hint is a :tag/, fn ->
        files("component :tag\ncomponent :field do\n  part :hint, component: :tag\nend")
      end

      assert_raise ArgumentError, ~r/no value :level of :tag/, fn ->
        files("component :tag do\n  value :level, stroke: 2\nend")
      end
    end
  end

  describe "fonts" do
    @fonts """
    family :text,
      doc: "Text",
      web: [name: "Fonty", fallback: "sans-serif", faces: [[file: "Fonty", weights: {100, 900}, style: :normal]]],
      ios: [name: "Fonty", faces: [[file: "Fonty.woff2", weights: {100, 900}, style: :normal]]],
      android: :system
    """

    test "a family bound to a named iOS font: its files are copied, Fonts.swift registers them" do
      files =
        tokens_design(
          @fonts,
          ~s|swift module: "Fonty", fonts: "test/fixtures/fonts", font_files: ["OFL.txt"]|
        )
        |> Swift.files()

      assert {"Sources/Fonty/Fonts/Fonty.woff2", {:copy, "test/fixtures/fonts/Fonty.woff2"}, _} =
               List.keyfind(files, "Sources/Fonty/Fonts/Fonty.woff2", 0)

      assert {_, {:copy, "test/fixtures/fonts/OFL.txt"}, _} =
               List.keyfind(files, "Sources/Fonty/Fonts/OFL.txt", 0)

      {_, fonts, _} = List.keyfind(files, "Sources/Fonty/Fonts.swift", 0)
      assert fonts =~ ~s|static let files = [\n        "Fonty.woff2",\n    ]|

      {_, package, _} = List.keyfind(files, "Package.swift", 0)
      assert package =~ ~s|.target(name: "Fonty", resources: [.copy("Fonts")])|

      {_, look, _} = List.keyfind(files, "Sources/Fonty/Look.swift", 0)
      assert look =~ "            FontyFonts.register()\n"

      {_, tokens, _} = List.keyfind(files, "Sources/Fonty/Tokens.swift", 0)
      assert tokens =~ ~s|public static let text = FontyFontFamily.named("Fonty")|
    end

    test "with the system font, nothing is copied and nothing registers" do
      files = Swift.files(ExampleDesign.__schema__())
      refute Enum.any?(files, &match?({_, {:copy, _}, _}, &1))
      refute Enum.any?(files, &(elem(&1, 0) =~ "Fonts"))
    end

    test "a named font needs fonts: and a face's file its extension" do
      assert_raise ArgumentError, ~r/the swift declaration needs fonts:/, fn ->
        @fonts |> tokens_design(~s|swift module: "Fonty"|) |> Swift.files()
      end

      assert_raise ArgumentError, ~r/the face "Fonty" needs its file's extension/, fn ->
        @fonts
        |> String.replace(~s|file: "Fonty.woff2"|, ~s|file: "Fonty"|)
        |> tokens_design(~s|swift module: "Fonty", fonts: "test/fixtures/fonts"|)
        |> Swift.files()
      end
    end
  end

  # ------------------------------------------------------------ helpers

  defp body(design, path) do
    {_, body, _} = design |> Swift.files() |> List.keyfind(path, 0)
    body
  end

  defp index(text, part) do
    {index, _} = :binary.match(text, part)
    index
  end

  # The Swift files of a design of components `body`, on Prism.Generator.TokensOnly.
  defp files(body), do: body |> schema() |> Swift.files()

  defp schema(body) do
    n = System.unique_integer([:positive])

    [{module, _}] =
      Code.compile_string("""
      defmodule SwiftDesign#{n} do
        use Prism.Generator.Schema, tokens: Prism.Generator.TokensOnly
        swift module: "Only"
      #{body}
      end
      """)

    module.__schema__()
  end

  # A design of tokens `body`, with a swift declaration.
  defp tokens_design(body, swift \\ ~s|swift module: "Fonty"|) do
    n = System.unique_integer([:positive])

    [{module, _}] =
      Code.compile_string("""
      defmodule SwiftTokens#{n} do
        use Prism.Generator.Schema
        web prefix: "fonty", fonts_url: "../fonts"
        #{swift}
        color :ink, "#101010"
      #{body}
      end
      """)

    module.__schema__()
  end
end
