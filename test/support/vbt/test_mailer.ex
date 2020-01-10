defmodule VBT.TestMailer do
  @moduledoc false
  use VBT.Mailer, templates: "templates", oban_worker: [queue: "mailer"]
end
