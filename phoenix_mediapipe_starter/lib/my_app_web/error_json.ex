defmodule MyAppWeb.ErrorJSON do
  @moduledoc """
  Renders JSON error bodies for status codes raised by the endpoint.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
