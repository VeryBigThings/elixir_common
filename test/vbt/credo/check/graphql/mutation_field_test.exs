defmodule VBT.Credo.Check.Graphql.MutationFieldTest do
  use Credo.Test.Case

  alias VBT.Credo.Check.Graphql.MutationField

  test "reports error on non-payload fields" do
    [issue] =
      """
      defmodule Test do
        use VBT.Absinthe.Relay.Schema

        mutation do
          payload field :foo do
          end

          field :bar do
          end

          payload field :baz do
          end
        end
      end
      """
      |> to_source_file()
      |> run_check(MutationField)
      |> assert_issue()

    assert issue.message == "Mutation field :bar is not a payload field."
  end

  test "correctly handles nested modules" do
    [issue] =
      """
      defmodule Test do
        defmodule NotSchema do
        end

        defmodule Schema do
          use VBT.Absinthe.Relay.Schema

          mutation do
            field :foo do
            end
          end
        end

        defmodule AlsoNotSchema do
        end
      end
      """
      |> to_source_file()
      |> run_check(MutationField)
      |> assert_issue()

    assert issue.scope == "Test.Schema"
  end

  test "ignores non-schema modules" do
    """
    defmodule Test do
      mutation do
        field :foo do
        end
      end

      defmodule Schema do
        use VBT.Absinthe.Relay.Schema

        defmodule NotSchema do
          mutation do
            field :foo do
            end
          end
        end
      end

      mutation do
        field :bar do
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(MutationField)
    |> refute_issues()
  end
end
