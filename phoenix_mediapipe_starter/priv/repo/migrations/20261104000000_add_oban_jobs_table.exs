defmodule MyApp.Repo.Migrations.AddObanJobsTable do
  @moduledoc """
  Creates the Oban job tables used by the `video_analysis` queue.

  Kept as the first migration so background jobs work as soon as the
  database is created.
  """

  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 14)

  def down, do: Oban.Migrations.down(version: 1)
end
