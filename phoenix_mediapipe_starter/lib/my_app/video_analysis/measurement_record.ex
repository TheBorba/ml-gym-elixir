defmodule MyApp.Measurement do
  @moduledoc """
  A single joint-angle sample derived from one frame.

  `joint` uses the same naming as `MyApp.Biometrics.Measurement`, e.g.
  `"left_knee"` or `"right_elbow"`.

  `angle_degrees` is `nil` when the underlying landmarks failed the quality
  gate (low visibility); `quality` then records `"insufficient"`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.{Analysis, Frame}

  @coordinate_systems ~w(image_normalized world_3d)
  @qualities ~w(usable insufficient)

  @type t :: %__MODULE__{}

  schema "measurements" do
    field :joint, :string
    field :coordinate_system, :string
    field :quality, :string, default: "usable"
    field :angle_degrees, :float
    field :timestamp_ms, :integer

    belongs_to :analysis, Analysis
    belongs_to :frame, Frame

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required ~w(analysis_id frame_id joint coordinate_system timestamp_ms)a

  @doc false
  def changeset(measurement, attrs) do
    measurement
    |> cast(attrs, @required ++ [:quality, :angle_degrees])
    |> validate_required(@required)
    |> validate_inclusion(:coordinate_system, @coordinate_systems)
    |> validate_inclusion(:quality, @qualities)
    |> foreign_key_constraint(:analysis_id)
    |> foreign_key_constraint(:frame_id)
  end
end
