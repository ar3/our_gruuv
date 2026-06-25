require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  # Create a simple test job class
  class TestJob < ApplicationJob
    def perform(test_arg)
      { success: true, test_arg: test_arg, message: "Job executed successfully" }
    end
  end

  class KeywordArgTestJob < ApplicationJob
    def perform(first_arg, second_arg = nil, third_arg = nil, existing_id: nil)
      { first_arg: first_arg, second_arg: second_arg, third_arg: third_arg, existing_id: existing_id }
    end
  end

  describe 'job execution methods' do
    it 'demonstrates the difference between perform_now and perform_and_get_result' do
      # perform_and_get_result is the reliable way to get the return value of perform
      result = TestJob.perform_and_get_result("test_value")
      expect(result).to eq({
        success: true,
        test_arg: "test_value",
        message: "Job executed successfully"
      })

      # perform_now behavior is adapter-dependent (e.g. :test may return the value; async adapters do not)
      perform_now_result = TestJob.perform_now("test_value")
      expect(perform_now_result).to be_present
    end

    it 'shows that perform_and_get_result bypasses Active Job framework' do
      result = TestJob.perform_and_get_result("bypass_test")
      
      expect(result).to be_a(Hash)
      expect(result[:success]).to be true
      expect(result[:test_arg]).to eq("bypass_test")
    end

    it 'forwards keyword arguments to perform' do
      result = KeywordArgTestJob.perform_and_get_result(1, [], nil, existing_id: 42)

      expect(result).to eq({
        first_arg: 1,
        second_arg: [],
        third_arg: nil,
        existing_id: 42
      })
    end
  end
end
