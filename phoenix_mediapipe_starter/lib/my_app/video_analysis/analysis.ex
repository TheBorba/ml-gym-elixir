defmodule MyApp.Analysis do
  @moduledoc """
  One processed video (an MP4 upload) and its pipeline state.

  The row is created in `pending` state when the upload is saved, flipped to
  `processing` by `MyApp.VideoAnalysis.AnalysisWorker`, and finished as
  `completed` or `failed`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.{AssessmentSession, Frame, Measurement, RomResult}

  @statuses ~w(pending processing completed failed cancelled)

  @type t :: %__MODULE__{}

  schema "analyses" do
    field(:status, :string, default: "pending")
    field(:source, :string, default: "mp4")
    field(:video_path, :string)
    field(:model_path, :string)
    field(:sample_fps, :float)
    field(:source_fps, :float)
    field(:source_frames, :integer)
    field(:processed_frames, :integer, default: 0)
    field(:error, :string)
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)

    belongs_to(:assessment_session, AssessmentSession)
    has_many(:frames, Frame)
    has_many(:measurements, Measurement)
    has_many(:rom_results, RomResult)

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(video_path model_path)a
  @optional ~w(assessment_session_id status source sample_fps)a

  @doc """
  Changeset used when enqueueing a new analysis job.
  """
  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:sample_fps, greater_than: 0)
    |> foreign_key_constraint(:assessment_session_id)
  end

  @doc """
  Changeset for pipeline state transitions.
  """
  def status_changeset(analysis, status, extra \\ []) when status in @statuses do
    analysis
    |> cast(Map.new(extra) |> Map.put(:status, status), [
      :status,
      :processed_frames,
      :source_fps,
      :source_frames,
      :error,
      :started_at,
      :finished_at
    ])
    |> validate_required(:status)
    |> validate_inclusion(:status, @statuses)
  end
end
