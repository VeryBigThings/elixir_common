defmodule VbtCredo.Check.Consistency.ModuleLayoutTest do
  use Credo.TestHelper

  @described_check VbtCredo.Check.Consistency.ModuleLayout

  test "no errors are reported on a successful layout" do
    """
    defmodule Test do
      @moduledoc "some doc"

      @behaviour GenServer
      @behaviour Supervisor

      use GenServer

      import GenServer

      alias GenServer
      alias Mod1.{Mod2, Mod3}

      require GenServer

      @x 1
    end
    """
    |> to_source_file
    |> refute_issues(@described_check)
  end

  test "moduledoc must appear before behaviour" do
    [issue] =
      """
      defmodule Test do
        @behaviour GenServer
        @moduledoc "some doc"
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of moduledoc."
  end

  test "behaviour must appear before use" do
    [issue] =
      """
      defmodule Test do
        use GenServer
        @behaviour GenServer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of behaviour."
  end

  test "use must appear before import" do
    [issue] =
      """
      defmodule Test do
        import GenServer
        use GenServer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of use."
  end

  test "import must appear before alias" do
    [issue] =
      """
      defmodule Test do
        alias GenServer
        import GenServer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of import."
  end

  test "alias must appear before require" do
    [issue] =
      """
      defmodule Test do
        require GenServer
        alias GenServer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of alias."
  end

  test "require must appear before module attribute" do
    [issue] =
      """
      defmodule Test do
        @x 1
        require GenServer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of require."
  end
end
