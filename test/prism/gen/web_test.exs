defmodule Prism.Gen.WebTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  # The web output is prism 0.1.7, byte for byte, apart from the header line and
  # the reviewed diff in test/golden/0.1.7.diff (a shadow written with `0`
  # instead of `0px`: the same value). A change to the output fails here until
  # the diff file is updated, so every change consumers get is reviewed.
  test "the web output is 0.1.7 plus the reviewed diff", %{tmp_dir: dir} do
    diff =
      for {path, source} <- Prism.Gen.Web.generate(Prism.Tokens.__schema__()) do
        [header, body] = String.split(source, "\n", parts: 2)
        assert header == Prism.Gen.Web.header(path)

        generated = Path.join(dir, String.replace(path, "/", "_"))
        File.write!(generated, body)

        {out, _status} =
          System.cmd("diff", [
            "-u",
            "--label",
            "0.1.7/#{path}",
            "--label",
            "generated/#{path}",
            "test/golden/0.1.7/#{path}",
            generated
          ])

        out
      end

    assert Enum.join(diff) == File.read!("test/golden/0.1.7.diff")
  end

  test "a new token reaches the output" do
    %{tokens: tokens} = Prism.Tokens.__schema__()

    extra = [
      %{kind: :color, name: :accent, value: "#123456", group: "Extra"},
      %{kind: :text_shadow, name: :xl, value: [y: 12, blur: 24, color: {:black, 0.3}], group: nil}
    ]

    files = Map.new(Prism.Gen.Web.generate(%{tokens: tokens ++ extra}))

    assert files["tailwind.preset.js"] =~ ~s(      // Extra\n      accent: "#123456",\n)

    assert files["css/base.css"] =~
             ".prism-text-shadow-xl {\n  text-shadow: 0px 12px 24px rgba(0, 0, 0, 0.3);\n}"
  end
end
