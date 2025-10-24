# spec/enm/spec_helper.rb
# ENM-specific RSpec configuration

require_relative '../rails_helper'

# ENM-specific configuration
RSpec.configure do |config|
  # Tag all ENM specs
  config.define_derived_metadata(file_path: %r{/spec/enm/}) do |metadata|
    metadata[:enm] = true
  end

  # ENM-specific before hooks
  config.before(:each, enm: true) do
    # Any ENM-specific setup can go here
  end

  # ENM-specific after hooks
  config.after(:each, enm: true) do
    # Any ENM-specific cleanup can go here
  end
end
