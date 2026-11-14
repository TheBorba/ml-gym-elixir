defmodule MyApp.Repo.Migrations.CreateRomResults do
  @moduledoc """
  Aggregated range-of-motion summary per analysis, joint and coordinate system.

  One row answers: "for this video, how far did `left_knee` travel, and how
  many repetitions were detected?"
  """

  use Ecto.Migration

  def change do
    create table(:rom_results) do
      add :analysis_id, references(:analyses, on_delete: :delete_all), null: false
      add :joint, :string, null: false
      add :coordinate_system, :string, null: false
      add :sample_count, :integer, null: false, default: 0
      add :min_angle, :float
      add :max_angle, :float
      add :rom_degrees, :float
      add :repetitions, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:rom_results, [:analysis_id])
    create unique_index(:rom_results, [:analysis_id, :joint, :coordinate_system])
  end
end
