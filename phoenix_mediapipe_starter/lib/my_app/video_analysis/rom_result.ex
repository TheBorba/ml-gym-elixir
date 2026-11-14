defmodule MyApp.RomResult do
  @moduledoc """
  Aggregated range-of-motion result for one analysis + joint + coordinate
  system.

  Written by `MyApp.VideoAnalysis.AnalysisWorker` after the Python worker
  finishes, using `MyApp.Biometrics.RomAccumulator` and
  `MyApp.Biometrics.RepDetector`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Analysis

  @coordinate_systems ~w(image_normalized world_3d)

  @type t :: %__MODULE__{}

  schema "rom_results" do
    field :joint, :string
    field :coordinate_system, :string
    field :sample_count, :integer, default: 0
    field :min_angle, :float
    field :max_angle, :float
    field :rom_degrees, :float
    field :repetitions, :integer, default: 0

    belongs_to :analysis, Analysis

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(analysis_id joint coordinate_system)a

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, @required ++ [:sample_count, :min_angle, :max_angle, :rom_degrees, :repetitions])
    |> validate_required(@required)
    |> validate_inclusion(:coordinate_system, @coordinate_systems)
    |> validate_number(:sample_count, greater_than_or_equal_to: 0)
    |> validate_number(:repetitions, greater_than_or_equal_to: 0)
    |> unique_constraint([:analysis_id, :joint, :coordinate_system])
    |> foreign_key_constraint(:analysis_id)
  end
end
