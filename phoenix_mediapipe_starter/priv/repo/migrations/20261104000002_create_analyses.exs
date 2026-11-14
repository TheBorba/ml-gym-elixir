defmodule MyApp.Repo.Migrations.CreateAnalyses do
  @moduledoc """
  One `analyses` row per processed MP4 upload.

  Status transitions: `pending -> processing -> completed | failed`, plus
  `cancelled` when the job is discarded.
  """

  use Ecto.Migration

  def change do
    create table(:analyses) do
      add(
        :assessment_session_id,
        references(:assessment_sessions, on_delete: :nilify_all)
      )

      add(:status, :string, null: false, default: "pending")
      add(:source, :string, null: false, default: "mp4")
      add(:video_path, :string, null: false)
      add(:model_path, :string, null: false)
      add(:sample_fps, :float)
      add(:source_fps, :float)
      add(:source_frames, :integer)
      add(:processed_frames, :integer, null: false, default: 0)
      add(:error, :text)
      add(:started_at, :utc_datetime_usec)
      add(:finished_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:analyses, [:assessment_session_id]))
    create(index(:analyses, [:status]))
  end
end
