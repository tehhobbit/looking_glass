defmodule LookingGlass.PageController do
  use LookingGlass.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
