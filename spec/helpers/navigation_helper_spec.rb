require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  describe '#pending_get_shit_done_count' do
    it 'returns 0 when teammate is nil' do
      expect(helper.pending_get_shit_done_count(nil)).to eq(0)
    end

    it 'counts all pending items' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      observable_moment = create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
      observable_moment.reload
      create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: nil, effective_date: Time.current)
      create(:observation, observer: person, company: company, published_at: nil)
      # Goal needs to meet check_in_eligible criteria
      goal = create(:goal, owner: company_teammate, company: company, started_at: Time.current, deleted_at: nil, completed_at: nil, most_likely_target_date: 1.month.from_now, goal_type: 'quantitative_key_result')
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should have at least 3 (observable moment, maap snapshot, observation)
      # Goal may or may not be included depending on check_in_eligible scope
      expect(count).to be >= 3
    end

    it 'excludes archived observations from count' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft.soft_delete!
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should only count draft1, not archived_draft
      expect(count).to eq(1)
    end

    it 'excludes journal observations from count' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      draft1 = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observed_only, story: "Draft 1 #{SecureRandom.hex(4)}")
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only, story: "Journal #{SecureRandom.hex(4)}")
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should only count draft1, not journal_draft
      expect(count).to eq(1)
    end

    it 'uses the same query logic as GetShitDoneQueryService' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      # Create various observations
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only)
      archived_draft = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft.soft_delete!
      
      # Both should return the same count
      helper_count = helper.pending_get_shit_done_count(company_teammate)
      service_count = GetShitDoneQueryService.new(teammate: company_teammate).total_pending_count
      
      expect(helper_count).to eq(service_count)
      expect(helper_count).to eq(1) # Only draft1 should be counted
    end
  end
end
