defmodule Prism.Generator.Web.Classes do
  @moduledoc """
  The web's class names and state selectors, from a design's names. The CSS
  (`Prism.Generator.Web.Components`) and the Phoenix components
  (`Prism.Generator.Phoenix`) both take them from here, so the classes a
  component renders are the classes its CSS styles.

  A class is made of the design's names, with `-` for `_`, and says what kind
  of name it is, as in BEM:

  - a component is `<prefix>-<component>` (`acme-button`);
  - a part is `__<part>` after its component (`acme-button__label`); a part
    that is another component has that component's class;
  - a variant (of any axis, or one of its aliases), a state of the component
    and a look with a part are `--<name>` after the component
    (`acme-button--primary`, `acme-button--loading`, `acme-button--with-icon`);
  - a state of a part is `--<state>` after the part
    (`acme-select__option--selected`).

  A state is the browser's on a form control: a pseudo-class
  (`pseudo_classes/2`). Any other state is a modifier class the app sets.
  """

  # The components whose own element is a form control, and the parts that are one.
  @controls [:button, :text_field, :text_area, :checkbox]
  @control_parts [radio: :control, select: :field]

  @control %{
    pressed: ":active",
    hovered: ":hover",
    focused: ":focus",
    disabled: ":disabled",
    checked: ":checked"
  }

  @element %{hovered: ":hover"}

  @doc "The class of a component: `component(\"acme\", :text_field)` is `\"acme-text-field\"`."
  def component(prefix, name), do: "#{prefix}-#{key(name)}"

  @doc """
  The class of a component's part. `component` is the component's data from
  `__schema__/0`, so a part that is another component has that component's
  class.
  """
  def part(prefix, %{name: component, parts: parts}, name) do
    case Enum.find(parts, &(&1.name == name)) do
      %{component: ref} when ref != nil -> component(prefix, ref)
      _ -> "#{component(prefix, component)}__#{key(name)}"
    end
  end

  @doc """
  The modifier class of a variant, an alias, a state of the component or a
  look with a part (`:with_icon`): `acme-button--primary`.
  """
  def modifier(prefix, component, name), do: "#{component(prefix, component)}--#{key(name)}"

  @doc "The modifier class of a part's state: `acme-select__option--selected`."
  def part_modifier(prefix, component, part, state),
    do: "#{part(prefix, component, part)}--#{key(state)}"

  @doc """
  The states that are the browser's on a component's element (`part` `nil`)
  or on one of its parts, with their pseudo-classes: `%{pressed: ":active", …}`.
  A state not in the map is a modifier class.
  """
  def pseudo_classes(component, nil), do: if(component in @controls, do: @control, else: @element)

  def pseudo_classes(component, part),
    do: if({component, part} in @control_parts, do: @control, else: @element)

  @doc "Whether a component's element (`part` `nil`) or one of its parts is a form control."
  def control?(component, nil), do: component in @controls
  def control?(component, part), do: {component, part} in @control_parts

  defp key(name), do: name |> Atom.to_string() |> String.replace("_", "-")
end
