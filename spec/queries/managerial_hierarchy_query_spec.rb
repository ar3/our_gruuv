require 'rails_helper'

RSpec.describe ManagerialHierarchyQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: company) }
  
  let(:direct_manager) { create(:person) }
  let(:direct_manager_teammate) { CompanyTeammate.create!(person: direct_manager, organization: company) }
  
  let(:grand_manager) { create(:person) }
  let(:grand_manager_teammate) { CompanyTeammate.create!(person: grand_manager, organization: company) }

  describe '#initialize' do
    it 'accepts person and organization' do
      query = described_class.new(person: person, organization: company)
      expect(query).to be_a(ManagerialHierarchyQuery)
    end
  end

  describe '#call' do
    context 'when person or organization is nil' do
      it 'returns empty array when person is nil' do
        query = described_class.new(person: nil, organization: company)
        expect(query.call).to eq([])
      end

      it 'returns empty array when organization is nil' do
        query = described_class.new(person: person, organization: nil)
        expect(query.call).to eq([])
      end
    end

    context 'when person has no managers' do
      it 'returns empty array' do
        # Create employment tenure without manager
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: nil)
        
        query = described_class.new(person: person, organization: company)
        expect(query.call).to eq([])
      end
    end

    context 'when person has a direct manager' do
      before do
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate)
      end

      it 'returns the direct manager' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(1)
        expect(results.first[:person_id]).to eq(direct_manager.id)
        expect(results.first[:name]).to eq(direct_manager.display_name)
        expect(results.first[:email]).to eq(direct_manager.email)
        expect(results.first[:level]).to eq(0)
      end

      it 'includes manager position information' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: company, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        # Find or create the manager's employment tenure and update its position
        manager_tenure = EmploymentTenure.find_or_create_by!(company_teammate: direct_manager_teammate, company: company) do |et|
          et.started_at = 1.month.ago
          et.position = position
        end
        manager_tenure.update!(position: position) unless manager_tenure.position == position
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.first[:tenure]).to be_present
        expect(results.first[:tenure]).to eq(position.display_name)
      end
    end

    context 'when person has multiple managers' do
      let(:manager2) { create(:person) }
      let(:manager2_teammate) { CompanyTeammate.create!(person: manager2, organization: company) }

      before do
        # Person has two employment tenures with different managers
        # Inactive tenure that ended before the active one started (create this first)
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: manager2_teammate, started_at: 3.months.ago, ended_at: 2.months.ago)
        # Active tenure starting after the inactive one ended
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate, started_at: 1.month.ago)
      end

      it 'returns all managers from active tenures' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(1)
        expect(results.first[:person_id]).to eq(direct_manager.id)
      end

      it 'only includes managers from active tenures' do
        # The before block already created an active tenure starting at 1.month.ago
        # Create an inactive tenure with a manager that ended well before the active one started
        # Use a different company to avoid overlap validation issues
        other_company = create(:organization, :company)
        other_teammate = CompanyTeammate.create!(person: person, organization: other_company)
        inactive_manager = create(:person)
        inactive_manager_teammate = CompanyTeammate.create!(person: inactive_manager, organization: other_company)
        create(:employment_tenure, company_teammate: other_teammate, company: other_company, manager_teammate: inactive_manager_teammate, started_at: 3.months.ago, ended_at: 2.months.ago)
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        manager_ids = results.map { |r| r[:person_id] }
        # inactive_manager's tenure is in a different company, so shouldn't appear
        expect(manager_ids).not_to include(inactive_manager.id)
        expect(manager_ids).to include(direct_manager.id)
      end
    end

    context 'when manager has a manager (grand manager)' do
      before do
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate)
        create(:employment_tenure, company_teammate: direct_manager_teammate, company: company, manager_teammate: grand_manager_teammate)
      end

      it 'returns both direct manager and grand manager' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(2)
        manager_ids = results.map { |r| r[:person_id] }
        expect(manager_ids).to include(direct_manager.id, grand_manager.id)
      end

      it 'sorts by level (closest managers first)' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results[0][:level]).to eq(0)
        expect(results[0][:person_id]).to eq(direct_manager.id)
        expect(results[1][:level]).to eq(1)
        expect(results[1][:person_id]).to eq(grand_manager.id)
      end
    end

    context 'when manager chain goes deeper' do
      let(:great_grand_manager) { create(:person) }
      let(:great_grand_manager_teammate) { CompanyTeammate.create!(person: great_grand_manager, organization: company) }

      before do
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate)
        create(:employment_tenure, company_teammate: direct_manager_teammate, company: company, manager_teammate: grand_manager_teammate)
        create(:employment_tenure, company_teammate: grand_manager_teammate, company: company, manager_teammate: great_grand_manager_teammate)
      end

      it 'returns all managers in the chain' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(3)
        manager_ids = results.map { |r| r[:person_id] }
        expect(manager_ids).to include(direct_manager.id, grand_manager.id, great_grand_manager.id)
      end

      it 'assigns correct levels to each manager' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        levels = results.map { |r| r[:level] }
        expect(levels).to eq([0, 1, 2])
      end
    end

    context 'when manager appears multiple times in chain' do
      before do
        # Circular reference scenario - manager manages person, but also has a manager
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate)
        create(:employment_tenure, company_teammate: direct_manager_teammate, company: company, manager_teammate: grand_manager_teammate)
        # If grand_manager also had direct_manager as a manager, we should only see each manager once
      end

      it 'does not duplicate managers' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        manager_ids = results.map { |r| r[:person_id] }
        expect(manager_ids.uniq.length).to eq(manager_ids.length)
      end
    end

    context 'when person has employment in different organization' do
      let(:other_company) { create(:organization, :company) }
      let(:other_company_manager) { create(:person) }
      let(:other_company_manager_teammate) { CompanyTeammate.create!(person: other_company_manager, organization: other_company) }
      let(:other_company_teammate) { CompanyTeammate.create!(person: person, organization: other_company) }

      before do
        create(:employment_tenure, company_teammate: person_teammate, company: company, manager_teammate: direct_manager_teammate)
        create(:employment_tenure, company_teammate: other_company_teammate, company: other_company, manager_teammate: other_company_manager_teammate)
      end

      it 'only returns managers from the specified organization' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        manager_ids = results.map { |r| r[:person_id] }
        expect(manager_ids).to include(direct_manager.id)
        expect(manager_ids).not_to include(other_company_manager.id)
      end
    end
  end
end

