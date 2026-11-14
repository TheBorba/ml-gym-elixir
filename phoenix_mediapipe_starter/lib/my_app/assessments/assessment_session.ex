defmodule MyApp.AssessmentSession do
  @moduledoc """
  A group of analyses belonging to one subject.

  `patient_ref` is a pseudonymous identifier (e.g. a study code). Do not
  store names, dates of birth, or other direct identifiers here.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Analysis

  @type t :: %__MODULE__{}

  schema "assessment_sessions" do
    field(:patient_ref, :string)
    field(:notes, :string)

    has_many(:analyses, Analysis, foreign_key: :assessment_session_id)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:patient_ref, :notes])
    |> validate_length(:patient_ref, max: 128)
    |> validate_length(:notes, max: 5_000)
  end
end
