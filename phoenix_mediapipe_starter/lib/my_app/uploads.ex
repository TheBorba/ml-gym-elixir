defmodule MyApp.Uploads do
  @moduledoc """
  Private storage for uploaded videos.

  Files are written under `priv/uploads` (configurable via `UPLOAD_DIR`),
  which is deliberately *not* served by `Plug.Static` — uploads must never be
  publicly reachable. In production, swap `store/2` for object storage with
  signed URLs.
  """

  @doc """
  Absolute path of the upload directory, created if missing.
  """
  def dir do
    dir =
      :my_app
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:dir, "priv/uploads")
      |> Path.expand()

    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Stores a `%Plug.Upload{}` (or any path/name pair) and returns the absolute
  destination path.

  The stored filename is namespaced by a random token so concurrent uploads
  of the same original name never collide, and the extension is preserved
  for MediaPipe's decoder.
  """
  def store(%Plug.Upload{path: source, filename: filename}) do
    destination =
      Path.join(
        dir(),
        "#{Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)}#{ext(filename)}"
      )

    File.cp!(source, destination)
    {:ok, destination}
  end

  @doc """
  Removes a previously stored upload. Missing files are treated as success.
  """
  def delete(path) when is_binary(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ext(filename) do
    case Path.extname(filename || "") do
      "" -> ".mp4"
      extension -> String.downcase(extension)
    end
  end
end
