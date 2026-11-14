defmodule MyApp.Repo.Migrations.CreateAssessmentSessions do
  @moduledoc """
  An `assessment_sessions` row groups one or more analyses (e.g. several
  camera angles of the same squat set) for a single subject.

  `patient_ref` is a pseudonymous external reference. No direct identifiers
  are stored.
  """

  use Ecto.Migration

  def change do
    create table(:assessment_sessions) do
      add(:patient_ref, :string)
      add(:notes, :text)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:assessment_sessions, [:patient_ref]))
  end
end
