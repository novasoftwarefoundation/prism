defmodule Prism.Design.TokensTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  # The web output is prism 0.1.7, byte for byte, apart from the header line and
  # the reviewed diff in test/design/golden/0.1.7.diff (a shadow written with `0`
  # instead of `0px`: the same value). A change to the output fails here until
  # the diff file is updated, so every change consumers get is reviewed.
  test "the web output is 0.1.7 plus the reviewed diff", %{tmp_dir: dir} do
    diff =
      for {path, source} <- Prism.Generator.Web.generate(Prism.Design.Tokens.__schema__()) do
        [header, body] = String.split(source, "\n", parts: 2)
        assert header == Prism.Generator.Web.header(path, "lib/design/tokens.ex")

        generated = Path.join(dir, String.replace(path, "/", "_"))
        File.write!(generated, body)

        {out, _status} =
          System.cmd("diff", [
            "-u",
            "--label",
            "0.1.7/#{path}",
            "--label",
            "generated/#{path}",
            "test/design/golden/0.1.7/#{path}",
            generated
          ])

        out
      end

    assert Enum.join(diff) == File.read!("test/design/golden/0.1.7.diff")
  end

  test "the families are roles: Nunito and Nunito Sans on the web, the system font natively" do
    families = for %{kind: :family} = f <- Prism.Design.Tokens.__schema__().tokens, do: f

    assert [{:display, "Nunito"}, {:text, "Nunito Sans"}] ==
             Enum.map(families, &{&1.name, &1.web[:name]})

    assert Enum.all?(families, &(&1.ios == :system and &1.android == :system))
  end

  test "mix prism.gen.web generates Prism.Design.Tokens into clients/web" do
    assert Application.get_env(:prism, :design) == Prism.Design.Tokens
    assert Application.get_env(:prism, :out) == "clients/web"
    assert File.exists?("clients/web/package.json")
  end

  test "mix.exs and clients/web/package.json have the same version" do
    assert JSON.decode!(File.read!("clients/web/package.json"))["version"] ==
             Mix.Project.config()[:version]
  end
end
