require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  # Create a simple test job class
  class TestJob < ApplicationJob
    def perform(test_arg)
      { success: true, test_arg: test_arg, message: "Job executed successfully" }
    end
  end

  describe 'job execution methods' do
    it 'demonstrates the difference between perform_now and perform_and_get_result' do
      # Test the helper method - should return the actual result
      result = TestJob.perform_and_get_result("test_value")
      expect(result).to eq({
        success: true,
        test_arg: "test_value",
        message: "Job executed successfully"
      })

      # Test perform_now - may return SentryLogger or other framework object
      perform_now_result = TestJob.perform_now("test_value")
      
      # perform_now might not return the actual result due to Active Job framework interference
      # This is the issue you were experiencing in production
      expect(perform_now_result).not_to eq({
        success: true,
        test_arg: "test_value",
        message: "Job executed successfully"
      })
    end

    it 'shows that perform_and_get_result bypasses Active Job framework' do
      result = TestJob.perform_and_get_result("bypass_test")
      
      expect(result).to be_a(Hash)
      expect(result[:success]).to be true
      expect(result[:test_arg]).to eq("bypass_test")
    end
  end
end 