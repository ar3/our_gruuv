require 'rails_helper'

RSpec.describe ObservableMoments::AssociateAndProcessService do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { CompanyTeammate.create!(person: observer, organization: company) }
  let(:observable_moment) { create(:observable_moment, :new_hire, company: company, primary_potential_observer: observer_teammate) }
  let(:observation) { create(:observation, observer: observer, company: company) }
  
  describe '.call' do
    context 'when observable_moment_id is present and moment exists' do
      it 'associates observation with observable moment' do
        expect {
          ObservableMoments::AssociateAndProcessService.call(
            observation: observation,
            observable_moment_id: observable_moment.id
          )
        }.to change { observation.reload.observable_moment }.from(nil).to(observable_moment)
      end
      
      it 'marks moment as processed' do
        expect(observable_moment.processed?).to be false
        
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observable_moment.reload.processed?).to be true
        expect(observable_moment.processed_at).to be_present
      end
      
      it 'sets processed_by_teammate to observer teammate' do
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observable_moment.reload.processed_by_teammate).to eq(observer_teammate)
      end
      
      it 'is idempotent - does not overwrite processed_at if already set' do
        original_processed_at = 1.hour.ago
        observable_moment.update!(
          processed_at: original_processed_at,
          processed_by_teammate: observer_teammate
        )
        
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observable_moment.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
      
      it 'is idempotent - can be called multiple times safely' do
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        first_processed_at = observable_moment.reload.processed_at
        
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observable_moment.reload.processed_at).to be_within(1.second).of(first_processed_at)
      end
    end
    
    context 'when observable_moment_id is blank' do
      it 'does nothing' do
        expect {
          ObservableMoments::AssociateAndProcessService.call(
            observation: observation,
            observable_moment_id: nil
          )
        }.not_to change { observation.reload.observable_moment }
      end
    end
    
    context 'when observable_moment does not exist' do
      it 'does nothing gracefully' do
        expect {
          ObservableMoments::AssociateAndProcessService.call(
            observation: observation,
            observable_moment_id: 99999
          )
        }.not_to change { observation.reload.observable_moment }
      end
    end
    
    context 'when observer has no teammate in company' do
      let(:observer_without_teammate) { create(:person) }
      let(:observation) { create(:observation, observer: observer_without_teammate, company: company) }
      
      it 'still associates and processes, but processed_by_teammate is nil' do
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observation.reload.observable_moment).to eq(observable_moment)
        expect(observable_moment.reload.processed?).to be true
        expect(observable_moment.processed_by_teammate).to be_nil
      end
    end
  end
end
