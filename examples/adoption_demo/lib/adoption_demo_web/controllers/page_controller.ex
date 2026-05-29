defmodule AdoptionDemoWeb.PageController do
  use AdoptionDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
