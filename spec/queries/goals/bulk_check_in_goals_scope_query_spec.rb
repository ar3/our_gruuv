# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::BulkCheckInGoalsScopeQuery do
  let(:organization) { create(:organization, :company) }
  let(:owner) { create(:person) }
  let(:owner_teammate) { create(:teammate, person: owner, organization: organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }

  before do
    create(:employment_tenure, teammate: owner_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    owner_teammate.update!(first_employed_at: 1.year.ago)
    owner_teammate.employment_tenures.active.first.update!(manager_teammate: manager_teammate)
  end

  def call_query(viewing_teammate: owner_teammate)
    described_class.new(
      teammate: owner_teammate,
      organization: organization,
      viewing_teammate: viewing_teammate
    ).call
  end

  describe '#call' do
    it 'returns active goals owned by the teammate' do
      active_goal = create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
                          started_at: 1.week.ago, most_likely_target_date: 1.month.from_now)
      create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
             started_at: nil, most_likely_target_date: 1.month.from_now)

      expect(call_query).to contain_exactly(active_goal)
    end

    it 'includes draft parent goals owned by the same teammate' do
      draft_parent = create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
                            started_at: nil, most_likely_target_date: 2.months.from_now, title: 'Draft parent')
      active_child = create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
                            started_at: 1.week.ago, most_likely_target_date: 1.month.from_now, title: 'Active child')
      create(:goal_link, parent: draft_parent, child: active_child)

      results = call_query
      expect(results).to include(draft_parent, active_child)
    end

    it 'excludes private goals when a manager is viewing' do
      public_goal = create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
                         started_at: 1.week.ago, most_likely_target_date: 1.month.from_now,
                         privacy_level: 'only_creator_owner_and_managers')
      private_goal = create(:goal, creator: owner_teammate, owner: owner_teammate, company: organization,
                          started_at: 1.week.ago, most_likely_target_date: 1.month.from_now,
                          privacy_level: 'only_creator')

      results = call_query(viewing_teammate: manager_teammate)
      expect(results).to include(public_goal)
      expect(results).not_to include(private_goal)
    end
  end
end
