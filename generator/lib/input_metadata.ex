defmodule Prism.Generator.InputMetadata do
  @moduledoc """
  Pure input metadata validation and generated data APIs. These declarations
  describe input instances; they never change rendering or schedule actions.
  """

  @doc """
  Validate atom-keyed per-input metadata against a component's declarations.
  Missing or nil values become nil (disabled). Unknown keys and invalid values
  raise ArgumentError. The design is its public `__schema__/0` data.
  """
  def validate!(design, component, metadata) when is_map(metadata) do
    declaration =
      Enum.find(design.components, &(&1.name == component)) ||
        raise ArgumentError, "unknown component #{inspect(component)}"

    properties = Map.get(declaration, :input_properties, [])
    names = Enum.map(properties, & &1.name)
    unknown = Map.keys(metadata) -- names
    if unknown != [], do: raise(ArgumentError, "unknown input properties: #{inspect(unknown)}")

    Map.new(properties, fn property ->
      value = Map.get(metadata, property.name)

      unless is_nil(value) or
               (is_integer(value) and value >= property.min and value <= property.max),
             do:
               raise(
                 ArgumentError,
                 "#{property.name}: expected nil or integer milliseconds " <>
                   "#{property.min}..#{property.max}"
               )

      {property.name, value}
    end)
  end

  def validate!(_design, _component, _metadata),
    do: raise(ArgumentError, "input metadata must be a map")

  @doc false
  def components(design),
    do: Enum.filter(design.components, &(Map.get(&1, :input_properties, []) != []))

  @doc false
  def react_files(design) do
    case components(design) do
      [] -> []
      components -> [{"src/input-metadata.ts", Enum.map_join(components, "\n", &react/1)}]
    end
  end

  defp react(component) do
    type = pascal(component.name) <> "InputMetadata"

    fields =
      Enum.map_join(component.input_properties, "", fn p ->
        "  /** Integer milliseconds #{p.min}..#{p.max}; absent/null disables. */\n" <>
          "  #{camel(p.name)}?: number | null;\n"
      end)

    checks =
      Enum.map_join(component.input_properties, "", fn p ->
        key = camel(p.name)

        """
          if (metadata.#{key} != null &&
              (!Number.isInteger(metadata.#{key}) ||
               metadata.#{key} < #{p.min} || metadata.#{key} > #{p.max})) {
            throw new Error("#{p.name}: expected integer milliseconds #{p.min}..#{p.max}");
          }
        """
      end)

    returned =
      Enum.map_join(component.input_properties, "", fn p ->
        "    #{camel(p.name)}: metadata.#{camel(p.name)} ?? null,\n"
      end)

    keys = Enum.map_join(component.input_properties, ", ", &JSON.encode!(camel(&1.name)))

    """
    /** Semantic data for a form input; the form owns scheduling and submission. */
    export interface #{type} {
    #{fields}}

    /** Validate metadata without coercion; normalize missing values to null. */
    export function #{camel(component.name)}InputMetadata(
      metadata: #{type} = {},
    ): #{type} {
      if (metadata == null || typeof metadata !== "object" || Array.isArray(metadata)) {
        throw new Error("input metadata must be an object");
      }
      for (const key of Object.keys(metadata)) {
        if (![#{keys}].includes(key)) throw new Error(`unknown input property: ${key}`);
      }
    #{checks}  return {
    #{returned}  };
    }
    """
  end

  @doc false
  def swift_files(design, module) do
    case components(design) do
      [] ->
        []

      components ->
        [
          {"Sources/#{module}/InputMetadata.swift",
           """
           import Foundation

           /// Invalid semantic metadata; form consumers own scheduling and submission.
           public enum #{module}InputMetadataError: Error, Equatable, Sendable {
               case outOfRange(String)
           }

           """ <> Enum.map_join(components, "\n", &swift(&1, module))}
        ]
    end
  end

  defp swift(component, module) do
    type = module <> pascal(component.name) <> "InputMetadata"

    fields =
      Enum.map_join(component.input_properties, "", fn p ->
        "    /// Integer milliseconds #{p.min}...#{p.max}; nil disables.\n" <>
          "    public let #{Prism.Generator.Swift.ident(p.name)}: Int?\n"
      end)

    params =
      Enum.map_join(
        component.input_properties,
        ", ",
        &"#{Prism.Generator.Swift.ident(&1.name)}: Int? = nil"
      )

    checks =
      Enum.map_join(component.input_properties, "", fn p ->
        key = Prism.Generator.Swift.ident(p.name)

        """
                if let value = #{key}, !(#{p.min}...#{p.max}).contains(value) {
                    throw #{module}InputMetadataError.outOfRange("#{p.name}")
                }
                self.#{key} = #{key}
        """
      end)

    coding =
      Enum.map_join(component.input_properties, "", fn p ->
        "        case #{Prism.Generator.Swift.ident(p.name)} = \"#{p.name}\"\n"
      end)

    decoding =
      Enum.map_join(component.input_properties, ",\n", fn p ->
        key = Prism.Generator.Swift.ident(p.name)
        "            #{key}: values.decodeIfPresent(Int.self, forKey: .#{key})"
      end)

    """
    /// Semantic data for one input instance; does not modify the styled field.
    public struct #{type}: Codable, Equatable, Sendable {
    #{fields}
        public init(#{params}) throws {
    #{checks}    }

        private enum CodingKeys: String, CodingKey {
    #{coding}    }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
    #{decoding}
            )
        }
    }
    """
  end

  defp pascal(name), do: name |> Atom.to_string() |> Macro.camelize()

  defp camel(name) do
    <<first::utf8, rest::binary>> = pascal(name)
    String.downcase(<<first::utf8>>) <> rest
  end
end
