defmodule MyApp.Repo.Migrations.CreateMeasurements do
  @moduledoc """
  Per-frame joint angle measurements.

  `analysis_id` is denormalized from `frame_id` so ROM queries can aggregate
  without joining the (much larger) `frames` table.
  """

  use Ecto.Migration

  def change do
    create table(:measurements) do
      add :analysis_id, references(:analyses, on_delete: :delete_all), null: false
      add :frame_id, references(:frames, on_delete: :delete_all), null: false
      add :joint, :string, null: false
      add :coordinate_system, :string, null: false
      add :quality, :string, null: false, default: "usable"
      add :angle_degrees, :float
      add :timestamp_ms, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:measurements, [:analysis_id, :joint])
    create index(:measurements, [:frame_id])
  end
end
