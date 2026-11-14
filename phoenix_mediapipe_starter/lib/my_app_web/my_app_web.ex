defmodule MyAppWeb do
  @moduledoc """
  The entrypoint for defining the web interface for MyApp.

  This module defines the domain of the web application, including:
  - The Endpoint that serves HTTP requests
  - The Plug pipeline for routing and authentication
  - The LiveView and Controller bindings

  All modules in the `MyAppWeb` namespace are part of this interface.

  ## Usage

      defmodule MyAppWeb.WebcamLive do
        use MyAppWeb, :live_view
      end

      defmodule MyAppWeb.HealthController do
        use MyAppWeb, :controller
      end
  """

  @doc """
  Provides the bindings used by each kind of web module.

      use MyAppWeb, :live_view    # LiveView pages
      use MyAppWeb, :controller   # controllers
      use MyAppWeb, :router       # the router
      use MyAppWeb, :html         # HTML/component modules

  `:live_view` and `:html` import `MyAppWeb.CoreComponents`, so components such
  as `<.live_status />` are available in their templates.
  """
  defmacro __using__(:live_view) do
    quote do
      use Phoenix.LiveView, layout: false
      import MyAppWeb.CoreComponents
      alias MyAppWeb.Endpoint
    end
  end

  defmacro __using__(:controller) do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      import Plug.Conn
      alias MyAppWeb.Endpoint
    end
  end

  defmacro __using__(:router) do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller, only: [accepts: 2, put_secure_browser_headers: 2, redirect: 2]
      import Phoenix.LiveView.Router, only: [live: 3]
    end
  end

  defmacro __using__(:html) do
    quote do
      use Phoenix.Component
      import MyAppWeb.CoreComponents
    end
  end
end
