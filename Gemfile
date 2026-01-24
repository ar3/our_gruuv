source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# HAML templating engine for Rails
gem "haml-rails"

# Pagination gem - fast and lightweight
gem 'pagy', '~> 6.0'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mingw x64_mingw jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Error tracking with Sentry
gem "sentry-ruby", "~> 5.0"
gem "sentry-rails", "~> 5.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mingw x64_mingw ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  # Code coverage analysis
  gem "simplecov", "~> 0.21", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  
  # HAML linting for consistent view formatting
  gem "haml-lint", require: false
  
  # Detect N+1 queries and unused eager loading
  gem "bullet", require: false
  
  # Code quality analysis
  gem "rubycritic", "~> 4.7", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  
  # Database cleaning for system tests
  gem "database_cleaner-active_record"
end

gem "rspec-rails", "~> 8.0", groups: [:development, :test]

gem "shoulda-matchers", "~> 6.5", group: :test
gem "factory_bot_rails", "~> 6.4", group: :test

gem "pry", "~> 0.15.2", groups: [:development, :test]
gem "pry-rails", "~> 0.3.11", groups: [:development, :test]
gem "pry-byebug", "~> 3.11", groups: [:development, :test]

gem "rails-controller-testing", "~> 1.0", group: :test
gem "rack_session_access", "~> 0.2", group: :test
gem "pundit", "~> 2.5"
gem "draper", "~> 4.0"

# Form validation with Reform and dry-validation
gem "reform"
gem "reform-rails"
gem "dry-validation", "~> 1.11"
gem "dry-schema", "~> 1.11"

# Slack API integration
gem "slack-ruby-client", "~> 3.1"

# HTTP client for API requests
gem "http", "~> 5.0"

# AWS SDK for S3 storage
gem "aws-sdk-s3", "~> 1.0"

# Environment variables
gem "dotenv-rails", "~> 3.1"

# Excel file parsing for data uploads
gem "roo", "~> 2.10"
gem "creek", "~> 2.0"
gem "csv", "~> 3.2"

# Markdown rendering
gem "redcarpet", "~> 3.6"

# OAuth authentication
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"

gem "paper_trail", "~> 16.0"

# Full-text search with PostgreSQL
gem "pg_search", "~> 2.3"
