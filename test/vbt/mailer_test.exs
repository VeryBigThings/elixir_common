defmodule VBT.MailerTest do
  use ExUnit.Case, async: true
  import VBT.TestHelper
  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.{Mailer, TestMailer}

  setup_all do
    # need to force load the test adapter module, because otherwise the attachment test fails
    # because of lazy module loading in test env and a bamboo internal check
    Code.ensure_loaded(Bamboo.TestAdapter)

    :ok
  end

  describe "send!" do
    test "sends mail with all fields populated" do
      Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body",
        cc: "cc@x.y.z",
        bcc: "bcc@x.y.z",
        headers: %{"Reply-To" => "reply-to@x.y.z"}
      )

      mail = assert_delivered_email()
      assert mail.from == {nil, "from@x.y.z"}
      assert mail.to == [{nil, "to@x.y.z"}]
      assert mail.cc == [{nil, "cc@x.y.z"}]
      assert mail.bcc == [{nil, "bcc@x.y.z"}]
      assert mail.subject == "some subject"
      assert mail.text_body == "mail body"
      assert mail.headers == %{"Reply-To" => "reply-to@x.y.z"}
    end

    test "sends an attachment with data" do
      Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body",
        attachments: [%Bamboo.Attachment{filename: "foo.txt", data: "some content"}]
      )

      mail = assert_delivered_email()
      assert [attachment] = mail.attachments

      assert attachment.filename == "foo.txt"
      assert attachment.data == "some content"
    end

    test "sends an attachment with file" do
      tmp_file = Path.join(System.tmp_dir!(), "attachment_#{unique_positive_integer()}.txt")
      file_data = :crypto.strong_rand_bytes(16)
      File.write(tmp_file, file_data)

      try do
        Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body",
          attachments: [%Bamboo.Attachment{path: tmp_file}]
        )

        mail = assert_delivered_email()
        assert [attachment] = mail.attachments

        assert attachment.filename == Path.basename(tmp_file)
        assert attachment.data == file_data
      after
        File.rm_rf(tmp_file)
      end
    end

    test "doesn't overwrite a filename if provided" do
      tmp_file = Path.join(System.tmp_dir!(), "attachment_#{unique_positive_integer()}.txt")
      file_data = :crypto.strong_rand_bytes(16)
      File.write(tmp_file, file_data)

      try do
        Mailer.send!(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body",
          attachments: [%Bamboo.Attachment{path: tmp_file, filename: "bar.txt"}]
        )

        mail = assert_delivered_email()
        assert [attachment] = mail.attachments

        assert attachment.filename == "bar.txt"
        assert attachment.data == file_data
      after
        File.rm_rf(tmp_file)
      end
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
      Mailer.enqueue(TestMailer, "from@x.y.z", "to@x.y.z", "some subject", "mail body",
        cc: "cc@x.y.z",
        bcc: "bcc@x.y.z",
        headers: %{"Reply-To" => "reply-to@x.y.z"},
        attachments: [%Bamboo.Attachment{filename: "foo.txt", data: "some content"}]
      )

      TestMailer.drain_queue()

      mail = assert_delivered_email()
      assert mail.from == {nil, "from@x.y.z"}
      assert mail.to == [{nil, "to@x.y.z"}]
      assert mail.cc == [{nil, "cc@x.y.z"}]
      assert mail.bcc == [{nil, "bcc@x.y.z"}]
      assert mail.subject == "some subject"
      assert mail.text_body == "mail body"
      assert mail.headers == %{"Reply-To" => "reply-to@x.y.z"}

      assert [attachment] = mail.attachments
      assert attachment.filename == "foo.txt"
      assert attachment.data == "some content"
    end
  end
end
