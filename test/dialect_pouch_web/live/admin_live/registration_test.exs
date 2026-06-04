defmodule DialectPouchWeb.AdminLive.RegistrationTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DialectPouch.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admins/register")

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_admin(admin_fixture())
        |> live(~p"/admins/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(admin: %{"email" => "with spaces"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register admin" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/register")

      email = unique_admin_email()
      form = form(lv, "#registration_form", admin: valid_admin_attributes(email: email))

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/admins/log-in")

      assert html =~
               ~r/An email was sent to .*, please access it to confirm your account/
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/register")

      admin = admin_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          admin: %{"email" => admin.email}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/admins/log-in")

      assert login_html =~ "Log in"
    end
  end
end
