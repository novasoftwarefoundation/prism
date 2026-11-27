defmodule Prism.Design.WebTest do
  use ExUnit.Case, async: true

  # The generated web package in targets/web; the golden test compares it with 0.1.7.

  @dir "../targets/web"
  @stack ~s("ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace")

  # Code is the system's monospaced font on the web too (SF Mono in Safari, Menlo in the
  # other browsers on macOS, Consolas on Windows), in Tailwind's `font-mono` and Prism's
  # `.font-mono` classes. No other font is, and no font face is loaded for it.
  test "mono, monosmall and monomedium are the system's monospaced font" do
    preset = File.read!(Path.join(@dir, "tailwind.preset.js"))

    for name <- ["mono", "monosmall", "monomedium"] do
      assert preset =~ "        #{name}: [#{@stack}],\n"

      assert preset =~
               ~s(        ".font-#{name}": {\n) <>
                 ~s(          "font-family": "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",\n) <>
                 ~s(          "font-weight": "300",\n)
    end

    assert length(String.split(preset, @stack)) == 4
    assert length(String.split(preset, "ui-monospace, SFMono-Regular")) == 4
    refute File.read!(Path.join(@dir, "css/base.css")) =~ "monospace"
  end
end
