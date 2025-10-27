require_relative "boot"

require "rails/all"

# Load environment variables from .env file
require 'dotenv-rails'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OurGruuv
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks scripts])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Set default URL options for the application
    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: ENV.fetch('RAILS_HOST', 'localhost'),
        protocol: ENV.fetch('RAILS_ACTION_MAILER_DEFAULT_URL_PROTOCOL', 'http')
      }
    end
  end
end
