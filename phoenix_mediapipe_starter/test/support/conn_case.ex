defmodule MyAppWeb.ConnCase do
  @moduledoc """
  Test case for tests that need a `Plug.Conn` and/or the Ecto sandbox.

  Starts an Ecto SQL sandbox owner so DB access from the test process and from
  any LiveView process it spawns is allowed.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint MyAppWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
