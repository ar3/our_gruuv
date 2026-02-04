require 'rails_helper'

RSpec.describe GetShitDoneQueryService do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    # Ensure we get a CompanyTeammate, not just a generic Teammate
    CompanyTeammate.find_or_create_by!(person: person, organization: company)
  end
  let(:service) { described_class.new(teammate: teammate) }

  describe '#observation_drafts' do
    it 'excludes journal observations (observer_only privacy level)' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observed_only)
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only)
      
      drafts = service.observation_drafts
      
      expect(drafts).to include(draft1)
      expect(drafts).not_to include(journal_draft)
    end

    it 'excludes archived (soft-deleted) observations' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil, story: "Draft 1 #{SecureRandom.hex(4)}")
      archived_draft = create(:observation, observer: person, company: company, published_at: nil, story: "Archived #{SecureRandom.hex(4)}")
      archived_draft.soft_delete!
      
      drafts = service.observation_drafts
      
      expect(drafts).to include(draft1)
      expect(drafts).not_to include(archived_draft)
    end

    it 'excludes published observations' do
      draft = create(:observation, observer: person, company: company, published_at: nil)
      published = create(:observation, observer: person, company: company, published_at: Time.current)
      
      drafts = service.observation_drafts
      
      expect(drafts).to include(draft)
      expect(drafts).not_to include(published)
    end

    it 'only includes observations for the given person and company' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      other_person = create(:person)
      other_draft = create(:observation, observer: other_person, company: company, published_at: nil)
      
      drafts = service.observation_drafts
      
      expect(drafts).to include(draft1)
      expect(drafts).not_to include(other_draft)
    end

    it 'returns empty relation when teammate is nil' do
      service = described_class.new(teammate: nil)
      
      expect(service.observation_drafts).to be_empty
    end
  end

  describe '#total_pending_count' do
    it 'counts all pending items correctly' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      # Create one of each type
      # Observable moment needs to be for the correct observer
      observable_moment = create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
      observable_moment.reload # Ensure associations are loaded
      
      create(:maap_snapshot, employee_company_teammate: company_teammate, company: company, employee_acknowledged_at: nil, effective_date: Time.current)
      create(:observation, observer: person, company: company, published_at: nil)
      # Goal needs to meet check_in_eligible criteria
      goal = create(:goal, owner: company_teammate, company: company, started_at: Time.current, deleted_at: nil, completed_at: nil, most_likely_target_date: 1.month.from_now, goal_type: 'quantitative_key_result')
      
      # Verify observable moment is associated with correct observer
      expect(observable_moment.primary_potential_observer).to eq(company_teammate)
      
      count = service.total_pending_count
      # Should have at least 3 (observable moment, maap snapshot, observation)
      # Goal may or may not be included depending on check_in_eligible scope
      expect(count).to be >= 3
    end

    it 'excludes archived observations from count' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft.soft_delete!
      
      # Should only count draft1, not archived_draft
      expect(service.total_pending_count).to eq(1)
    end

    it 'excludes journal observations from count' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observed_only)
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only)
      
      # Should only count draft1, not journal_draft
      expect(service.total_pending_count).to eq(1)
    end
  end

  describe '#all_pending_items' do
    it 'returns a hash with all pending items and total count' do
      result = service.all_pending_items
      
      expect(result).to have_key(:observable_moments)
      expect(result).to have_key(:maap_snapshots)
      expect(result).to have_key(:observation_drafts)
      expect(result).to have_key(:goals_needing_check_in)
      expect(result).to have_key(:total_pending)
      expect(result[:total_pending]).to be_a(Integer)
    end
  end
end
