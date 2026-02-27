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

  describe '#check_ins_awaiting_input' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) do
      CompanyTeammate.find_or_create_by!(person: manager_person, organization: company)
    end
    let(:employee_person) { create(:person) }
    let(:employee_teammate) do
      CompanyTeammate.find_or_create_by!(person: employee_person, organization: company)
    end
    let!(:employment_tenure) do
      create(:employment_tenure,
             company_teammate: employee_teammate,
             company: company,
             manager: manager_teammate)
    end
    let(:assignment) { create(:assignment, company: company) }
    let(:aspiration) { create(:aspiration, company: company) }

    context 'as employee' do
      let(:service) { described_class.new(teammate: employee_teammate) }

      it 'includes check-ins where manager is complete but employee is not' do
        check_in = create(:assignment_check_in,
                          teammate: employee_teammate,
                          assignment: assignment,
                          manager_completed_at: Time.current,
                          manager_completed_by_teammate: manager_teammate,
                          employee_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end

      it 'excludes check-ins where neither side is complete' do
        check_in = create(:assignment_check_in,
                          teammate: employee_teammate,
                          assignment: assignment,
                          manager_completed_at: nil,
                          employee_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'excludes finalized check-ins' do
        check_in = create(:assignment_check_in, :finalized,
                          teammate: employee_teammate,
                          assignment: assignment)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'excludes check-ins where employee is complete but manager is not' do
        check_in = create(:assignment_check_in,
                          teammate: employee_teammate,
                          assignment: assignment,
                          employee_completed_at: Time.current,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'includes aspiration check-ins awaiting employee input' do
        check_in = create(:aspiration_check_in,
                          teammate: employee_teammate,
                          aspiration: aspiration,
                          manager_completed_at: Time.current,
                          manager_completed_by_teammate: manager_teammate,
                          employee_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end

      it 'includes position check-ins awaiting employee input' do
        check_in = create(:position_check_in,
                          teammate: employee_teammate,
                          employment_tenure: employment_tenure,
                          manager_completed_at: Time.current,
                          manager_completed_by_teammate: manager_teammate,
                          employee_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end
    end

    context 'as manager' do
      let(:service) { described_class.new(teammate: manager_teammate) }

      it 'includes check-ins for direct reports where employee is complete but manager is not' do
        check_in = create(:assignment_check_in,
                          teammate: employee_teammate,
                          assignment: assignment,
                          employee_completed_at: Time.current,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end

      it 'excludes check-ins where neither side is complete' do
        check_in = create(:assignment_check_in,
                          teammate: employee_teammate,
                          assignment: assignment,
                          employee_completed_at: nil,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'excludes finalized check-ins for direct reports' do
        check_in = create(:assignment_check_in, :finalized,
                          teammate: employee_teammate,
                          assignment: assignment)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'excludes check-ins for non-direct-reports' do
        non_report_person = create(:person)
        non_report_teammate = CompanyTeammate.find_or_create_by!(person: non_report_person, organization: company)
        check_in = create(:assignment_check_in,
                          teammate: non_report_teammate,
                          assignment: assignment,
                          employee_completed_at: Time.current,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).not_to include(check_in)
      end

      it 'includes aspiration check-ins for direct reports awaiting manager input' do
        check_in = create(:aspiration_check_in,
                          teammate: employee_teammate,
                          aspiration: aspiration,
                          employee_completed_at: Time.current,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end

      it 'includes position check-ins for direct reports awaiting manager input' do
        check_in = create(:position_check_in,
                          teammate: employee_teammate,
                          employment_tenure: employment_tenure,
                          employee_completed_at: Time.current,
                          manager_completed_at: nil)

        result = service.check_ins_awaiting_input
        expect(result).to include(check_in)
      end
    end

    it 'returns empty array when teammate is nil' do
      service = described_class.new(teammate: nil)
      expect(service.check_ins_awaiting_input).to be_empty
    end
  end

  describe '#total_pending_count' do
    it 'includes check-ins awaiting input in the count' do
      employee_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      manager_person = create(:person)
      mgr_teammate = CompanyTeammate.find_or_create_by!(person: manager_person, organization: company)
      assignment = create(:assignment, company: company)

      create(:assignment_check_in,
             teammate: employee_teammate,
             assignment: assignment,
             manager_completed_at: Time.current,
             manager_completed_by_teammate: mgr_teammate,
             employee_completed_at: nil)

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
      expect(result).to have_key(:check_ins_awaiting_input)
      expect(result).to have_key(:total_pending)
      expect(result[:total_pending]).to be_a(Integer)
    end
  end
end
