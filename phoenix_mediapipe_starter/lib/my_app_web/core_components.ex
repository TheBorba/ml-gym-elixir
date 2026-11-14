defmodule MyAppWeb.CoreComponents do
  @moduledoc """
  Shared LiveView components for the MyApp web interface.

  This module provides reusable LiveView components that are used across the
  application, including:
  - `live_status/1` — a status indicator that shows the current state of a
    LiveView or LiveSocket operation
  - `live_error/1` — an error display component for showing server-side errors
  - `live_action/1` — a helper for accessing the current LiveView action

  These components are used in LiveView templates to provide consistent
  UX patterns across the webcam and video upload interfaces.

  ## Usage

  Components are used in LiveView templates via the `<.component_name/>`
  syntax:

      <.status status={@status} />
  """

  use Phoenix.Component

  @doc """
  Renders a status indicator for LiveView or LiveSocket operations.

  The status is displayed as a colored badge with a label.

  ## Examples

      <.status status="ready" label="Ready" />
      <.status status="processing" label="Processing..." />
      <.status status="error" label="Error" />
  """
  attr :status, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: "mb-2"
  slot :inner_block, required: false

  def live_status(assigns) do
    ~H"""
    <div class={@class}>
      <span class={
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium gap-1.5 " <>
        case @status do
          "ready" -> "bg-green-100 text-green-800"
          "processing" -> "bg-yellow-100 text-yellow-800"
          "error" -> "bg-red-100 text-red-800"
          "success" -> "bg-blue-100 text-blue-800"
          _ -> "bg-gray-100 text-gray-800"
        end
      }>
        <%= @label %>
      </span>
    </div>
    """
  end

  @doc """
  Renders an error display for server-side errors returned from LiveView events.

  ## Examples

      <.error kind={@error_kind} error={@error} />
  """
  attr :kind, :string, default: "error"
  attr :error, :string, default: ""
  attr :class, :string, default: "mb-2"

  def live_error(assigns) do
    ~H"""
    <div class={@class <> " text-sm"}>
      <%= if @error != "" do %>
        <div class="bg-red-50 border border-red-200 text-red-700 px-3 py-2 rounded">
          <span class="font-medium">Error:</span>
          <%= @error %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a file upload dropzone for the video upload LiveView.

  The dropzone provides a visual cue for dragging and dropping files,
  and accepts clicks for users who prefer browsing.

  ## Examples

      <.dropzone
        id="video-upload"
        label="Drop your MP4 video here or click to browse"
        accept="video/mp4,video/x-m4v,video/quicktime"
      />
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :accept, :string, default: "video/mp4,video/x-m4v,video/quicktime"

  attr :target, :string,
    default: nil,
    doc: "the upload ref this dropzone belongs to (`@uploads.<name>.ref`)"

  attr :class, :string,
    default:
      "border-2 border-dashed border-gray-300 rounded-lg p-8 text-center cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-colors"

  slot :inner_block, required: false

  def live_dropzone(assigns) do
    ~H"""
    <div
      id={@id}
      class={@class}
      phx-drop-target={@target || @id}
    >

      <div class="text-sm text-gray-500 mb-2">
        <%= @label %>
      </div>
      <span class="text-xs text-gray-400">
        Accepts: <%= @accept %>
      </span>
    </div>
    """
  end

  @doc """
  Renders a progress bar for displaying the current progress of an operation.

  ## Examples

      <.progress value={0.65} label="Processing video..." />
  """
  attr :value, :float, required: true
  attr :max, :float, default: 1.0
  attr :label, :string, default: ""
  attr :class, :string, default: "w-full"

  def live_progress(assigns) do
    ~H"""
    <div class={"mb-2 #{@class}"}>
      <div class="flex items-center justify-between text-sm mb-1">
        <span class="font-medium text-gray-700"><%= @label %></span>
        <span class="text-gray-500"><%= Float.round(@value / @max * 100, 1) %>%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2.5">
        <div
          class="bg-blue-600 h-2.5 rounded-full transition-all duration-300"
          style={"width: #{Float.round(@value / @max * 100, 1)}%"}
        ></div>
      </div>
    </div>
    """
  end
end
