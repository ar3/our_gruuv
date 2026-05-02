# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::PropagateMostLikelyTargetDateJob, type: :job do
  let(:company) { create(:organization) }
  let(:creator_teammate) { CompanyTeammate.find(create(:teammate, organization: company).id) }
  let(:parent_date) { Date.current + 90.days }
  let(:new_date) { Date.current + 120.days }
  let(:wide_earliest) { Date.current }
  let(:wide_latest) { Date.current + 2.years }

  describe '#perform' do
    it 'syncs unstarted children to the goal most_likely_target_date' do
      parent = create(:goal, :quantitative_key_result, creator: creator_teammate, owner: creator_teammate,
        earliest_target_date: wide_earliest, latest_target_date: wide_latest,
        most_likely_target_date: new_date, started_at: Time.current)
      child = create(:goal, :quantitative_key_result, creator: creator_teammate, owner: creator_teammate,
        most_likely_target_date: parent_date, started_at: nil, earliest_target_date: nil, latest_target_date: nil)
      create(:goal_link, parent: parent, child: child)

      described_class.perform_now(parent.id)

      expect(child.reload.most_likely_target_date).to eq(new_date)
    end

    it 'returns when goal is missing' do
      expect { described_class.perform_now(999_999_999) }.not_to raise_error
    end
  end
end
