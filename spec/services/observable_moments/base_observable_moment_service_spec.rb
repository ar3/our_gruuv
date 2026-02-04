require 'rails_helper'

RSpec.describe ObservableMoments::BaseObservableMomentService do
  let(:company) { create(:organization, :company) }
  let(:created_by) { create(:person) }
  let(:creator_teammate) { create(:company_teammate, person: created_by, organization: company) }
  let(:primary_observer) { create(:company_teammate, organization: company) }
  let(:employment_tenure) { create(:employment_tenure, company: company) }
  
  describe '.call' do
    it 'creates an observable moment successfully' do
      result = ObservableMoments::BaseObservableMomentService.call(
        momentable: employment_tenure,
        company: company,
        created_by: creator_teammate,
        primary_potential_observer: primary_observer,
        moment_type: :new_hire,
        occurred_at: Time.current,
        metadata: { test: 'data' }
      )
      
      expect(result.ok?).to be true
      expect(result.value).to be_a(ObservableMoment)
      expect(result.value.momentable).to eq(employment_tenure)
      expect(result.value.company).to eq(company)
      expect(result.value.created_by).to eq(created_by)
      expect(result.value.primary_potential_observer).to eq(primary_observer)
      expect(result.value.moment_type).to eq('new_hire')
      expect(result.value.metadata['test']).to eq('data')
    end
    
    it 'handles validation errors gracefully' do
      result = ObservableMoments::BaseObservableMomentService.call(
        momentable: nil,
        company: company,
        created_by: creator_teammate,
        primary_potential_observer: primary_observer,
        moment_type: :new_hire
      )
      
      expect(result.ok?).to be false
      expect(result.error).to be_present
    end
    
    it 'does not raise exceptions on failure' do
      expect {
        ObservableMoments::BaseObservableMomentService.call(
          momentable: nil,
          company: company,
          created_by: creator_teammate,
          primary_potential_observer: primary_observer,
          moment_type: :new_hire
        )
      }.not_to raise_error
    end
  end
end

