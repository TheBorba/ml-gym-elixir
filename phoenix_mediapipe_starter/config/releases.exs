import Config

# For production, configure the database URL via DATABASE_URL environment variable.
# Exclude source code and test files from the release.
release :my_app do
  set version: "0.1.0"
  set distillery_relfile: "rel/config.exs"
  set cookie: System.get_env("PHX_COOKIE")
  set users: []

  # Remove distillery default calls to prevent the release from starting
  # automatically when using `mix release`.
  plugin MyApp.ReleasePlugins, :prod
end
