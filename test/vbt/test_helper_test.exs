defmodule VBT.TestHelperTest do
  use ExUnit.Case, async: true
  alias VBT.TestHelper
  require TestHelper

  doctest TestHelper

  describe "unique_positive_integer" do
    test "returns only positive numbers" do
      Stream.repeatedly(fn -> TestHelper.unique_positive_integer() end)
      |> Stream.take(1000)
      |> Enum.each(&assert(&1 > 0))
    end

    test "returns strictly increasing numbers" do
      Stream.repeatedly(fn -> TestHelper.unique_positive_integer() end)
      |> Stream.take(1000)
      |> Stream.chunk_every(2, 1, :discard)
      |> Enum.each(fn [previous, next] -> assert previous < next end)
    end
  end

  describe "eventually" do
    test "raises an assertion error if the condition is not met after max attempts" do
      e =
        assert_raise(
          ExUnit.AssertionError,
          fn ->
            VBT.TestHelper.eventually(
              fn ->
                current_value = Process.get(:expected_value, 0)
                Process.put(:expected_value, current_value + 1)
                assert current_value == 5
              end,
              attempts: 1,
              delay: 10
            )
          end
        )

      assert e.message == "Assertion with == failed"
    end

    defp token_expired?() do
      current_value = Process.get(:expected_value, 0)
      Process.put(:expected_value, current_value + 1)
      current_value == 5
    end
  end

  describe "assert_delivered_email" do
    test "succeeds on a matched mail" do
      deliver_mail("some subject")
      TestHelper.assert_delivered_email(subject: "some subject")
    end

    test "can match mails in an order different from the send order" do
      deliver_mail("some subject")
      deliver_mail("another subject")

      TestHelper.assert_delivered_email(subject: "another subject")
      TestHelper.assert_delivered_email(subject: "some subject")
    end

    test "uses pattern matching" do
      deliver_mail("some subject")
      TestHelper.assert_delivered_email(subject: subject)
      assert subject == "some subject"
    end

    test "fails if the mail is not matched" do
      deliver_mail("some subject")

      assert_raise(
        ExUnit.AssertionError,
        fn -> TestHelper.assert_delivered_email(subject: "another subject") end
      )
    end

    defp deliver_mail(subject) do
      VBT.Mailer.send!(
        VBT.TestMailer,
        "some_sender@some_host.some.domain",
        "some_recipient@some_host.some_domain",
        subject,
        "mail body"
      )
    end
  end
end
