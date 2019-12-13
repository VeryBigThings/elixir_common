%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      requires: [],
      strict: true,
      color: true,
      checks: [
        {VBT.Credo.Check.Consistency.ModuleLayout, []},
        {VBT.Credo.Check.Readability.WithPlaceholder, []},
        {VBT.Credo.Check.Consistency.FileLocation,
         exclude: [Path.join(~w/test integration skafolder_tester/)]},
        {Credo.Check.Readability.Specs, []},
        {Credo.Check.Design.TagTODO, false}
      ]
    }
  ]
}
