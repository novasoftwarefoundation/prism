defmodule Prism.Generator.Schema do
  @moduledoc """
  The schema of a design, written as a DSL. A module that `use`s it is a
  design: it declares design tokens, components (`Prism.Generator.Schema.Components`)
  and how the web files are named. `use Prism.Generator.Schema, tokens: Other`
  takes the tokens and the web declaration of the design `Other`, so the
  components can live in a file of their own; such a design declares no tokens,
  and its `web` declaration only adds `components_doc:`.

      web prefix: "acme", fonts_url: "../fonts"
      group "Brand colors" do
        color :accent, "#1A73E8"
        color :link, :accent               # an alias: same value, its own name
      end
      shadow :card, y: 5, blur: 20, color: {:black, 0.1}
      shadow :raised, :card, deprecated: true
      family :text,
        doc: "Body text (≤ 20px)",
        web: [name: "Acme Sans", fallback: "sans-serif", faces: [...]],
        ios: :system,
        android: :system
      font :button, :text, 700             # family and weight (`font-button`)
      text :button, 18, 18                 # size and line height (`text-button`)
      typography :button, font: :button, text: :button
      radius :default, {0.25, :rem}

  Fonts and text sizes are two low-level lists, named as the web names its
  `font-…` and `text-…` classes. A `typography` token is one font and
  one text size, so no target pairs them on its own. Native targets read
  type only from the `typography` tokens.

  Values are platform-neutral: colors are `"#RRGGBB"` or the name of another
  color, shadow colors are `{color, alpha}`, lengths are numbers in px (points
  on iOS, dp on Android) or `{n, :rem}` / `{n, :percent}`.

  Every mistake fails at compile time and points at its line: an unknown
  option, a name that isn't a snake_case atom, a duplicate name, a value of the
  wrong type, a reference to a token that doesn't exist or has another kind, a
  node in the wrong place, or a binding key its target doesn't know.

  ## The design as data

  Generators read `__schema__/0`, never the source or this module's internals.
  It returns

      %{tokens: [token], components: [component], web: web | nil,
        file: file, tokens_file: file}

  - Every token is a map with `kind`, `name` (an atom) and `group` (its
    group's text or `nil`), in the order of the design, plus per kind:
    - `:color`: `value` (`"#RRGGBB"` or the name of a color);
    - `:shadow`: `value` (a keyword list or the name of a shadow), and
      `deprecated` when given;
    - `:text_shadow`: `value` (a keyword list);
    - `:space` and `:height`: `key` (the web key, `"2px"` or an integer step)
      and `value` (px);
    - `:max_height`: `value` (px); `:radius`: `value` (a length);
    - `:family`: `doc`, and `web`, `ios`, `android` (each `:system` or a
      keyword list with `name`, `faces` and, on the web, `fallback`);
    - `:font`: `family`, `weight`, and `italic` when given;
    - `:text`: `size` and `line_height` (px);
    - `:typography`: `font` and `text` (the names of a font and a text size).
  - Every component is a map, in the order of the design:
    - `name`; `style`, its own look: a keyword list of properties in the
      design's order (`Prism.Generator.Schema.Components.properties/0`), each
      value as the design writes it (a token's name, `{color, alpha}`,
      `"#RRGGBB"`, `:transparent`, a length, insets such as `[y: 15, x: 16]`
      where `x` is left and right and `y` top and bottom, …);
    - `parts`: `[%{name, component, position, style, states}]` in the
      design's order, `component` being the name of the component the part
      is, or `nil`, and `position` the part's side of the content when the app
      may pick it (`:start` or `:end`), or `nil`;
    - `variants`: `[%{name, axis, aliases, style, parts, with_parts,
      with_variants, states}]` in the design's order; `axis` is `:variant`, or
      the name of the `variants` block it is in; `parts` are the changes it
      makes to the component's parts, `[%{name, style, states}]`;
      `with_variants` are its looks with a variant of another axis,
      `[%{name, style, states}]`, `name` being that variant's;
    - `flags`: `[%{name, default, style, with_variants, states}]`, the looks
      the app turns on or off, `default` `true` or `false`; `with_variants`
      as a variant's, naming a variant of any axis;
    - `default`: the default of the `:variant` axis, and `axes`:
      `[%{name, default}]`, the `variants` blocks. A default is the name of
      one of the axis's variants, a name without a look of its own (no class),
      or `nil` for none;
    - `with_parts`: `[%{name, part, style, states}]`, the looks while the
      component has one of its parts (`part`), named `with_<part>`; a
      variant's `with_parts` have the same shape;
    - `states`: `[%{name, style, parts}]`, `name` one of
      `Prism.Generator.Schema.Components.states/0`; a part's states have the
      same shape. A state's `parts` are its changes to the component's parts,
      `[%{name, style, states}]`, with `states` always `[]`; a variant's part
      changes have the same shape, and their `states` are the part's states
      within that variant;
    - and on every component, part, variant, axis, look with a part or a
      variant, flag and state, `web`, `ios` and `android`: its binding for that target, a
      keyword list (`[]` without one). A property in a binding replaces the shared one on that target;
      the other keys are the target's own (`Prism.Generator.Web.Components`).
      A target reads only its own binding.
  - `file` is the design's source file relative to the project
    (`"lib/my_design.ex"`), and `tokens_file` the file of its tokens (the same
    file, or the other design's). Generated files name the one they are made
    from in their header.
  - `web` is the `web` declaration as a map with every key (`prefix`,
    `fonts_url`, `line_clamps`, `preset_doc`, `base_doc`, `font_classes_doc`,
    `components_doc`), or `nil` without one.
  """

  @platforms [:web, :ios, :android]

  # The keys each kind of token has, after the macro has put its arguments in.
  @keys %{
    color: [:value],
    shadow: [:value, :deprecated],
    text_shadow: [:value],
    space: [:key, :value],
    height: [:key, :value],
    max_height: [:value],
    radius: [:value],
    family: [:doc | @platforms],
    font: [:family, :weight, :italic],
    text: [:size, :line_height],
    typography: [:font, :text]
  }

  @text_rule ~s(must be a one-line string without ", \\ or */)
  @face_rule "a face is [file:, weights: {from, to}, style: :normal | :italic], file in A-Z a-z 0-9 . _ -"

  @font_rule "is :system or [name:, faces: [...]] (on web also fallback:)"
  @family_name_rule "must be a CSS family name: letters, digits, spaces, _ and -"
  @weight_rule "weights: {from, to} with 1 <= from <= to <= 1000"

  @web_keys [
    :prefix,
    :fonts_url,
    :line_clamps,
    :preset_doc,
    :base_doc,
    :font_classes_doc,
    :components_doc
  ]

  @shadow_keys %{
    shadow: [:inset, :x, :y, :blur, :spread, :color],
    text_shadow: [:x, :y, :blur, :color]
  }

  defmacro __using__(opts) do
    quote do
      import Prism.Generator.Schema
      import Prism.Generator.Schema.Components
      Module.register_attribute(__MODULE__, :prism_tokens, accumulate: true)
      Module.register_attribute(__MODULE__, :prism_web, accumulate: true)
      Module.register_attribute(__MODULE__, :prism_nodes, accumulate: true)
      Module.put_attribute(__MODULE__, :prism_group, nil)
      Module.put_attribute(__MODULE__, :prism_stack, [])

      Module.put_attribute(
        __MODULE__,
        :prism_import,
        {unquote(Keyword.get(opts, :tokens)), unquote(__CALLER__.line)}
      )

      @before_compile Prism.Generator.Schema
    end
  end

  @doc """
  How the web files are named and introduced. Once per design; the web generator
  needs it.

  - `prefix:` (required) the prefix of the CSS classes the generator writes,
    e.g. `"acme"` gives `.acme-text-shadow`.
  - `fonts_url:` (required) where `css/base.css` finds the font files, relative
    to it, e.g. `"../fonts"`.
  - `line_clamps:` the number of `.<prefix>-max-lines-N` classes (default 0).
  - `preset_doc:`, `base_doc:` the comment block at the top of
    `tailwind.preset.js` and `css/base.css` (several lines allowed).
  - `font_classes_doc:` the comment above the preset's font classes (one line).
  - `components_doc:` the comment block at the top of `css/components.css`.
  """
  defmacro web(opts) do
    quote do
      Prism.Generator.Schema.Components.__top_level__!(
        __MODULE__,
        __ENV__.file,
        unquote(__CALLER__.line),
        "web"
      )

      @prism_web {unquote(opts), unquote(__CALLER__.line)}
    end
  end

  @doc """
  Puts a comment above the tokens in `body`, e.g. `// Brand colors` in the
  preset. Groups don't nest.
  """
  defmacro group(doc, do: body) do
    quote do
      Prism.Generator.Schema.__group__(
        __MODULE__,
        __ENV__.file,
        unquote(__CALLER__.line),
        unquote(doc)
      )

      unquote(body)
      @prism_group nil
    end
  end

  @doc "A color: `\"#RRGGBB\"`, or the name of another color (an alias)."
  defmacro color(name, value), do: token(:color, name, [value: value], [], __CALLER__)

  @doc """
  A box shadow: `[inset:, x:, y:, blur:, spread:, color: {color, alpha}]`, or
  the name of another shadow. Option: `deprecated: true`.
  """
  defmacro shadow(name, value, opts \\ []),
    do: token(:shadow, name, [value: value], opts, __CALLER__)

  @doc "A text shadow: `[x:, y:, blur:, color: {color, alpha}]`."
  defmacro text_shadow(name, value),
    do: token(:text_shadow, name, [value: value], [], __CALLER__)

  @doc "A corner radius: a length."
  defmacro radius(name, value), do: token(:radius, name, [value: value], [], __CALLER__)

  @doc "A named maximum height in px (`max-h-dropdown`)."
  defmacro max_height(name, value),
    do: token(:max_height, name, [value: value], [], __CALLER__)

  @doc """
  A font family: a role (`:display`, `:text`) that each platform binds to a
  font. Options, all required:

  - `doc:` what the role is for; a trailing `(…)` such as `(> 20px)` is the
    size range the web comments name.
  - `web:`, `ios:`, `android:` one per platform, so a new platform forces a
    choice. A binding is `:system` (the platform's system font) or a named font
    `[name:, faces: [[file:, weights: {from, to}, style:]]]`; on the web also
    `fallback:` (a generic CSS family). The web has no `:system` binding yet.

  Weights and italic belong to the fonts that use the family, so every platform
  shares them.
  """
  defmacro family(name, opts), do: token(:family, name, [], opts, __CALLER__)

  @doc "A font: a family and a weight, optionally `italic: true`."
  defmacro font(name, family, weight, opts \\ []),
    do: token(:font, name, [family: family, weight: weight], opts, __CALLER__)

  @doc "A text size: size and line height in px."
  defmacro text(name, size, line_height),
    do: token(:text, name, [size: size, line_height: line_height], [], __CALLER__)

  @doc """
  A typography token: one font and one text size, both required and declared before
  it, e.g. `typography :body, font: :body, text: :body_medium`. Native targets
  read type only from these, never from the two lists.
  """
  defmacro typography(name, opts), do: token(:typography, name, [], opts, __CALLER__)

  defmacro space(values) when is_list(values) do
    for px <- values,
        do: token(:space, :"px_#{px}", [key: "#{px}px", value: px], [], __CALLER__)
  end

  defmacro space(step, px),
    do: token(:space, :"step_#{step}", [key: step, value: px], [], __CALLER__)

  @doc "A pixel height step: `height_step 44` gives `h-44px`."
  defmacro height_step(px),
    do: token(:height, :"px_#{px}", [key: "#{px}px", value: px], [], __CALLER__)

  # The macro's arguments go in `args`, its keyword options in `opts`; they are
  # checked and merged in `__before_compile__`, so options may use attributes.
  defp token(kind, name, args, opts, caller) do
    unless is_atom(name) and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, Atom.to_string(name)),
      do:
        __fail__(
          caller.file,
          caller.line,
          "#{kind} #{Macro.to_string(name)}: name must be a snake_case atom"
        )

    quote do
      Prism.Generator.Schema.Components.__top_level__!(
        __MODULE__,
        __ENV__.file,
        unquote(caller.line),
        unquote("#{kind} #{inspect(name)}")
      )

      @prism_tokens %{
        kind: unquote(kind),
        name: unquote(name),
        group: @prism_group,
        line: unquote(caller.line),
        args: Map.new(unquote(args)),
        opts: unquote(opts)
      }
    end
  end

  @doc false
  def __group__(mod, file, line, doc) do
    Prism.Generator.Schema.Components.__top_level__!(mod, file, line, "group #{inspect(doc)}")

    if outer = Module.get_attribute(mod, :prism_group),
      do:
        __fail__(
          file,
          line,
          "group #{inspect(doc)} inside group #{inspect(outer)}: groups don't nest"
        )

    unless text?(doc), do: __fail__(file, line, "group #{inspect(doc)}: #{@text_rule}")
    Module.put_attribute(mod, :prism_group, doc)
  end

  @doc false
  def __fail__(file, line, description),
    do: raise(CompileError, file: file, line: line, description: description)

  defmacro __before_compile__(env) do
    own = env.module |> Module.get_attribute(:prism_tokens) |> Enum.reverse()
    web = env.module |> Module.get_attribute(:prism_web) |> Enum.reverse()

    {tokens, tokens_file, web} =
      case Module.get_attribute(env.module, :prism_import) do
        {nil, _} ->
          tokens = own |> validate!(env.file) |> Enum.map(&Map.delete(&1, :line))
          {tokens, file(env.file), validate_web!(web, env.file, nil)}

        {module, line} ->
          imported = imported!(module, own, env.file, line)
          {imported.tokens, imported.tokens_file, validate_web!(web, env.file, imported)}
      end

    nodes = env.module |> Module.get_attribute(:prism_nodes) |> Enum.reverse()

    schema = %{
      tokens: tokens,
      components: Prism.Generator.Schema.Components.validate!(nodes, tokens, env.file),
      web: web,
      file: file(env.file),
      tokens_file: tokens_file
    }

    quote do
      @doc "The design as plain data, for generators."
      def __schema__, do: unquote(Macro.escape(schema))
    end
  end

  # The design's file relative to the project, for the headers of generated files;
  # just its name when it lies outside the project, so no machine paths leak out.
  defp file(path) do
    case Path.relative_to(path, File.cwd!()) do
      "/" <> _ -> Path.basename(path)
      relative -> relative
    end
  end

  # The design whose tokens and web declaration a design takes (`tokens: Module`).
  defp imported!(module, own, file, line) do
    fail = &__fail__(file, line, "tokens: #{inspect(module)}#{&1}")

    unless is_atom(module) and match?({:module, _}, Code.ensure_compiled(module)) and
             function_exported?(module, :__schema__, 0),
           do: fail.(" is not a design (a module that uses Prism.Generator.Schema)")

    schema = module.__schema__()
    if schema.components != [], do: fail.(" has components; take tokens from a design without")

    case own do
      [] ->
        schema

      [t | _] ->
        __fail__(
          file,
          t.line,
          "#{t.kind} #{inspect(t.name)}: this design takes its tokens from #{inspect(module)}; declare them there"
        )
    end
  end

  # Tokens are checked in order, so an alias or reference must come after what it names.
  defp validate!(tokens, file) do
    Enum.map_reduce(tokens, MapSet.new(), fn t, seen ->
      fail = &__fail__(file, t.line, "#{t.kind} #{inspect(t.name)}#{&1}")
      if {t.kind, t.name} in seen, do: fail.(" is defined twice")
      t = merge_opts!(t, fail)

      case check(t, seen) do
        :ok -> :ok
        {:error, message} -> fail.(": " <> message)
      end

      {t, MapSet.put(seen, {t.kind, t.name})}
    end)
    |> elem(0)
  end

  defp merge_opts!(%{args: args, opts: opts} = t, fail) do
    unless Keyword.keyword?(opts), do: fail.(": options must be a keyword list")
    keys = Keyword.keys(opts)

    case keys -- Enum.uniq(keys) do
      [] -> :ok
      [key | _] -> fail.(": option #{inspect(key)} is given twice")
    end

    case Enum.filter(keys, &Map.has_key?(args, &1)) do
      [] -> :ok
      [key | _] -> fail.(": #{inspect(key)} is an argument, not an option")
    end

    # Only the kind's own keys, so an option can't replace the token's name or group.
    case keys -- @keys[t.kind] do
      [] -> :ok
      extra -> fail.(": unknown option #{Enum.map_join(extra, ", ", &inspect/1)}")
    end

    t |> Map.drop([:args, :opts]) |> Map.merge(args) |> Map.merge(Map.new(opts))
  end

  defp check(%{kind: :color, name: :transparent}, _),
    do: {:error, "the name is taken: components write :transparent for no color"}

  defp check(%{kind: :color, value: "#" <> hex}, _) do
    if Regex.match?(~r/\A[0-9A-F]{6}\z/, hex),
      do: :ok,
      else: {:error, "write colors as #RRGGBB (upper case)"}
  end

  defp check(%{kind: :shadow, deprecated: deprecated}, _) when not is_boolean(deprecated),
    do: {:error, "deprecated is a boolean"}

  defp check(%{kind: kind, value: ref}, seen) when kind in [:color, :shadow] and is_atom(ref),
    do: known(seen, kind, ref, "alias of unknown #{kind} #{inspect(ref)}")

  defp check(%{kind: kind, value: shadow}, seen) when kind in [:shadow, :text_shadow] do
    cond do
      not Keyword.keyword?(shadow) ->
        {:error, "a shadow is a keyword list or the name of another shadow"}

      (extra = Keyword.keys(shadow) -- @shadow_keys[kind]) != [] ->
        {:error, "unknown shadow key #{Enum.map_join(extra, ", ", &inspect/1)}"}

      not Enum.all?(Keyword.delete(shadow, :color), &shadow_value?/1) ->
        {:error,
         "shadow offsets and spread are numbers in px, blur is not negative, inset is a boolean"}

      true ->
        case shadow[:color] do
          {ref, alpha} when is_atom(ref) and is_number(alpha) and alpha >= 0 and alpha <= 1 ->
            known(seen, :color, ref, "shadow color #{inspect(ref)} is not a color")

          other ->
            {:error, "shadow color must be {color, alpha}, got #{inspect(other)}"}
        end
    end
  end

  defp check(%{kind: :color}, _), do: {:error, "a color is \"#RRGGBB\" or the name of a color"}

  defp check(%{kind: kind, value: px}, _) when kind in [:space, :height, :max_height] do
    if is_number(px) and px >= 0, do: :ok, else: {:error, "#{inspect(px)} is not a length in px"}
  end

  defp check(%{kind: :radius, value: value}, _) do
    case value do
      n when is_number(n) and n >= 0 ->
        :ok

      {n, unit} when is_number(n) and n >= 0 and unit in [:rem, :percent] ->
        :ok

      _ ->
        {:error, "#{inspect(value)} is not a length (a number >= 0, {n, :rem} or {n, :percent})"}
    end
  end

  defp check(%{kind: :family} = family, _) do
    with :ok <- if(text?(Map.get(family, :doc)), do: :ok, else: {:error, "doc: " <> @text_rule}) do
      Enum.find_value(@platforms, :ok, fn platform ->
        case Map.fetch(family, platform) do
          :error ->
            {:error, "missing #{platform}: (every family names #{Enum.join(@platforms, ", ")})"}

          {:ok, binding} ->
            case binding(platform, binding) do
              :ok -> nil
              {:error, message} -> {:error, "#{platform}: #{message}"}
            end
        end
      end)
    end
  end

  defp check(%{kind: :font} = font, seen) do
    cond do
      font.weight not in 100..1000//100 ->
        {:error, "weight #{inspect(font.weight)} is not one of 100, 200, …, 1000"}

      Map.get(font, :italic, false) not in [true, false] ->
        {:error, "italic is a boolean"}

      true ->
        known(seen, :family, font.family, "unknown family #{inspect(font.family)}")
    end
  end

  defp check(%{kind: :text, size: size, line_height: line_height}, _) do
    if is_number(size) and size > 0 and is_number(line_height) and line_height > 0,
      do: :ok,
      else: {:error, "size and line height are numbers in px, greater than 0"}
  end

  defp check(%{kind: :typography} = typography, seen) do
    Enum.find_value([:font, :text], :ok, fn kind ->
      case Map.fetch(typography, kind) do
        :error ->
          {:error, "missing #{kind}: (a typography names a font and a text size)"}

        {:ok, ref} ->
          with :ok <- known(seen, kind, ref, "unknown #{kind} #{inspect(ref)}"), do: nil
      end
    end)
  end

  defp binding(:web, :system),
    do: {:error, ":system is not supported on the web yet; name a font"}

  defp binding(_, :system), do: :ok

  defp binding(platform, font) do
    keys = if platform == :web, do: [:faces, :fallback, :name], else: [:faces, :name]

    cond do
      not (Keyword.keyword?(font) and Enum.sort(Keyword.keys(font)) == keys) ->
        {:error, @font_rule <> ", got #{inspect(font)}"}

      not family_name?(font[:name]) ->
        {:error, "name: " <> @family_name_rule}

      platform == :web and not family_name?(font[:fallback]) ->
        {:error, "fallback: " <> @family_name_rule}

      not (is_list(font[:faces]) and font[:faces] != [] and Enum.all?(font[:faces], &face?/1)) ->
        {:error, @face_rule}

      not Enum.all?(font[:faces], &weights?(&1[:weights])) ->
        {:error, @weight_rule}

      true ->
        :ok
    end
  end

  defp known(seen, kind, ref, message),
    do: if({kind, ref} in seen, do: :ok, else: {:error, message})

  defp shadow_value?({:inset, value}), do: is_boolean(value)
  defp shadow_value?({:blur, value}), do: is_number(value) and value >= 0
  defp shadow_value?({_, value}), do: is_number(value)

  defp face?(face) do
    Keyword.keyword?(face) and Enum.sort(Keyword.keys(face)) == [:file, :style, :weights] and
      is_binary(face[:file]) and Regex.match?(~r/\A[A-Za-z0-9._-]+\z/, face[:file]) and
      face[:style] in [:normal, :italic] and match?({_, _}, face[:weights])
  end

  defp weights?({from, to}),
    do: is_integer(from) and is_integer(to) and 1 <= from and from <= to and to <= 1000

  # Font names reach CSS unquoted (`font-family: Acme Sans, sans-serif`), so only
  # the characters of a plain family name.
  defp family_name?(name), do: is_binary(name) and Regex.match?(~r/\A[A-Za-z0-9 _-]+\z/, name)

  # Design text ends up in JS strings and comments and in CSS strings and comments,
  # so it is one line without quotes, backslashes or a comment end.
  defp text?(text) do
    is_binary(text) and String.valid?(text) and not String.contains?(text, "*/") and
      not Regex.match?(~r/["\\\x{0}-\x{1F}\x{7F}\x{2028}\x{2029}]/u, text)
  end

  # A comment block may have several lines, but no comment end or other controls.
  defp block_text?(text) do
    is_binary(text) and String.valid?(text) and not String.contains?(text, "*/") and
      not Regex.match?(~r/[\x{0}-\x{9}\x{B}-\x{1F}\x{7F}\x{2028}\x{2029}]/u, text)
  end

  # A design that takes its tokens from another takes that design's web declaration
  # too; its own may only add the comment at the top of the component CSS.
  defp validate_web!([], _, imported), do: imported && imported.web

  defp validate_web!([{opts, line} | rest], file, imported) do
    fail = &__fail__(file, line, "web#{&1}")
    if rest != [], do: fail.(" is declared more than once")
    unless Keyword.keyword?(opts), do: fail.(": options must be a keyword list")

    case Keyword.keys(opts) -- @web_keys do
      [] -> :ok
      extra -> fail.(": unknown option #{Enum.map_join(extra, ", ", &inspect/1)}")
    end

    base =
      if imported do
        case Keyword.keys(opts) -- [:components_doc] do
          [] ->
            :ok

          [key | _] ->
            fail.(": #{key} comes with the tokens; this design may only add components_doc:")
        end

        imported.web || fail.(": the design the tokens come from has no web declaration")
      else
        %{
          line_clamps: 0,
          preset_doc: nil,
          base_doc: nil,
          font_classes_doc: nil,
          components_doc: nil
        }
      end

    web = Map.merge(base, Map.new(opts))

    checks = [
      prefix:
        {&(is_binary(&1) and Regex.match?(~r/\A[a-z][a-z0-9-]*\z/, &1)),
         "a lower-case CSS class prefix"},
      fonts_url:
        {&(is_binary(&1) and Regex.match?(~r/\A(?!\/)[A-Za-z0-9._\/-]+\z/, &1)),
         "a relative path (no leading /)"},
      line_clamps: {&(is_integer(&1) and &1 >= 0), "a number >= 0"},
      preset_doc: {&(is_nil(&1) or block_text?(&1)), "text without */"},
      base_doc: {&(is_nil(&1) or block_text?(&1)), "text without */"},
      font_classes_doc: {&(is_nil(&1) or text?(&1)), "one line " <> @text_rule},
      components_doc: {&(is_nil(&1) or block_text?(&1)), "text without */"}
    ]

    for {key, {ok?, rule}} <- checks, not ok?.(web[key]) do
      fail.(": #{key} must be #{rule}, got #{inspect(web[key])}")
    end

    web
  end
end
