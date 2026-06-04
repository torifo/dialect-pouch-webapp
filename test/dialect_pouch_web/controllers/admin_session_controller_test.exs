defmodule DialectPouchWeb.AdminSessionControllerTest do
  use DialectPouchWeb.ConnCase, async: true

  import DialectPouch.AccountsFixtures
  alias DialectPouch.Accounts

  setup do
    %{unconfirmed_admin: unconfirmed_admin_fixture(), admin: admin_fixture()}
  end

  describe "POST /admins/log-in - email and password" do
    test "logs the admin in", %{conn: conn, admin: admin} do
      admin = set_password(admin)

      conn =
        post(conn, ~p"/admins/log-in", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin.email
      assert response =~ ~p"/admins/settings"
      assert response =~ ~p"/admins/log-out"
    end

    test "logs the admin in with remember me", %{conn: conn, admin: admin} do
      admin = set_password(admin)

      conn =
        post(conn, ~p"/admins/log-in", %{
          "admin" => %{
            "email" => admin.email,
            "password" => valid_admin_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_dialect_pouch_web_admin_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the admin in with return to", %{conn: conn, admin: admin} do
      admin = set_password(admin)

      conn =
        conn
        |> init_test_session(admin_return_to: "/foo/bar")
        |> post(~p"/admins/log-in", %{
          "admin" => %{
            "email" => admin.email,
            "password" => valid_admin_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, admin: admin} do
      conn =
        post(conn, ~p"/admins/log-in?mode=password", %{
          "admin" => %{"email" => admin.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/admins/log-in"
    end
  end

  describe "POST /admins/log-in - magic link" do
    test "logs the admin in", %{conn: conn, admin: admin} do
      {token, _hashed_token} = generate_admin_magic_link_token(admin)

      conn =
        post(conn, ~p"/admins/log-in", %{
          "admin" => %{"token" => token}
        })

      assert get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin.email
      assert response =~ ~p"/admins/settings"
      assert response =~ ~p"/admins/log-out"
    end

    test "confirms unconfirmed admin", %{conn: conn, unconfirmed_admin: admin} do
      {token, _hashed_token} = generate_admin_magic_link_token(admin)
      refute admin.confirmed_at

      conn =
        post(conn, ~p"/admins/log-in", %{
          "admin" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Admin confirmed successfully."

      assert Accounts.get_admin!(admin.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin.email
      assert response =~ ~p"/admins/settings"
      assert response =~ ~p"/admins/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/admins/log-in", %{
          "admin" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/admins/log-in"
    end
  end

  describe "DELETE /admins/log-out" do
    test "logs the admin out", %{conn: conn, admin: admin} do
      conn = conn |> log_in_admin(admin) |> delete(~p"/admins/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :admin_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the admin is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/admins/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :admin_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
