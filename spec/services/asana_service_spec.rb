require 'rails_helper'

RSpec.describe AsanaService do
  describe '.task_url' do
    it 'generates task URL with project ID' do
      url = AsanaService.task_url('123456789', '987654321')
      expect(url).to eq('https://app.asana.com/0/987654321/123456789')
    end

    it 'generates task URL without project ID' do
      url = AsanaService.task_url('123456789')
      expect(url).to eq('https://app.asana.com/0/0/123456789')
    end

    it 'generates task URL with nil project ID' do
      url = AsanaService.task_url('123456789', nil)
      expect(url).to eq('https://app.asana.com/0/0/123456789')
    end
  end
end

