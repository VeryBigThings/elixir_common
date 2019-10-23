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
        # extra enabled checks
        {VBT.Credo.Check.Consistency.ModuleLayout, []},
        {VBT.Credo.Check.Readability.WithPlaceholder, []},
        {VBT.Credo.Check.Consistency.FileLocation,
         ignore_folder_namespace: %{
           "lib/<%= app %>_web" => ~w/channels controllers views/,
           "test/<%= app %>_web" => ~w/channels controllers views/
         }},
        {Credo.Check.Readability.AliasAs, []},

        # disabled checks
        {Credo.Check.Readability.Specs, false},
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.ModuleDoc, false}
      ]
    }
  ]
}
