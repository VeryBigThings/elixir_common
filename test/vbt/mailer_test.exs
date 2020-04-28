defmodule VBT.MailerTest do
  use ExUnit.Case, async: true
  import VBT.TestHelper
  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.{Mailer, TestMailer}

  describe "send!" do
    test "sends mail with all fields populated" do
      Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body")
      mail = assert_delivered_email()
      assert mail.from == {nil, "from@x.y.z"}
      assert mail.to == [{nil, "to@x.y.z"}]
      assert mail.subject == "some subject"
      assert mail.text_body == "mail body"
    end

    test "sets text and html body" do
      send_mail(%{text: "text body", html: "html body"})
      assert_delivered_email(text_body: "text body", html_body: "html body")
    end

    test "sets body through phoenix view" do
      send_mail(%{layout: :layout, template: "greetings.text", name: "foo bar"})
      assert_delivered_email(text_body: "Hello foo bar,\n\n\nBest regards,\nVBT\n")
    end

    test "sets text and html body through phoenix view" do
      send_mail(%{layout: :layout, template: :greetings, name: "foo bar"})
      mail = assert_delivered_email()
      assert mail.text_body == "Hello foo bar,\n\n\nBest regards,\nVBT\n"
      assert mail.html_body == "<div>Hello foo bar,</div>\n<div>Best regards, VBT</div>\n"
    end

    defp send_mail(body),
      do: Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", body)
  end

  describe "enqueue" do
    setup do
      Sandbox.checkout(VBT.TestRepo)
    end

    test "sends e-mail" do
      Mailer.enqueue(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body")
      TestMailer.drain_queue()

      mail = assert_delivered_email()
      assert mail.from == {nil, "from@x.y.z"}
      assert mail.to == [{nil, "to@x.y.z"}]
      assert mail.subject == "some subject"
      assert mail.text_body == "mail body"
    end
  end
end
