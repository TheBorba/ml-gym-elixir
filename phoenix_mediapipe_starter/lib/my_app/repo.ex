defmodule MyApp.Repo do
  @moduledoc """
  Ecto repository for PostgreSQL persistence.

  This repository is configured in `config/config.exs` and `config/test.exs`.
  It is responsible for storing assessment sessions, measurements, ROM data,
  and analysis results.

  Usage:
      MyApp.Repo.all(MyApp.AssessmentSession)
      MyApp.Repo.insert(%MyApp.AssessmentSession{...})
  """

  use Ecto.Repo,
    otp_app: :my_app,
    repo: MyApp.Repo,
    adapter: Ecto.Adapters.Postgres
end

