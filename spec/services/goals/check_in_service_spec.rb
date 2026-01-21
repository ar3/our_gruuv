require 'rails_helper'

RSpec.describe Goals::CheckInService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:week_start) { Date.current.beginning_of_week(:monday) }
  
  let(:goal) do
    create(:goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      most_likely_target_date: Date.today + 1.month
    )
  end

  describe '#call' do
    context 'when creating a new check-in' do
      it 'creates a new check-in for the current week' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          confidence_reason: 'Making good progress'
        )

        expect(result.ok?).to be true
        check_in = result.value[:check_in]
        expect(check_in).to be_persisted
        expect(check_in.goal).to eq(goal)
        expect(check_in.check_in_week_start).to eq(week_start)
        expect(check_in.confidence_percentage).to eq(75)
        expect(check_in.confidence_reason).to eq('Making good progress')
        expect(check_in.confidence_reporter).to eq(person)
      end

      it 'creates a check-in with only confidence' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 65
        )

        expect(result.ok?).to be true
        check_in = result.value[:check_in]
        expect(check_in.confidence_percentage).to eq(65)
        expect(check_in.confidence_reason).to be_nil
      end

      it 'creates a check-in with only reason' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_reason: 'Reason only'
        )

        expect(result.ok?).to be(true), "Expected success but got error: #{result.error}"
        check_in = result.value[:check_in]
        expect(check_in.confidence_reason).to eq('Reason only')
      end
    end

    context 'when updating an existing check-in' do
      let!(:existing_check_in) do
        create(:goal_check_in,
          goal: goal,
          check_in_week_start: week_start,
          confidence_percentage: 50,
          confidence_reason: 'Old reason',
          confidence_reporter: person
        )
      end

      it 'updates the existing check-in' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 80,
          confidence_reason: 'New reason'
        )

        expect(result.ok?).to be true
        expect(result.value[:check_in].id).to eq(existing_check_in.id)
        existing_check_in.reload
        expect(existing_check_in.confidence_percentage).to eq(80)
        expect(existing_check_in.confidence_reason).to eq('New reason')
      end
    end

    context 'when goal has not been started' do
      it 'starts the goal after successful check-in save' do
        expect(goal.started_at).to be_nil

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.started_at).to be_present
      end

      it 'starts the goal even if only reason is provided' do
        expect(goal.started_at).to be_nil

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_reason: 'Starting work'
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.started_at).to be_present
      end
    end

    context 'when goal has already been started' do
      let(:started_goal) do
        create(:goal,
          creator: teammate,
          owner: teammate,
          company: organization,
          started_at: 1.week.ago,
          most_likely_target_date: Date.today + 1.month
        )
      end

      it 'does not change the started_at timestamp' do
        original_started_at = started_goal.started_at

        result = described_class.call(
          goal: started_goal,
          current_person: person,
          confidence_percentage: 75
        )

        expect(result.ok?).to be true
        started_goal.reload
        expect(started_goal.started_at).to eq(original_started_at)
      end
    end

    context 'when auto-completing goal' do
      # Note: 0% and 100% are no longer available in the UI dropdowns,
      # but the service still supports these values programmatically (e.g., when marking goals as done)
      it 'auto-completes goal when confidence is 0%' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 0,
          confidence_reason: 'Not happening'
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.completed_at).to be_present
      end

      it 'auto-completes goal when confidence is 100%' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 100,
          confidence_reason: 'Done!'
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.completed_at).to be_present
      end

      it 'does not auto-complete goal when confidence is not 0% or 100%' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 50
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.completed_at).to be_nil
      end

      it 'does not auto-complete goal that is already completed' do
        goal.update!(completed_at: 1.day.ago)
        original_completed_at = goal.completed_at

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 100
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.completed_at).to eq(original_completed_at)
      end
    end

    context 'when updating target date' do
      it 'updates most_likely_target_date when provided' do
        new_target_date = Date.today + 60.days
        goal.update!(
          earliest_target_date: nil,
          most_likely_target_date: Date.today + 30.days,
          latest_target_date: nil
        )

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          most_likely_target_date: new_target_date.to_s
        )

        expect(result.ok?).to be true
        expect(result.value[:target_date_updated]).to be true
        goal.reload
        expect(goal.most_likely_target_date).to eq(new_target_date)
      end

      it 'updates latest_target_date to be at least one day after new target date if latest is set' do
        goal.update!(
          earliest_target_date: nil,
          most_likely_target_date: Date.today + 30.days,
          latest_target_date: Date.today + 60.days
        )
        new_target_date = Date.today + 70.days

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          most_likely_target_date: new_target_date.to_s
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.most_likely_target_date).to eq(new_target_date)
        expect(goal.latest_target_date).to eq(new_target_date + 1.day)
      end

      it 'updates earliest_target_date if new target date is before existing earliest' do
        original_earliest = Date.today + 20.days
        goal.update!(
          earliest_target_date: original_earliest,
          most_likely_target_date: Date.today + 30.days,
          latest_target_date: Date.today + 60.days
        )
        new_target_date = Date.today + 15.days

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          most_likely_target_date: new_target_date.to_s
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.most_likely_target_date).to eq(new_target_date)
        expect(goal.earliest_target_date).to eq(new_target_date)
      end
    end

    context 'when creating observable moments' do
      context 'when confidence changed significantly' do
        let!(:previous_check_in) do
          create(:goal_check_in,
            goal: goal,
            confidence_percentage: 50,
            check_in_week_start: week_start - 1.week,
            confidence_reporter: person
          )
        end

        it 'creates observable moment when confidence increased by 25 points' do
          expect {
            described_class.call(
              goal: goal,
              current_person: person,
              confidence_percentage: 75,
              confidence_reason: 'Making good progress'
            )
          }.to change { ObservableMoment.count }.by(1)

          moment = ObservableMoment.last
          expect(moment.moment_type).to eq('goal_check_in')
          expect(moment.metadata['confidence_delta']).to eq(25)
        end
      end

      context 'when confidence changed by less than 20 points' do
        let!(:previous_check_in) do
          create(:goal_check_in,
            goal: goal,
            confidence_percentage: 50,
            check_in_week_start: week_start - 1.week,
            confidence_reporter: person
          )
        end

        it 'does not create observable moment when change is only 15 points' do
          expect {
            described_class.call(
              goal: goal,
              current_person: person,
              confidence_percentage: 65,
              confidence_reason: 'Making good progress'
            )
          }.not_to change { ObservableMoment.count }
        end
      end
    end

    context 'when using custom week_start' do
      let(:custom_week_start) { 2.weeks.ago.beginning_of_week(:monday) }

      it 'creates check-in for the specified week' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          week_start: custom_week_start
        )

        expect(result.ok?).to be true
        check_in = result.value[:check_in]
        expect(check_in.check_in_week_start).to eq(custom_week_start)
      end
    end

    context 'when check-in validation fails' do
      it 'returns error when check-in is invalid' do
        # Create a check-in for the same week to trigger uniqueness validation
        create(:goal_check_in,
          goal: goal,
          check_in_week_start: week_start,
          confidence_percentage: 50
        )

        # Try to create another with invalid data that would fail validation
        # Actually, the find_or_initialize_by will find the existing one, so let's test with invalid confidence
        invalid_goal = create(:goal,
          creator: teammate,
          owner: teammate,
          company: organization,
          most_likely_target_date: Date.today + 1.month
        )

        result = described_class.call(
          goal: invalid_goal,
          current_person: person,
          confidence_percentage: 150  # Invalid: out of range
        )

        expect(result.ok?).to be false
        expect(result.error).to be_present
      end
    end

    context 'when date parsing fails' do
      it 'returns error for invalid date format' do
        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75,
          most_likely_target_date: 'invalid-date'
        )

        expect(result.ok?).to be false
        expect(result.error).to include('Invalid date format')
      end
    end

    context 'when goal is completed' do
      it 'still allows check-in but does not change completed_at' do
        goal.update!(completed_at: 1.day.ago)
        original_completed_at = goal.completed_at

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 75
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.completed_at).to eq(original_completed_at)
      end
    end

    context 'when starting goal and auto-completing in same check-in' do
      it 'starts the goal and then auto-completes it' do
        expect(goal.started_at).to be_nil
        expect(goal.completed_at).to be_nil

        result = described_class.call(
          goal: goal,
          current_person: person,
          confidence_percentage: 100
        )

        expect(result.ok?).to be true
        goal.reload
        expect(goal.started_at).to be_present
        expect(goal.completed_at).to be_present
      end
    end
  end
end
