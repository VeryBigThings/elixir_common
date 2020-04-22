defmodule VBT.Credo.Check.Readability.MultilineSimpleDoTest do
  # credo:disable-for-this-file VBT.Credo.Check.Readability.MultilineSimpleDo
  use Credo.Test.Case

  alias VBT.Credo.Check.Readability.MultilineSimpleDo

  test "reports no errors on valid usage" do
    """
    defmodule Test do
      def fun1, do: :ok
      def fun2, do: :ok

      def fun3,
        do: :ok

      def fun4 do
        if some_condition(),
          do: :ok,
          else: :error
      end
    end
    """
    |> to_source_file()
    |> run_check(MultilineSimpleDo)
    |> refute_issues()
  end

  test "reports error on multiline do:" do
    [issue] =
      """
      defmodule Test do
        def fun,
          do:
            :ok
      end
      """
      |> to_source_file()
      |> run_check(MultilineSimpleDo)
      |> assert_issue()

    assert issue.line_no == 3
    assert issue.column == 5
  end

  test "reports error with comments present:" do
    [issue] =
      """
      defmodule Test do
        def fun,
          # some comment
          do:
          # another comment
            :ok
      end
      """
      |> to_source_file()
      |> run_check(MultilineSimpleDo)
      |> assert_issue()

    assert issue.line_no == 4
    assert issue.column == 5
  end

  test "reports multiple errors" do
    assert [issue1, issue2] =
             """
             defmodule Test do
               def fun1,
                 do:
                   :ok

               def fun2, do: :ok

               def fun3,
                 # some comment
                 do:
                 # another comment
                   :ok
             end
             """
             |> to_source_file()
             |> run_check(MultilineSimpleDo)
             |> assert_issues()

    assert issue1.line_no == 3
    assert issue1.column == 5

    assert issue2.line_no == 10
    assert issue2.column == 5
  end
end
