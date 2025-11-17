require 'rails_helper'

RSpec.describe MaapChangeDetectionService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  
  describe '#assignment_changes_count' do
    context 'with MaapSnapshot 122 scenario' do
      let(:previous_snapshot) { create(:maap_snapshot, created_at: 2.days.ago) }
      let(:snapshot) { create(:maap_snapshot, id: 122, created_at: 1.day.ago) }
      
      before do
        # Create previous snapshot with the baseline state (standard format)
        previous_snapshot.update!(
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          reason: 'Previous state',
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 40,  # Different from proposed 50
                'official_rating' => 'meeting'
              }
            ],
            'position' => {
              'seat_id' => nil,
              'manager_id' => manager.id,
              'position_id' => 8,
              'employment_type' => 'full_time',
              'official_position_rating' => nil
            },
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        # Set up the exact scenario from MaapSnapshot 122 (proposed state)
        snapshot.update!(
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          reason: 'Assignment updates',
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,  # Changed from 40
                'official_rating' => 'meeting'
              }
            ],
            'position' => {
              'seat_id' => nil,
              'manager_id' => manager.id,
              'position_id' => 8,
              'employment_type' => 'full_time',
              'official_position_rating' => nil
            },
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      it 'correctly counts assignment changes' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager,
          previous_snapshot: previous_snapshot
        )
        
        # This should detect changes in:
        # 1. anticipated_energy_percentage: 40 → 50
        expect(service.change_counts[:assignments]).to eq(1)
      end
      
      it 'correctly identifies which assignment has changes' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager,
          previous_snapshot: previous_snapshot
        )
        
        expect(service.assignment_has_changes?(assignment)).to be true
      end
      
      it 'provides detailed change information' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager,
          previous_snapshot: previous_snapshot
        )
        
        details = service.detailed_changes[:assignments]
        expect(details[:has_changes]).to be true
        expect(details[:details].length).to eq(1)
        
        assignment_changes = details[:details].first
        expect(assignment_changes[:assignment_id]).to eq(assignment.id)
        expect(assignment_changes[:changes].length).to eq(1)
        expect(assignment_changes[:changes].first[:field]).to eq('anticipated_energy_percentage')
        
        # Check for specific changes
        change_fields = assignment_changes[:changes].map { |c| c[:field] }
        expect(change_fields).to include('anticipated_energy_percentage')
      end
    end
  end
  
  describe '#aspiration_changes_count' do
    let(:aspiration) { create(:aspiration, organization: organization, name: 'Be Kind') }
    let(:previous_snapshot) { create(:maap_snapshot, created_at: 2.days.ago) }
    let(:snapshot) { create(:maap_snapshot, created_at: 1.day.ago) }
    
    before do
      previous_snapshot.update!(
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'aspiration_management',
        reason: 'Previous state',
        maap_data: {
          'position' => nil,
          'assignments' => [],
          'abilities' => [],
          'aspirations' => [
            {
              'aspiration_id' => aspiration.id,
              'official_rating' => nil
            }
          ]
        }
      )
      
      snapshot.update!(
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'aspiration_management',
        reason: 'Aspiration updates',
        maap_data: {
          'position' => nil,
          'assignments' => [],
          'abilities' => [],
          'aspirations' => [
            {
              'aspiration_id' => aspiration.id,
              'official_rating' => 'meeting'
            }
          ]
        }
      )
    end
    
    it 'correctly counts aspiration changes' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )
      
      expect(service.change_counts[:aspirations]).to eq(1)
    end
    
    it 'provides detailed aspiration change information' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )
      
      details = service.detailed_changes[:aspirations]
      expect(details[:has_changes]).to be true
      expect(details[:details].length).to eq(1)
      
      aspiration_changes = details[:details].first
      expect(aspiration_changes[:aspiration_id]).to eq(aspiration.id)
      expect(aspiration_changes[:changes].length).to be > 0
      
      rating_change = aspiration_changes[:changes].find { |c| c[:field] == 'official_rating' }
      expect(rating_change).to be_present
      expect(rating_change[:current]).to be_nil
      expect(rating_change[:proposed]).to eq('meeting')
    end
  end
end