defmodule MyApp.Repo.Migrations.CreateFrames do
  @moduledoc """
  Sampled landmark frames produced by the Python MediaPipe worker.

  Both coordinate systems are stored side by side and never merged:
  `image_landmarks` are normalized [0, 1] image coordinates and
  `world_landmarks` are MediaPipe world coordinates in meters.
  """

  use Ecto.Migration

  def change do
    create table(:frames) do
      add(:analysis_id, references(:analyses, on_delete: :delete_all), null: false)
      add(:frame_index, :integer, null: false)
      add(:timestamp_ms, :integer, null: false)
      add(:image_landmarks, :map)
      add(:world_landmarks, :map)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:frames, [:analysis_id]))
    create(unique_index(:frames, [:analysis_id, :frame_index]))
  end
end
