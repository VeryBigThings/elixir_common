# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterWeb.PageController do
  use SkafolderTesterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
