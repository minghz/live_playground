defmodule DemoWeb.HomepageControllerTest do
  use DemoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix LiveView!"
  end
end
