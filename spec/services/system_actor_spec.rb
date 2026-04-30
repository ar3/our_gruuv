require 'rails_helper'

RSpec.describe SystemActor do
  describe '.person' do
    it 'creates a reusable automation person when missing' do
      person = described_class.person

      expect(person).to be_persisted
      expect(person.email).to eq('automation@og.local')
      expect(person.first_name).to eq('OG')
      expect(person.last_name).to eq('Automation')
    end

    it 'returns the same person on subsequent calls' do
      first = described_class.person
      second = described_class.person

      expect(second.id).to eq(first.id)
    end
  end
end
