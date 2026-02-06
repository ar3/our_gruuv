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

    it 'validates management_relationship_filter inclusion' do
      outcome.management_relationship_filter = 'invalid'
      expect(outcome).not_to be_valid
      expect(outcome.errors[:management_relationship_filter]).to include('is not included in the list')
    end

    it 'accepts valid management_relationship_filter values' do
      %w[direct_employee direct_manager no_relationship].each do |value|
        outcome.management_relationship_filter = value
        expect(outcome).to be_valid
      end
    end

    it 'allows nil management_relationship_filter' do
      outcome.management_relationship_filter = nil
      expect(outcome).to be_valid
    end

    it 'allows empty string management_relationship_filter' do
      outcome.management_relationship_filter = ''
      expect(outcome).to be_valid
    end

    it 'validates team_relationship_filter inclusion' do
      outcome.team_relationship_filter = 'invalid'
      expect(outcome).not_to be_valid
      expect(outcome.errors[:team_relationship_filter]).to include('is not included in the list')
    end

    it 'accepts valid team_relationship_filter values' do
      %w[same_team different_team].each do |value|
        outcome.team_relationship_filter = value
        expect(outcome).to be_valid
      end
    end

    it 'allows nil team_relationship_filter' do
      outcome.team_relationship_filter = nil
      expect(outcome).to be_valid
    end

    it 'allows empty string team_relationship_filter' do
      outcome.team_relationship_filter = ''
      expect(outcome).to be_valid
    end

    it 'validates consumer_assignment_filter inclusion' do
      outcome.consumer_assignment_filter = 'invalid'
      expect(outcome).not_to be_valid
      expect(outcome.errors[:consumer_assignment_filter]).to include('is not included in the list')
    end

    it 'accepts valid consumer_assignment_filter values' do
      %w[active_consumer not_consumer].each do |value|
        outcome.consumer_assignment_filter = value
        expect(outcome).to be_valid
      end
    end

    it 'allows nil consumer_assignment_filter' do
      outcome.consumer_assignment_filter = nil
      expect(outcome).to be_valid
    end

    it 'allows empty string consumer_assignment_filter' do
      outcome.consumer_assignment_filter = ''
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

    describe '#has_additional_configuration?' do
      it 'returns false when no additional config fields are set' do
        outcome.update!(progress_report_url: nil, management_relationship_filter: nil, team_relationship_filter: nil, consumer_assignment_filter: nil)
        expect(outcome.has_additional_configuration?).to be false
      end

      it 'returns true when progress_report_url is set' do
        outcome.update!(progress_report_url: 'https://example.com/report')
        expect(outcome.has_additional_configuration?).to be true
      end

      it 'returns true when management_relationship_filter is set' do
        outcome.update!(management_relationship_filter: 'direct_employee')
        expect(outcome.has_additional_configuration?).to be true
      end

      it 'returns true when team_relationship_filter is set' do
        outcome.update!(team_relationship_filter: 'same_team')
        expect(outcome.has_additional_configuration?).to be true
      end

      it 'returns true when consumer_assignment_filter is set' do
        outcome.update!(consumer_assignment_filter: 'active_consumer')
        expect(outcome.has_additional_configuration?).to be true
      end
    end

    describe '#additional_configuration_badge_label' do
      it 'returns "Add add\'l config" when no config is set' do
        outcome.update!(progress_report_url: nil, management_relationship_filter: nil, team_relationship_filter: nil, consumer_assignment_filter: nil)
        expect(outcome.additional_configuration_badge_label).to eq("Add add'l config")
      end

      it 'returns "Modify/View add\'l config" when any config is set' do
        outcome.update!(progress_report_url: 'https://example.com')
        expect(outcome.additional_configuration_badge_label).to eq("Modify/View add'l config")
      end
    end

    describe '#extract_quoted_content' do
      it 'extracts content from double quotes' do
        outcome.description = 'Team agrees: "We communicate clearly and frequently"'
        expect(outcome.extract_quoted_content).to eq('We communicate clearly and frequently')
      end

      it 'extracts content from single quotes' do
        outcome.description = "Team agrees: 'We communicate clearly and frequently'"
        expect(outcome.extract_quoted_content).to eq('We communicate clearly and frequently')
      end

      it 'returns nil if no quotes found' do
        outcome.description = 'Team agrees: We communicate clearly and frequently'
        expect(outcome.extract_quoted_content).to be_nil
      end

      it 'returns nil if description is blank' do
        outcome.description = nil
        expect(outcome.extract_quoted_content).to be_nil
      end

      it 'returns first quoted content if multiple quotes exist' do
        outcome.description = 'First: "First quote" and second: "Second quote"'
        expect(outcome.extract_quoted_content).to eq('First quote')
      end
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
