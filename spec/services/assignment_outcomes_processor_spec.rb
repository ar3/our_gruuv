require 'rails_helper'

RSpec.describe AssignmentOutcomesProcessor do
  let(:assignment) { create(:assignment) }

  describe '#initialize' do
    it 'stores assignment and outcomes text' do
      processor = described_class.new(assignment, "Outcome 1\nOutcome 2")
      expect(processor.assignment).to eq(assignment)
      expect(processor.outcomes_text).to eq("Outcome 1\nOutcome 2")
    end

    it 'converts nil to empty string' do
      processor = described_class.new(assignment, nil)
      expect(processor.outcomes_text).to eq('')
    end
  end

  describe '#process' do
    context 'with blank outcomes text' do
      it 'does nothing' do
        processor = described_class.new(assignment, '')
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(0)
        expect(processor.created_count).to eq(0)
        expect(processor.skipped_count).to eq(0)
      end

      it 'handles nil input' do
        processor = described_class.new(assignment, nil)
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(0)
      end
    end

    context 'with single outcome' do
      it 'creates a quantitative outcome' do
        processor = described_class.new(assignment, 'Increase customer satisfaction by 20%')
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(1)
        outcome = assignment.assignment_outcomes.first
        expect(outcome.description).to eq('Increase customer satisfaction by 20%')
        expect(outcome.outcome_type).to eq('quantitative')
        expect(processor.created_count).to eq(1)
        expect(processor.skipped_count).to eq(0)
      end

      it 'creates a sentiment outcome when contains agree:' do
        processor = described_class.new(assignment, 'Team agrees: We communicate clearly')
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(1)
        outcome = assignment.assignment_outcomes.first
        expect(outcome.description).to eq('Team agrees: We communicate clearly')
        expect(outcome.outcome_type).to eq('sentiment')
        expect(processor.created_count).to eq(1)
      end

      it 'creates a sentiment outcome when contains agrees:' do
        processor = described_class.new(assignment, 'Team agrees: We work efficiently')
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(1)
        outcome = assignment.assignment_outcomes.first
        expect(outcome.outcome_type).to eq('sentiment')
      end

      it 'is case-insensitive when detecting sentiment type' do
        processor = described_class.new(assignment, 'Team AGREES: We communicate clearly')
        processor.process

        outcome = assignment.assignment_outcomes.first
        expect(outcome.outcome_type).to eq('sentiment')
      end
    end

    context 'with multiple outcomes' do
      it 'creates all outcomes from newline-separated text' do
        text = "Increase customer satisfaction by 20%\nReduce response time to under 2 hours\nTeam agrees: We communicate clearly"
        processor = described_class.new(assignment, text)
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(3)
        expect(assignment.assignment_outcomes.pluck(:description)).to include(
          'Increase customer satisfaction by 20%',
          'Reduce response time to under 2 hours',
          'Team agrees: We communicate clearly'
        )
        expect(processor.created_count).to eq(3)
      end

      it 'ignores empty lines and whitespace' do
        text = "  \nIncrease customer satisfaction\n  \n\nReduce response time\n"
        processor = described_class.new(assignment, text)
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(2)
        expect(processor.created_count).to eq(2)
      end
    end

    context 'with existing outcomes' do
      it 'skips outcomes that already exist with exact same description' do
        # Create an existing outcome
        existing_outcome = create(:assignment_outcome,
          assignment: assignment,
          description: 'Increase customer satisfaction by 20%',
          outcome_type: 'quantitative',
          management_relationship_filter: 'direct_employee'
        )

        # Process outcomes including the existing one
        text = "Increase customer satisfaction by 20%\nReduce response time to under 2 hours"
        processor = described_class.new(assignment, text)
        processor.process

        # Should only create the new one
        expect(assignment.assignment_outcomes.count).to eq(2)
        expect(processor.created_count).to eq(1)
        expect(processor.skipped_count).to eq(1)

        # Verify existing outcome was not modified
        existing_outcome.reload
        expect(existing_outcome.management_relationship_filter).to eq('direct_employee')
      end

      it 'skips multiple existing outcomes' do
        create(:assignment_outcome, assignment: assignment, description: 'Outcome 1')
        create(:assignment_outcome, assignment: assignment, description: 'Outcome 2')

        text = "Outcome 1\nOutcome 2\nOutcome 3"
        processor = described_class.new(assignment, text)
        processor.process

        expect(assignment.assignment_outcomes.count).to eq(3)
        expect(processor.created_count).to eq(1)
        expect(processor.skipped_count).to eq(2)
      end

      it 'is case-sensitive when checking for existing outcomes' do
        create(:assignment_outcome, assignment: assignment, description: 'Outcome One')

        text = "Outcome One\noutcome one"
        processor = described_class.new(assignment, text)
        processor.process

        # "Outcome One" matches existing (skipped), "outcome one" is different (created)
        expect(assignment.assignment_outcomes.count).to eq(2)
        expect(processor.created_count).to eq(1)
        expect(processor.skipped_count).to eq(1)
      end
    end

    context 'with outcomes that have attributes' do
      it 'preserves existing outcome attributes when skipping' do
        existing = create(:assignment_outcome,
          assignment: assignment,
          description: 'Test outcome',
          outcome_type: 'quantitative',
          management_relationship_filter: 'direct_manager',
          team_relationship_filter: 'same_team',
          consumer_assignment_filter: 'active_consumer'
        )

        text = "Test outcome\nNew outcome"
        processor = described_class.new(assignment, text)
        processor.process

        # Existing outcome should be unchanged
        existing.reload
        expect(existing.management_relationship_filter).to eq('direct_manager')
        expect(existing.team_relationship_filter).to eq('same_team')
        expect(existing.consumer_assignment_filter).to eq('active_consumer')

        # New outcome should be created
        expect(assignment.assignment_outcomes.count).to eq(2)
        expect(processor.created_count).to eq(1)
        expect(processor.skipped_count).to eq(1)
      end
    end

    describe 'return values' do
      it 'tracks created and skipped counts' do
        create(:assignment_outcome, assignment: assignment, description: 'Existing')

        text = "Existing\nNew 1\nNew 2"
        processor = described_class.new(assignment, text)
        processor.process

        expect(processor.created_count).to eq(2)
        expect(processor.skipped_count).to eq(1)
      end
    end
  end
end
