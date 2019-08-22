%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      requires: [],
      strict: false,
      color: true,
      checks: [
        {VbtCredo.Check.Consistency.ModuleLayout, []},
        {VbtCredo.Check.Readability.WithPlaceholderTest, []},
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.ModuleDoc, false}
      ]
    }
  ]
}
