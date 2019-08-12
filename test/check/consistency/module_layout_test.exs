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

      defstruct x: 1, y: 2

      @opaque y :: pos_integer
      @type x :: pos_integer
      @typep z :: pos_integer

      @callback callback() :: any

      @macrocallback macrocallback() :: any

      @optional_callbacks [callback: 0]
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

    assert issue.message == "moduledoc must appear before behaviour"
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

    assert issue.message == "behaviour must appear before use"
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

    assert issue.message == "use must appear before import"
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

    assert issue.message == "import must appear before alias"
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

    assert issue.message == "alias must appear before require"
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

    assert issue.message == "require must appear before module attribute"
  end

  test "module attribute must appear before defstruct" do
    [issue] =
      """
      defmodule Test do
        defstruct x: 1, y: 2
        @x 1
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "module attribute must appear before defstruct"
  end

  test "defstruct must appear before opaque" do
    [issue] =
      """
      defmodule Test do
        @opaque x :: pos_integer
        defstruct x: 1, y: 2
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "defstruct must appear before opaque"
  end

  test "opaque must appear before type" do
    [issue] =
      """
      defmodule Test do
        @type y :: pos_integer
        @opaque x :: pos_integer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "opaque must appear before type"
  end

  test "type must appear before typep" do
    [issue] =
      """
      defmodule Test do
        @typep y :: pos_integer
        @type x :: pos_integer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "type must appear before typep"
  end

  test "typep must appear before callback" do
    [issue] =
      """
      defmodule Test do
        @callback callback() :: any
        @typep x :: pos_integer
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "typep must appear before callback"
  end

  test "callback must appear before macrocallback" do
    [issue] =
      """
      defmodule Test do
        @macrocallback macrocallback() :: any
        @callback callback() :: any
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "callback must appear before macrocallback"
  end

  test "macrocallback must appear before optional_callbacks" do
    [issue] =
      """
      defmodule Test do
        @optional_callbacks :: [callback: 0]
        @macrocallback macrocallback() :: any
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "macrocallback must appear before optional_callbacks"
  end
end
