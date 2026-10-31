defmodule Prism.Design.GoldenTest do
  use ExUnit.Case, async: true

  # Every class of 0.1.7's css/components.css, as the selector it was written in
  # (a class, or a class with a modifier class), and the selector it is now. The
  # same table is in ADR 0002 and targets/web/README.md, for consumers.
  @rename [
    {"prism-btn", "prism-button"},
    {"prism-btn-content", "prism-button__label"},
    {"prism-btn-primary", "prism-button--primary"},
    {"prism-btn-primary-icon", "prism-button--primary.prism-button--with-icon"},
    {"prism-btn-secondary", "prism-button--secondary"},
    {"prism-btn-secondary-icon", "prism-button--secondary.prism-button--with-icon"},
    {"prism-btn-plain", "prism-button--plain"},
    {"prism-btn-plain-icon", "prism-button--plain.prism-button--with-icon"},
    {"prism-btn-link", "prism-button--link"},
    {"prism-btn-label", "prism-button--text"},
    {"prism-btn-loading", "prism-button--loading"},
    {"prism-btn-success", "prism-button--success"},
    {"prism-btn-warning", "prism-button--warning"},
    {"prism-btn-danger", "prism-button--danger"},
    {"prism-btn-delete", "prism-button--danger"},
    {"prism-input", "prism-text-field"},
    {"prism-input-error", "prism-text-field--invalid"},
    {"prism-input-dark", "prism-text-field--inverse"},
    {"prism-textarea", "prism-text-area"},
    {"prism-label", "prism-field__label"},
    {"prism-label-error", "prism-field__error-message"},
    {"prism-radio-group", "prism-radio-group"},
    {"prism-radio-label", "prism-radio"},
    {"prism-radio-label.disabled", "prism-radio--disabled"},
    {"prism-radio", "prism-radio__control"},
    {"prism-radio-text", "prism-radio__label"},
    {"prism-dropdown", "prism-select"},
    {"prism-dropdown-input", "prism-select__field"},
    {"prism-dropdown-icon", "prism-select__icon"},
    {"prism-dropdown-options", "prism-select__listbox"},
    {"prism-dropdown-option", "prism-select__option"},
    {"prism-dropdown-option.selected", "prism-select__option--selected"},
    {"prism-spinner", "prism-spinner"},
    {"prism-spinner-sm", "prism-spinner--16"},
    {"prism-spinner-lg", "prism-spinner--32"},
    {"prism-spinner-primary", "prism-spinner--accent"},
    {"prism-spinner-white", "prism-spinner--inverse"},
    {"prism-checkbox", "prism-checkbox"},
    {"prism-tag", "prism-tag"},
    {"prism-tag-inner", "prism-tag__label"},
    {"prism-tag-primary", "prism-tag--accent"},
    {"prism-tag-secondary", "prism-tag--neutral"},
    {"prism-tag-success", "prism-tag--success"},
    {"prism-tag-warning", "prism-tag--warning"},
    {"prism-tag-error", "prism-tag--danger"},
    {"prism-tag-danger", "prism-tag--danger"},
    {"prism-alert", "prism-message-bar"},
    {"prism-alert-info", "prism-message-bar--info"},
    {"prism-alert-success", "prism-message-bar--success"},
    {"prism-alert-warning", "prism-message-bar--warning"},
    {"prism-alert-error", "prism-message-bar--danger"},
    {"prism-number-icon", "prism-step-indicator"},
    {"prism-number-icon-inactive", "prism-step-indicator--incomplete"},
    {"prism-number-icon-active", "prism-step-indicator--current"},
    {"prism-number-icon-completed", "prism-step-indicator--complete"}
  ]

  # A class of the prefix, with the modifier classes written onto it.
  @selector ~r/\.prism-[a-z0-9-]+(?:\.[a-z][a-z0-9-]*)*/

  defp files, do: Prism.Generator.Web.files(Prism.Design.Components.__schema__())

  defp generated(path) do
    {_, body, _} = List.keyfind(files(), path, 0)
    body
  end

  defp golden(path), do: File.read!("test/golden/0.1.7/#{path}")

  # 0.1.7's css/components.css with every class renamed by the table.
  defp renamed do
    rename = Map.new(@rename)

    Regex.replace(@selector, golden("css/components.css"), fn "." <> old -> "." <> rename[old] end)
  end

  test "the table renames every class of 0.1.7's components.css, and nothing else" do
    golden =
      for [s] <- Regex.scan(@selector, golden("css/components.css")), into: MapSet.new(), do: s

    assert MapSet.size(golden) > 50
    assert MapSet.new(@rename, fn {old, _} -> "." <> old end) == golden
    assert length(@rename) == MapSet.size(golden)
  end

  # Nothing is lost silently: every 0.1.7 class has its new selector in the CSS.
  test "every renamed selector is generated" do
    css = generated("css/components.css")

    missing =
      for {old, new} <- @rename,
          not Regex.match?(~r/\.#{Regex.escape(new)}(?![a-z0-9_-])/, css),
          do: "#{old} -> #{new}"

    assert missing == []
  end

  # The generated preset and base CSS are prism 0.1.7, and the component CSS is
  # 0.1.7 with its classes renamed by the table, byte for byte apart from the
  # header line and the reviewed diff in test/golden/0.1.7.diff (a shadow written
  # with `0` instead of `0px`, the button with an icon, the spinner's mask, …). A
  # change to the generated files fails here until the diff file is updated, so
  # every change consumers get is reviewed.
  test "the generated web files are 0.1.7, renamed, plus the reviewed diff" do
    assert Enum.map(files(), &elem(&1, 0)) ==
             ["tailwind.preset.js", "css/base.css", "css/components.css"]

    diff =
      for path <- ["tailwind.preset.js", "css/base.css", "css/components.css"] do
        if path == "css/components.css",
          do: unified(renamed(), generated(path), "0.1.7-renamed/#{path}", "generated/#{path}"),
          else: unified(golden(path), generated(path), "0.1.7/#{path}", "generated/#{path}")
      end

    assert Enum.join(diff) == File.read!("test/golden/0.1.7.diff")
  end

  # A unified diff with three lines of context, computed here rather than by the
  # system's diff, whose hunks differ between platforms.
  defp unified(old, new, from, to) do
    lines = &String.split(String.trim_trailing(&1, "\n"), "\n")

    {numbered, _} =
      List.myers_difference(lines.(old), lines.(new))
      |> Enum.flat_map(fn {op, ls} -> Enum.map(ls, &{op, &1}) end)
      |> Enum.map_reduce({1, 1}, fn {op, line}, {a, b} ->
        next = %{eq: {a + 1, b + 1}, del: {a + 1, b}, ins: {a, b + 1}}[op]
        {{op, line, a, b}, next}
      end)

    numbered = List.to_tuple(numbered)
    last = tuple_size(numbered) - 1
    changes = for i <- 0..last//1, elem(elem(numbered, i), 0) != :eq, do: i

    case changes do
      [] ->
        ""

      [first | rest] ->
        # Changes at most six unchanged lines apart share a hunk.
        hunks =
          rest
          |> Enum.reduce([{first, first}], fn i, [{s, e} | done] ->
            if i - e <= 7, do: [{s, i} | done], else: [{i, i}, {s, e} | done]
          end)
          |> Enum.reverse()

        body =
          Enum.map_join(hunks, fn {s, e} ->
            slice = for i <- max(s - 3, 0)..min(e + 3, last), do: elem(numbered, i)
            {_, _, a, b} = hd(slice)
            a_len = Enum.count(slice, &(elem(&1, 0) != :ins))
            b_len = Enum.count(slice, &(elem(&1, 0) != :del))

            "@@ -#{range(a, a_len)} +#{range(b, b_len)} @@\n" <>
              Enum.map_join(slice, fn {op, line, _, _} ->
                %{eq: " ", del: "-", ins: "+"}[op] <> line <> "\n"
              end)
          end)

        "--- #{from}\n+++ #{to}\n" <> body
    end
  end

  defp range(start, 1), do: "#{start}"
  defp range(start, 0), do: "#{start - 1},0"
  defp range(start, length), do: "#{start},#{length}"
end
