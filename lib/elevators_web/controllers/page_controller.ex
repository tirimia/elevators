defmodule ElevatorsWeb.PageController do
  use ElevatorsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
