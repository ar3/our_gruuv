require 'rails_helper'

RSpec.describe ObservableMoments::CreateAbilityMilestoneMomentService do
  let(:company) { create(:organization, :company) }
  let(:ability) { create(:ability, company: company) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:certified_by) { create(:person) }
  let(:certifier_teammate) { create(:teammate, organization: company, person: certified_by) }
  let(:milestone) do
    create(:teammate_milestone,
           teammate: teammate,
           ability: ability,
           certifying_teammate: certifier_teammate,
           milestone_level: 3)
  end
  
  describe '.call' do
    it 'creates observable moment with certifier as primary observer' do
      result = ObservableMoments::CreateAbilityMilestoneMomentService.call(
        teammate_milestone: milestone,
        created_by: certified_by
      )
      
      expect(result.ok?).to be true
      moment = result.value
      expect(moment.moment_type).to eq('ability_milestone')
      expect(moment.momentable).to eq(milestone)
      expect(moment.primary_potential_observer).to eq(certifier_teammate)
      expect(moment.company).to eq(ability.organization)
      expect(moment.metadata['ability_id']).to eq(ability.id)
      expect(moment.metadata['ability_name']).to eq(ability.name)
      expect(moment.metadata['milestone_level']).to eq(3)
    end
    
    it 'sets occurred_at to milestone attained_at date' do
      attained_date = 2.weeks.ago.to_date
      milestone.update!(attained_at: attained_date)
      
      result = ObservableMoments::CreateAbilityMilestoneMomentService.call(
        teammate_milestone: milestone,
        created_by: certified_by
      )
      
      expect(result.value.occurred_at.to_date).to eq(attained_date)
    end
  end
end

