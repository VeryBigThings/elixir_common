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
        # extra Credo checks
        {Credo.Check.Readability.AliasAs, []},
        {Credo.Check.Readability.SinglePipe, []},
        {Credo.Check.Readability.Specs, []},
        {Credo.Check.Readability.WithCustomTaggedTuple, []},

        # custom VBT checks
        {VBT.Credo.Check.Consistency.FileLocation,
         ignore_folder_namespace: %{
           "lib/skafolder_tester_web" => ~w/channels controllers views/,
           "test/skafolder_tester_web" => ~w/channels controllers views/
         }},
        {VBT.Credo.Check.Consistency.ModuleLayout, []},
        {VBT.Credo.Check.Readability.MultilineSimpleDo, []},

        # disabled checks
        {Credo.Check.Consistency.SpaceAroundOperators, false},
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.ModuleDoc, false},

        # obsolete checks
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false}
      ]
    }
  ]
}
