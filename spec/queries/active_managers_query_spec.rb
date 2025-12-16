require 'rails_helper'

RSpec.describe ActiveManagersQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }

  describe '#call' do
    context 'with require_active_teammate: true (strict mode)' do
      it 'returns only active managers who are also active teammates, ordered by last_name, first_name' do
        # Create managers who are active teammates
        manager1 = create(:person, first_name: 'Alice', last_name: 'Zebra')
        manager2 = create(:person, first_name: 'Bob', last_name: 'Alpha')
        manager3 = create(:person, first_name: 'Charlie', last_name: 'Beta')
        
        manager1_teammate = create(:teammate, type: 'CompanyTeammate', person: manager1, organization: company)
        manager2_teammate = create(:teammate, type: 'CompanyTeammate', person: manager2, organization: company)
        manager3_teammate = create(:teammate, type: 'CompanyTeammate', person: manager3, organization: company)
        
        # Create active employment tenures for managers (so they are active teammates)
        create(:employment_tenure, teammate: manager1_teammate, company: company, position: position, started_at: 1.year.ago)
        create(:employment_tenure, teammate: manager2_teammate, company: company, position: position, started_at: 1.year.ago)
        create(:employment_tenure, teammate: manager3_teammate, company: company, position: position, started_at: 1.year.ago)
        
        # Create employees managed by these managers
        emp1 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        emp2 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        emp3 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp1, company: company, position: position, manager: manager1, started_at: 6.months.ago)
        create(:employment_tenure, teammate: emp2, company: company, position: position, manager: manager2, started_at: 5.months.ago)
        create(:employment_tenure, teammate: emp3, company: company, position: position, manager: manager3, started_at: 4.months.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
        
        expect(result).to include(manager1, manager2, manager3)
        expect(result.size).to eq(3)
        # Should be ordered by last_name, first_name
        expect(result.map(&:last_name)).to eq(['Alpha', 'Beta', 'Zebra'])
      end

      it 'excludes managers who are not active teammates' do
        # Create a manager who has direct reports but is not an active teammate
        non_teammate_manager = create(:person, first_name: 'Non', last_name: 'Teammate')
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp, company: company, position: position, manager: non_teammate_manager, started_at: 2.months.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
        
        expect(result).not_to include(non_teammate_manager)
      end

      it 'excludes inactive managers' do
        # Create an inactive manager
        inactive_manager = create(:person, first_name: 'Inactive', last_name: 'Manager')
        inactive_manager_teammate = create(:teammate, type: 'CompanyTeammate', person: inactive_manager, organization: company)
        create(:employment_tenure, teammate: inactive_manager_teammate, company: company, position: position, started_at: 2.years.ago, ended_at: 1.year.ago)
        
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp, company: company, position: position, manager: inactive_manager, started_at: 3.months.ago, ended_at: 1.month.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
        
        expect(result).not_to include(inactive_manager)
      end

      it 'returns distinct managers' do
        manager = create(:person, first_name: 'Manager', last_name: 'One')
        manager_teammate = create(:teammate, type: 'CompanyTeammate', person: manager, organization: company)
        create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago)
        
        # Create multiple employees with the same manager
        emp1 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        emp2 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp1, company: company, position: position, manager: manager, started_at: 6.months.ago)
        create(:employment_tenure, teammate: emp2, company: company, position: position, manager: manager, started_at: 5.months.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
        
        expect(result.count { |m| m.id == manager.id }).to eq(1)
      end
    end

    context 'with require_active_teammate: false (lenient mode)' do
      it 'returns all managers with active direct reports, even if they are not active teammates' do
        # Create a manager who has direct reports but is not an active teammate
        non_teammate_manager = create(:person, first_name: 'Non', last_name: 'Teammate')
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp, company: company, position: position, manager: non_teammate_manager, started_at: 2.months.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: false).call
        
        expect(result).to include(non_teammate_manager)
      end

      it 'still excludes inactive managers' do
        inactive_manager = create(:person, first_name: 'Inactive', last_name: 'Manager')
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
        create(:employment_tenure, teammate: emp, company: company, position: position, manager: inactive_manager, started_at: 3.months.ago, ended_at: 1.month.ago)
        
        result = ActiveManagersQuery.new(company: company, require_active_teammate: false).call
        
        expect(result).not_to include(inactive_manager)
      end
    end

    context 'with organization hierarchy' do
      let(:parent_company) { create(:organization, :company) }
      let(:child_company) { create(:organization, :company, parent: parent_company) }

      it 'handles company hierarchy correctly' do
        manager = create(:person, first_name: 'Manager', last_name: 'One')
        manager_teammate = create(:teammate, type: 'CompanyTeammate', person: manager, organization: parent_company)
        create(:employment_tenure, teammate: manager_teammate, company: parent_company, position: position, started_at: 1.year.ago)
        
        # Employee in child company with manager from parent
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: child_company)
        create(:employment_tenure, teammate: emp, company: child_company, position: position, manager: manager, started_at: 6.months.ago)
        
        result = ActiveManagersQuery.new(company: parent_company, require_active_teammate: true).call
        
        expect(result).to include(manager)
      end

      it 'handles team/department hierarchy correctly' do
        team = create(:organization, type: 'Team', parent: company)
        
        manager = create(:person, first_name: 'Manager', last_name: 'One')
        manager_teammate = create(:teammate, type: 'CompanyTeammate', person: manager, organization: company)
        create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago)
        
        emp = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: team)
        create(:employment_tenure, teammate: emp, company: company, position: position, manager: manager, started_at: 6.months.ago)
        
        result = ActiveManagersQuery.new(company: team, require_active_teammate: true).call
        
        expect(result).to include(manager)
      end
    end
  end

  describe '#manager_ids' do
    it 'returns array of manager person IDs' do
      manager1 = create(:person, first_name: 'Manager', last_name: 'One')
      manager2 = create(:person, first_name: 'Manager', last_name: 'Two')
      
      manager1_teammate = create(:teammate, type: 'CompanyTeammate', person: manager1, organization: company)
      manager2_teammate = create(:teammate, type: 'CompanyTeammate', person: manager2, organization: company)
      
      create(:employment_tenure, teammate: manager1_teammate, company: company, position: position, started_at: 1.year.ago)
      create(:employment_tenure, teammate: manager2_teammate, company: company, position: position, started_at: 1.year.ago)
      
      emp1 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
      emp2 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: company)
      create(:employment_tenure, teammate: emp1, company: company, position: position, manager: manager1, started_at: 6.months.ago)
      create(:employment_tenure, teammate: emp2, company: company, position: position, manager: manager2, started_at: 5.months.ago)
      
      result = ActiveManagersQuery.new(company: company, require_active_teammate: true).manager_ids
      
      expect(result).to be_an(Array)
      expect(result).to include(manager1.id, manager2.id)
      expect(result.size).to eq(2)
    end
  end
end

