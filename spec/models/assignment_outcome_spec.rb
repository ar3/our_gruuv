require 'rails_helper'

RSpec.describe AssignmentOutcome, type: :model do
  let(:assignment) { create(:assignment) }
  let(:outcome) { create(:assignment_outcome, assignment: assignment) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(outcome).to be_valid
    end

    it 'requires description' do
      outcome.description = nil
      expect(outcome).not_to be_valid
    end

    it 'requires assignment' do
      outcome.assignment = nil
      expect(outcome).not_to be_valid
    end

    it 'requires outcome_type' do
      outcome.outcome_type = nil
      expect(outcome).not_to be_valid
    end

    it 'validates outcome_type inclusion' do
      outcome.outcome_type = 'invalid_type'
      expect(outcome).not_to be_valid
      expect(outcome.errors[:outcome_type]).to include('is not included in the list')
    end

    it 'accepts quantitative outcome_type' do
      outcome.outcome_type = 'quantitative'
      expect(outcome).to be_valid
    end

    it 'accepts sentiment outcome_type' do
      outcome.outcome_type = 'sentiment'
      expect(outcome).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to an assignment' do
      expect(outcome.assignment).to eq(assignment)
    end
  end

  describe 'constants' do
    it 'defines TYPES constant' do
      expect(AssignmentOutcome::TYPES).to eq(%w[quantitative sentiment])
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(outcome.display_name).to eq(outcome.description)
    end
  end

  describe 'factory traits' do
    it 'creates quantitative outcome with trait' do
      quantitative_outcome = create(:assignment_outcome, :quantitative)
      expect(quantitative_outcome.outcome_type).to eq('quantitative')
      expect(quantitative_outcome.description).to include('response time')
    end

    it 'creates sentiment outcome with trait' do
      sentiment_outcome = create(:assignment_outcome, :sentiment)
      expect(sentiment_outcome.outcome_type).to eq('sentiment')
      expect(sentiment_outcome.description).to include('agrees')
    end
  end
end
