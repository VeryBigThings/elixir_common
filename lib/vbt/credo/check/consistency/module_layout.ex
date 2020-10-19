# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule VBT.Credo.Check.Consistency.ModuleLayout do
  @moduledoc false

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Module parts should appear in the following order:

         1. @shortdoc
         2. @moduledoc
         3. @behaviour
         4. use
         5. import
         6. alias
         7. require
         8. custom module attributes
         9. defstruct
        10. @opaque
        11. @type
        12. @typep
        13. @callback
        14. @macrocallback
        15. @optional_callbacks
        16. public guards
        17. public macros
        18. public functions
        19. behaviour callbacks
        20. private functions

      This order has been adapted from https://github.com/christopheradams/elixir_style_guide#module-attribute-ordering.
      """
    ]

  alias Credo.Check.Readability.StrictModuleLayout

  @doc false
  def run(source_file, _params) do
    source_file
    |> StrictModuleLayout.run(
      order: ~w/
        shortdoc
        moduledoc
        behaviour
        use
        import
        alias
        require
        module_attribute
        defstruct
        opaque
        type
        typep
        callback
        macrocallback
        optional_callbacks
        private_macro
        public_guard
        public_macro
        public_fun
        callback_impl
        private_fun
      /a,
      ignore: [:private_macro, :private_guard]
    )
    |> Enum.map(&%Credo.Issue{&1 | check: __MODULE__})
  end
end
