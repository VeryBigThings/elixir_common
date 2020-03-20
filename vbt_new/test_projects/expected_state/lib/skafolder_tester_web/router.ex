# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterWeb.Router do
  use SkafolderTesterWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SkafolderTesterWeb do
    pipe_through(:api)
  end
end
