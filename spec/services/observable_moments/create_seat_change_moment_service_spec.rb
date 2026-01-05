require 'rails_helper'

RSpec.describe ObservableMoments::CreateSeatChangeMomentService do
  let(:company) { create(:organization, :company) }
  let(:created_by) { create(:person) }
  let(:creator_teammate) { create(:teammate, organization: company, person: created_by) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, organization: company, person: employee_person) }
  let(:old_position) { create(:position, company: company) }
  let(:new_position) { create(:position, company: company) }
  let(:old_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: company,
           position: old_position,
           started_at: 6.months.ago,
           ended_at: 1.day.ago)
  end
  let(:new_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: company,
           position: new_position,
           started_at: 1.day.ago)
  end
  
  describe '.call' do
    it 'creates observable moment with creator as primary observer' do
      result = ObservableMoments::CreateSeatChangeMomentService.call(
        new_employment_tenure: new_tenure,
        old_employment_tenure: old_tenure,
        created_by: created_by
      )
      
      expect(result.ok?).to be true
      moment = result.value
      expect(moment.moment_type).to eq('seat_change')
      expect(moment.momentable).to eq(new_tenure)
      expect(moment.primary_potential_observer).to eq(creator_teammate)
      expect(moment.metadata['old_position_id']).to eq(old_position.id)
      expect(moment.metadata['new_position_id']).to eq(new_position.id)
    end
    
    it 'stores old and new position names in metadata' do
      result = ObservableMoments::CreateSeatChangeMomentService.call(
        new_employment_tenure: new_tenure,
        old_employment_tenure: old_tenure,
        created_by: created_by
      )
      
      moment = result.value
      expect(moment.metadata['old_position_name']).to eq(old_position.name)
      expect(moment.metadata['new_position_name']).to eq(new_position.name)
    end
    
    it 'handles missing old tenure gracefully' do
      result = ObservableMoments::CreateSeatChangeMomentService.call(
        new_employment_tenure: new_tenure,
        old_employment_tenure: nil,
        created_by: created_by
      )
      
      expect(result.ok?).to be true
      moment = result.value
      expect(moment.metadata['old_position_id']).to be_nil
    end
  end
end

