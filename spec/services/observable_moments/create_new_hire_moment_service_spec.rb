require 'rails_helper'

RSpec.describe ObservableMoments::CreateNewHireMomentService do
  let(:company) { create(:organization, :company) }
  let(:created_by) { create(:person) }
  let(:new_hire_person) { create(:person) }
  let(:new_hire_teammate) { create(:teammate, organization: company, person: new_hire_person) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { create(:teammate, organization: company, person: manager_person) }
  let(:employment_tenure) do
    create(:employment_tenure,
           teammate: new_hire_teammate,
           company: company,
           manager_teammate: manager_teammate)
  end
  
  describe '.call' do
    context 'when employment has a manager' do
      it 'creates observable moment with manager as primary observer' do
        result = ObservableMoments::CreateNewHireMomentService.call(
          employment_tenure: employment_tenure,
          created_by: created_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.moment_type).to eq('new_hire')
        expect(moment.momentable).to eq(employment_tenure)
        expect(moment.primary_potential_observer).to eq(manager_teammate)
        expect(moment.metadata['person_name']).to eq(new_hire_person.display_name)
        expect(moment.metadata['position_id']).to eq(employment_tenure.position_id)
      end
    end
    
    context 'when employment has no manager' do
      let(:employment_tenure_no_manager) do
        create(:employment_tenure,
               teammate: new_hire_teammate,
               company: company,
               manager_teammate: nil)
      end
      
      it 'creates observable moment with creator as primary observer' do
        creator_teammate = create(:teammate, organization: company, person: created_by)
        
        result = ObservableMoments::CreateNewHireMomentService.call(
          employment_tenure: employment_tenure_no_manager,
          created_by: created_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.primary_potential_observer).to eq(creator_teammate)
      end
    end
    
    it 'sets occurred_at to employment start date' do
      start_date = 1.week.ago
      employment_tenure.update!(started_at: start_date)
      
      result = ObservableMoments::CreateNewHireMomentService.call(
        employment_tenure: employment_tenure,
        created_by: created_by
      )
      
      expect(result.value.occurred_at).to be_within(1.second).of(start_date)
    end
  end
end

