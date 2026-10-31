defmodule Prism.Schema do
  @moduledoc """
  The schema of the Prism style spec, written as a DSL. A module that `use`s it
  is part of the spec: `Prism.Tokens` holds the design tokens.

      group "Brand colors" do
        color :primary, "#4272EF"
        color :delete, :error              # an alias: same value, its own name
      end
      shadow :prism_card, y: 5, blur: 20, color: {:black, 0.1}
      shadow :floating, :prism_card, deprecated: true
      family :nunito_sans, "Nunito Sans", fallback: "sans-serif", faces: [...]
      font :button, :nunito_sans, 700      # family and weight (`font-button`)
      text :button, 18, 18                 # size and line height (`text-button`)
      radius :default, {0.25, :rem}

  Values are platform-neutral: colors are `"#RRGGBB"` or the name of another
  color, shadow colors are `{color, alpha}`, lengths are numbers in px (points
  on iOS, dp on Android) or `{n, :rem}` / `{n, :percent}`.

  Every mistake fails at compile time and points at its line: an unknown
  option, a name that isn't a snake_case atom, a duplicate name, a value of the
  wrong type, or a reference to a token that doesn't exist or has another kind.
  Generators read `__schema__/0`, never the source.
  """

  # The keys each kind of token has, after the macro has put its arguments in.
  @keys %{
    color: [:value],
    shadow: [:value, :deprecated],
    text_shadow: [:value],
    space: [:key, :value],
    height: [:key, :value],
    max_height: [:value],
    radius: [:value],
    family: [:css_name, :doc, :fallback, :faces],
    font: [:family, :weight, :italic],
    text: [:size, :line_height]
  }

  @shadow_keys %{
    shadow: [:inset, :x, :y, :blur, :spread, :color],
    text_shadow: [:x, :y, :blur, :color]
  }

  defmacro __using__(_opts) do
    quote do
      import Prism.Schema
      Module.register_attribute(__MODULE__, :prism_tokens, accumulate: true)
      Module.put_attribute(__MODULE__, :prism_group, nil)
      @before_compile Prism.Schema
    end
  end

  @doc "Puts a comment above the tokens in `body`, e.g. `// Brand colors` in the preset."
  defmacro group(doc, do: body) do
    quote do
      @prism_group unquote(doc)
      unquote(body)
      @prism_group nil
    end
  end

  @doc "A color: `\"#RRGGBB\"`, or the name of another color (an alias)."
  defmacro color(name, value), do: token(:color, name, [value: value], __CALLER__)

  @doc "A box shadow: `[inset:, x:, y:, blur:, spread:, color: {color, alpha}]`, or the name of another shadow."
  defmacro shadow(name, value, opts \\ []),
    do: token(:shadow, name, [value: value] ++ opts, __CALLER__)

  @doc "A text shadow: `[x:, y:, blur:, color: {color, alpha}]`."
  defmacro text_shadow(name, value), do: token(:text_shadow, name, [value: value], __CALLER__)

  @doc "A corner radius: a length."
  defmacro radius(name, value), do: token(:radius, name, [value: value], __CALLER__)

  @doc "A named maximum height in px (`max-h-dropdown`)."
  defmacro max_height(name, value), do: token(:max_height, name, [value: value], __CALLER__)

  @doc "A font family and its font faces (one file per style)."
  defmacro family(name, css_name, opts),
    do: token(:family, name, [css_name: css_name] ++ opts, __CALLER__)

  @doc "A font style: a family and a weight, optionally `italic: true`."
  defmacro font(name, family, weight, opts \\ []),
    do: token(:font, name, [family: family, weight: weight] ++ opts, __CALLER__)

  @doc "A text size: size and line height in px."
  defmacro text(name, size, line_height),
    do: token(:text, name, [size: size, line_height: line_height], __CALLER__)

  @doc "Pixel steps: `space [1, 2]` gives `p-1px` and `p-2px`; `space 15, 60` gives `p-15` = 60px."
  defmacro space(values) when is_list(values) do
    for px <- values, do: token(:space, :"px_#{px}", [key: "#{px}px", value: px], __CALLER__)
  end

  defmacro space(step, px), do: token(:space, :"step_#{step}", [key: step, value: px], __CALLER__)

  @doc "A pixel height step: `height_step 44` gives `h-44px`."
  defmacro height_step(px),
    do: token(:height, :"px_#{px}", [key: "#{px}px", value: px], __CALLER__)

  defp token(kind, name, attrs, caller) do
    unless is_atom(name) and Regex.match?(~r/^[a-z][a-z0-9_]*$/, Atom.to_string(name)),
      do:
        __fail__(
          caller.file,
          caller.line,
          "#{kind} #{Macro.to_string(name)}: name must be a snake_case atom"
        )

    quote do
      @prism_tokens Map.merge(Map.new(unquote(attrs)), %{
                      kind: unquote(kind),
                      name: unquote(name),
                      group: @prism_group,
                      line: unquote(caller.line)
                    })
    end
  end

  @doc false
  def __fail__(file, line, description),
    do: raise(CompileError, file: file, line: line, description: description)

  defmacro __before_compile__(env) do
    tokens = env.module |> Module.get_attribute(:prism_tokens) |> Enum.reverse()
    validate!(tokens, env.file)
    schema = %{tokens: Enum.map(tokens, &Map.delete(&1, :line))}

    quote do
      @doc "This part of the spec as plain data, for generators."
      def __schema__, do: unquote(Macro.escape(schema))
    end
  end

  # Tokens are checked in order, so an alias or reference must come after what it names.
  defp validate!(tokens, file) do
    Enum.reduce(tokens, MapSet.new(), fn t, seen ->
      fail = &__fail__(file, t.line, "#{t.kind} #{inspect(t.name)}#{&1}")
      if {t.kind, t.name} in seen, do: fail.(" is defined twice")

      case Map.keys(t) -- [:kind, :name, :group, :line | @keys[t.kind]] do
        [] -> :ok
        extra -> fail.(": unknown option #{Enum.map_join(extra, ", ", &inspect/1)}")
      end

      case check(t, seen) do
        :ok -> :ok
        {:error, message} -> fail.(": " <> message)
      end

      MapSet.put(seen, {t.kind, t.name})
    end)
  end

  defp check(%{kind: :color, value: "#" <> hex}, _) do
    if Regex.match?(~r/^[0-9A-F]{6}$/, hex),
      do: :ok,
      else: {:error, "write colors as #RRGGBB (upper case)"}
  end

  defp check(%{kind: kind, value: ref}, seen) when kind in [:color, :shadow] and is_atom(ref),
    do: known(seen, kind, ref, "alias of unknown #{kind} #{inspect(ref)}")

  defp check(%{kind: kind, value: shadow}, seen) when kind in [:shadow, :text_shadow] do
    cond do
      not Keyword.keyword?(shadow) ->
        {:error, "a shadow is a keyword list or the name of another shadow"}

      (extra = Keyword.keys(shadow) -- @shadow_keys[kind]) != [] ->
        {:error, "unknown shadow key #{Enum.map_join(extra, ", ", &inspect/1)}"}

      not Enum.all?(Keyword.delete(shadow, :color), &shadow_value?/1) ->
        {:error, "shadow lengths are numbers in px and inset is a boolean"}

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
      n when is_number(n) -> :ok
      {n, unit} when is_number(n) and unit in [:rem, :percent] -> :ok
      _ -> {:error, "#{inspect(value)} is not a length"}
    end
  end

  defp check(%{kind: :family} = family, _) do
    faces = Map.get(family, :faces)

    cond do
      not is_binary(family.css_name) -> {:error, "the CSS name must be a string"}
      not (is_list(faces) and faces != []) -> {:error, "a family needs faces: [...]"}
      not Enum.all?(faces, &face?/1) -> {:error, "a face is [file:, weights: {from, to}, style:]"}
      true -> :ok
    end
  end

  defp check(%{kind: :font} = font, seen) do
    cond do
      font.weight not in 100..1000//100 ->
        {:error, "weight #{inspect(font.weight)} is not 100..1000"}

      Map.get(font, :italic, false) not in [true, false] ->
        {:error, "italic is a boolean"}

      true ->
        known(seen, :family, font.family, "unknown family #{inspect(font.family)}")
    end
  end

  defp check(%{kind: :text, size: size, line_height: line_height}, _) do
    if is_number(size) and is_number(line_height),
      do: :ok,
      else: {:error, "size and line height are numbers in px"}
  end

  defp known(seen, kind, ref, message),
    do: if({kind, ref} in seen, do: :ok, else: {:error, message})

  defp shadow_value?({:inset, value}), do: is_boolean(value)
  defp shadow_value?({_, value}), do: is_number(value)

  defp face?(face) do
    Keyword.keyword?(face) and Enum.sort(Keyword.keys(face)) == [:file, :style, :weights] and
      is_binary(face[:file]) and face[:style] in [:normal, :italic] and
      match?({from, to} when is_integer(from) and is_integer(to) and from <= to, face[:weights])
  end
end
