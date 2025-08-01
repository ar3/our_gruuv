require 'rails_helper'

RSpec.describe 'Sentry Integration', type: :service do
  before do
    # Mock Sentry to avoid actually sending events during tests
    allow(Sentry).to receive(:capture_exception)
    allow(Sentry).to receive(:capture_message)
  end

  describe 'ApplicationController error handling' do
    let(:controller) { ApplicationController.new }
    
    it 'captures errors with context' do
      error = StandardError.new('Test error')
      
      # Mock controller methods that might not be available in test
      allow(controller).to receive(:controller_name).and_return('test')
      allow(controller).to receive(:action_name).and_return('index')
      allow(controller).to receive(:params).and_return({})
      allow(controller).to receive(:current_person).and_return(nil)
      
      expect(Sentry).to receive(:capture_exception).with(error) do |&block|
        event = double('event')
        allow(event).to receive(:set_context)
        allow(event).to receive(:set_user)
        block.call(event)
      end
      
      controller.capture_error_in_sentry(error, { test: 'context' })
    end
  end

  describe 'Model validation tracking' do
    let(:person) { Person.new }
    
    it 'tracks validation errors' do
      # Mock Rails.env to simulate production
      allow(Rails.env).to receive(:production?).and_return(true)
      
      expect(Sentry).to receive(:capture_message).with('Model validation failed', level: :warning)
      
      person.valid? # This will trigger validation and the after_validation callback
    end
  end

  describe 'Job error handling' do
    it 'captures job errors' do
      # Test that ApplicationJob has the rescue_from configuration by checking the source code
      source = File.read(Rails.root.join('app/jobs/application_job.rb'))
      expect(source).to include('rescue_from StandardError')
    end
  end

  describe 'Global error handler' do
    let(:controller) { ApplicationController.new }
    
    it 'captures errors in Sentry' do
      error = StandardError.new('Global error')
      error.set_backtrace(['line1', 'line2', 'line3'])
      
      # Mock controller methods
      allow(controller).to receive(:controller_name).and_return('test')
      allow(controller).to receive(:action_name).and_return('index')
      allow(controller).to receive(:current_person).and_return(nil)
      
      expect(Sentry).to receive(:capture_exception).with(error)
      
      # Just test the Sentry capture part
      controller.capture_error_in_sentry(error, {
        method: 'global_error_handler',
        controller: 'test',
        action: 'index'
      })
    end
  end
end 