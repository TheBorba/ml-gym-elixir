defmodule MyApp.Application do
  @moduledoc """
  Application module that starts the supervision tree.

  The supervision tree starts:

  - MyApp.Repo (EctoSQL) — PostgreSQL connection pool
  - MyApp.PubSub (Phoenix.PubSub) — LiveView broadcasting
  - MyAppWeb.Endpoint — Phoenix HTTP/LiveView endpoint
  - Oban — background queue for MP4 analysis

  Note that `MyApp.VideoAnalysis.AnalysisWorker` (an Oban worker) and
  `MyApp.VideoAnalysis.PythonPort` (a plain module) are *not* supervised
  children: they are invoked by Oban from inside a job process.
  """

  use Application

  @impl true
  def start(_type, _argv) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyAppWeb.Endpoint,
      {Oban, Application.fetch_env!(:my_app, Oban)}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MyAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
