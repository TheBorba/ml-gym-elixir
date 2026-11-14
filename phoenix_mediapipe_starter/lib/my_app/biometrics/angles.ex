defmodule MyApp.Biometrics.Angles do
  @moduledoc "Vector-based joint angle calculations."
  alias MyApp.Biometrics.Landmark

  @doc """
  Calculates the interior angle at point B, in degrees.
  All landmarks must use the same coordinate system.
  Returns nil for missing, invalid, or degenerate geometry.
  """
  def calculate(%Landmark{} = a, %Landmark{} = b, %Landmark{} = c) do
    with true <- same_coordinates?(a, b, c),
         {:ok, v1} <- vector(a, b),
         {:ok, v2} <- vector(c, b),
         mag1 when mag1 > 1.0e-10 <- magnitude(v1),
         mag2 when mag2 > 1.0e-10 <- magnitude(v2) do
      cosine = (dot(v1, v2) / (mag1 * mag2)) |> max(-1.0) |> min(1.0)
      cosine |> :math.acos() |> Kernel.*(180.0 / :math.pi()) |> Float.round(2)
    else
      _ -> nil
    end
  end

  def calculate(_, _, _), do: nil

  defp same_coordinates?(a, b, c) do
    a.coordinate_system == b.coordinate_system and b.coordinate_system == c.coordinate_system
  end

  defp vector(a, b) do
    z =
      if a.coordinate_system == :world_3d do
        if is_number(a.z) and is_number(b.z), do: a.z - b.z, else: :missing
      else
        0.0
      end

    if is_number(z), do: {:ok, [a.x - b.x, a.y - b.y, z]}, else: :error
  end

  defp dot(a, b), do: Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
  defp magnitude(v), do: v |> Enum.reduce(0.0, fn x, acc -> acc + x * x end) |> :math.sqrt()
end
