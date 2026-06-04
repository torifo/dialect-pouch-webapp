defmodule DialectPouchWeb.AdminLive.LoginTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DialectPouch.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admins/log-in")

      assert html =~ "Log in"
      assert html =~ "Register"
      assert html =~ "Log in with email"
    end
  end

  describe "admin login - magic link" do
    test "sends magic link email when admin exists", %{conn: conn} do
      admin = admin_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admins/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", admin: %{email: admin.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admins/log-in")

      assert html =~ "If your email is in our system"

      assert DialectPouch.Repo.get_by!(DialectPouch.Accounts.AdminToken, admin_id: admin.id).context ==
               "login"
    end

    test "does not disclose if admin is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", admin: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admins/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "admin login - password" do
    test "redirects if admin logs in with valid credentials", %{conn: conn} do
      admin = admin_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/admins/log-in")

      form =
        form(lv, "#login_form_password",
          admin: %{email: admin.email, password: valid_admin_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/admins/log-in")

      form =
        form(lv, "#login_form_password", admin: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/admins/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admins/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/admins/register")

      assert login_html =~ "Register"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      admin = admin_fixture()
      %{admin: admin, conn: log_in_admin(conn, admin)}
    end

    test "shows login page with email filled in", %{conn: conn, admin: admin} do
      {:ok, _lv, html} = live(conn, ~p"/admins/log-in")

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert html =~
               ~s(<input type="email" name="admin[email]" id="login_form_magic_email" value="#{admin.email}")
    end
  end
end
