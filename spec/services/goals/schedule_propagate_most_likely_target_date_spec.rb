# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::SchedulePropagateMostLikelyTargetDate, type: :model do
  let(:company) { create(:organization) }
  let(:creator_teammate) { CompanyTeammate.find(create(:teammate, organization: company).id) }
  let(:parent_date) { Date.current + 90.days }
  let(:wide_earliest) { Date.current }
  let(:wide_latest) { Date.current + 2.years }

  describe '.call' do
    it 'runs propagation synchronously when most_likely_target_date changed on last save' do
      goal = create(:goal, :quantitative_key_result, creator: creator_teammate, owner: creator_teammate,
        earliest_target_date: wide_earliest, latest_target_date: wide_latest,
        most_likely_target_date: parent_date, started_at: Time.current)

      goal.update!(most_likely_target_date: parent_date + 30.days)

      expect(Goals::PropagateMostLikelyTargetDateJob).to receive(:perform_now).with(goal.id).and_call_original

      Goals::SchedulePropagateMostLikelyTargetDate.call(goal)
    end

    it 'does not call the job when most_likely_target_date did not change on last save' do
      goal = create(:goal, :quantitative_key_result, creator: creator_teammate, owner: creator_teammate,
        earliest_target_date: wide_earliest, latest_target_date: wide_latest,
        most_likely_target_date: parent_date, started_at: Time.current)

      goal.update!(title: 'Renamed only')

      expect(Goals::PropagateMostLikelyTargetDateJob).not_to receive(:perform_now)

      Goals::SchedulePropagateMostLikelyTargetDate.call(goal)
    end

    it 'does not call the job when the last save was the initial insert' do
      goal = build(:goal, :quantitative_key_result, creator: creator_teammate, owner: creator_teammate,
        earliest_target_date: wide_earliest, latest_target_date: wide_latest,
        most_likely_target_date: parent_date, started_at: Time.current)

      expect(Goals::PropagateMostLikelyTargetDateJob).not_to receive(:perform_now)

      goal.save!
      Goals::SchedulePropagateMostLikelyTargetDate.call(goal)
    end
  end
end
