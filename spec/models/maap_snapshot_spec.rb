require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let!(:employee) { create(:person) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: company) }
  let!(:created_by) { create(:person) }
  let!(:company) { create(:organization) }
  
  before do
    # Set up employment tenure for the employee
    create(:employment_tenure, teammate: employee_teammate, company: company)
  end
  
  describe 'validations' do
    it 'requires change_type' do
      snapshot = build(:maap_snapshot, change_type: nil)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:change_type]).to include("can't be blank")
    end
    
    it 'requires reason' do
      snapshot = build(:maap_snapshot, reason: nil)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:reason]).to include("can't be blank")
    end
    
    it 'requires company' do
      snapshot = build(:maap_snapshot, company: nil)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:company]).to include("can't be blank")
    end
    
    it 'validates change_type inclusion' do
      snapshot = build(:maap_snapshot, change_type: 'invalid_type')
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:change_type]).to include('is not included in the list')
    end
  end
  
  describe 'associations' do
    it 'belongs to employee (optional)' do
      snapshot = create(:maap_snapshot, employee: employee)
      expect(snapshot.employee).to eq(employee)
    end
    
    it 'belongs to created_by (optional)' do
      snapshot = create(:maap_snapshot, created_by: created_by)
      expect(snapshot.created_by).to eq(created_by)
    end
    
    it 'belongs to company' do
      snapshot = create(:maap_snapshot, company: company)
      expect(snapshot.company).to eq(company)
    end
  end
  
  describe 'scopes' do
    let!(:snapshot1) { create(:maap_snapshot, change_type: 'assignment_management', effective_date: nil) }
    let!(:snapshot2) { create(:maap_snapshot, change_type: 'position_tenure', effective_date: Date.current) }
    let!(:snapshot3) { create(:maap_snapshot, :exploration, change_type: 'exploration') }
    
    it 'filters by change_type' do
      expect(MaapSnapshot.by_change_type('assignment_management')).to include(snapshot1)
      expect(MaapSnapshot.by_change_type('assignment_management')).not_to include(snapshot2)
    end
    
    it 'filters executed snapshots' do
      expect(MaapSnapshot.executed).to include(snapshot2)
      expect(MaapSnapshot.executed).not_to include(snapshot1)
    end
    
    it 'filters pending snapshots' do
      expect(MaapSnapshot.pending).to include(snapshot1)
      expect(MaapSnapshot.pending).not_to include(snapshot2)
    end
    
    it 'filters exploration snapshots' do
      expect(MaapSnapshot.exploration).to include(snapshot3)
      expect(MaapSnapshot.exploration).not_to include(snapshot1)
    end
  end
  
  describe 'instance methods' do
    let(:snapshot) { create(:maap_snapshot, effective_date: nil) }
    let(:executed_snapshot) { create(:maap_snapshot, effective_date: Date.current) }
    
    it 'checks if executed' do
      expect(snapshot.executed?).to be false
      expect(executed_snapshot.executed?).to be true
    end
    
    it 'checks if pending' do
      expect(snapshot.pending?).to be true
      expect(executed_snapshot.pending?).to be false
    end
    
    it 'checks if exploration snapshot' do
      exploration_snapshot = create(:maap_snapshot, :exploration)
      expect(exploration_snapshot.exploration_snapshot?).to be true
      expect(snapshot.exploration_snapshot?).to be false
    end
  end
  
  describe 'class methods' do
    describe '.build_for_employee' do
      it 'creates a snapshot for an employee' do
        snapshot = MaapSnapshot.build_for_employee(
          employee: employee,
          created_by: created_by,
          change_type: 'assignment_management',
          reason: 'Test snapshot',
          request_info: { ip_address: '127.0.0.1' }
        )
        
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.created_by).to eq(created_by)
        expect(snapshot.company.id).to eq(company.id)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.reason).to eq('Test snapshot')
        expect(snapshot.manager_request_info['ip_address']).to eq('127.0.0.1')
      end
    end
    
    describe '.build_exploration' do
      it 'creates an exploration snapshot' do
        snapshot = MaapSnapshot.build_exploration(
          created_by: created_by,
          company: company,
          reason: 'Test exploration',
          request_info: { ip_address: '127.0.0.1' }
        )
        
        expect(snapshot.employee).to be_nil
        expect(snapshot.created_by).to eq(created_by)
        expect(snapshot.company).to eq(company)
        expect(snapshot.change_type).to eq('exploration')
        expect(snapshot.reason).to eq('Test exploration')
      end
    end
    
    describe '.build_for_employee_with_changes' do
      let(:assignment) { create(:assignment, company: company) }
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 20) }
      
      it 'stores form_params separately and maap_data reflects DB state' do
        form_params = {
          "tenure_#{assignment.id}_anticipated_energy" => '5',
          "check_in_#{assignment.id}_actual_energy" => '10',
          "check_in_#{assignment.id}_employee_rating" => 'exceeding'
        }
        
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: created_by,
          change_type: 'assignment_management',
          reason: 'Test snapshot with changes',
          form_params: form_params
        )
        
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.created_by).to eq(created_by)
        expect(snapshot.company.id).to eq(company.id)
        expect(snapshot.company.name).to eq(company.name)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.reason).to eq('Test snapshot with changes')
        
        # Verify form_params are stored separately
        expect(snapshot.form_params).to eq(form_params)
        
        # Verify maap_data reflects DB state (not form_params)
        assignment_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment.id }
        expect(assignment_data).to be_present
        expect(assignment_data['anticipated_energy_percentage']).to eq(20) # From DB, not form_params
        # maap_data should not contain check-in data (only assignment_tenure data)
        expect(assignment_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage rated_assignment])
      end
      
      it 'maap_data always reflects current DB state, not proposed changes' do
        # Create assignment with 20% energy in DB
        assignment_tenure.update!(anticipated_energy_percentage: 20)
        
        form_params = {
          "tenure_#{assignment.id}_anticipated_energy" => '50' # Proposed change
        }
        
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: created_by,
          change_type: 'assignment_management',
          reason: 'Proposed change',
          form_params: form_params
        )
        
        # maap_data should reflect DB state (20%), not form_params (50%)
        assignment_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment.id }
        expect(assignment_data['anticipated_energy_percentage']).to eq(20) # DB state
        
        # form_params should contain proposed change
        expect(snapshot.form_params["tenure_#{assignment.id}_anticipated_energy"]).to eq('50')
      end
    end
    
    describe '.build_for_employee with position_tenure change_type' do
      it 'creates a snapshot for position tenure changes' do
        snapshot = MaapSnapshot.build_for_employee(
          employee: employee,
          created_by: created_by,
          change_type: 'position_tenure',
          reason: 'Position change',
          request_info: { ip_address: '127.0.0.1' }
        )
        
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.created_by).to eq(created_by)
        expect(snapshot.company.id).to eq(company.id)
        expect(snapshot.change_type).to eq('position_tenure')
        expect(snapshot.reason).to eq('Position change')
        expect(snapshot.manager_request_info['ip_address']).to eq('127.0.0.1')
        expect(snapshot.maap_data['position']).to be_present
      end
    end
  end
end
