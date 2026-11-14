defmodule MyAppWeb.ErrorHTML do
  @moduledoc """
  Renders HTML error pages for status codes raised by the endpoint.

  Uses the status message for the template name (e.g. `404.html` renders
  `"Not Found"`), which matches the Phoenix 1.7+ error view convention.
  """

  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
