defmodule Prism.Design.TokensTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  # The generated web files are prism 0.1.7, byte for byte, apart from the header line and
  # the reviewed diff in test/golden/0.1.7.diff (a shadow written with `0`
  # instead of `0px`: the same value). A change to the generated files fails here until
  # the diff file is updated, so every change consumers get is reviewed.
  test "the generated web files are 0.1.7 plus the reviewed diff", %{tmp_dir: dir} do
    diff =
      for {path, body} <- Prism.Generator.Web.files(Prism.Design.Tokens.__schema__()) do
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

  test "the families are roles: Nunito and Nunito Sans on the web, the system font natively" do
    families = for %{kind: :family} = f <- Prism.Design.Tokens.__schema__().tokens, do: f

    assert [{:display, "Nunito"}, {:text, "Nunito Sans"}] ==
             Enum.map(families, &{&1.name, &1.web[:name]})

    assert Enum.all?(families, &(&1.ios == :system and &1.android == :system))
  end

  test "mix prism.gen generates Prism.Design.Tokens into targets/web" do
    assert Application.get_env(:prism_generator, :design) == Prism.Design.Tokens
    assert Application.get_env(:prism_generator, :targets) == [web: "../targets/web"]
    assert File.exists?("../targets/web/package.json")
  end

  test "the committed web files start with the header naming design/lib/tokens.ex" do
    for {path, _body} <- Prism.Generator.Web.files(Prism.Design.Tokens.__schema__()) do
      [header | _] = "../targets/web" |> Path.join(path) |> File.read!() |> String.split("\n")
      assert header == Prism.Generator.Header.line(path, "design/lib/tokens.ex")
    end
  end

  test "mix.exs and targets/web/package.json have the same version" do
    assert JSON.decode!(File.read!("../targets/web/package.json"))["version"] ==
             Mix.Project.config()[:version]
  end
end
