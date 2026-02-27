require 'rails_helper'

RSpec.describe ObservableMoments::ObservationStoryTemplateService do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: company, person: person) }
  
  describe '.template_for' do
    context 'for new_hire moment' do
      let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
      let(:moment) { create(:observable_moment, :new_hire, momentable: employment_tenure, company: company) }
      
      it 'returns welcome message template' do
        template = ObservableMoments::ObservationStoryTemplateService.template_for(moment)
        expect(template).to include('Welcome')
        expect(template).to include(person.display_name)
      end
    end
    
    context 'for seat_change moment' do
      let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
      let(:moment) do
        create(:observable_moment, :seat_change, momentable: employment_tenure, company: company,
               metadata: { old_position_name: 'Junior Developer', new_position_name: 'Senior Developer' })
      end
      
      it 'returns promotion message template' do
        template = ObservableMoments::ObservationStoryTemplateService.template_for(moment)
        expect(template).to include('Congratulations')
        expect(template).to include('promotion')
      end
    end
    
    context 'for ability_milestone moment' do
      let(:ability) { create(:ability, company: company) }
      let(:milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3) }
      let(:moment) { create(:observable_moment, :ability_milestone, momentable: milestone, company: company) }

      it 'returns milestone achievement message' do
        template = ObservableMoments::ObservationStoryTemplateService.template_for(moment)
        expect(template).to include('achieving')
        expect(template).to include(ability.name)
        expect(template).to include('milestone level 3')
      end
    end

    context 'for goal_check_in moment' do
      let(:goal) { create(:goal, owner: teammate, company: company, title: 'Launch Feature') }
      let(:goal_check_in) { create(:goal_check_in, goal: goal, confidence_percentage: 80) }
      let(:moment) do
        create(:observable_moment, :goal_check_in,
               momentable: goal_check_in,
               company: company,
               metadata: { goal_title: 'Launch Feature', confidence_percentage: 80, confidence_delta: 25 })
      end
      
      it 'returns goal progress message' do
        template = ObservableMoments::ObservationStoryTemplateService.template_for(moment)
        expect(template).to include('Launch Feature')
        expect(template).to include('80%')
        expect(template).to include('increased')
      end
    end
  end
  
  describe '.suggested_observees' do
    let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
    let(:moment) { create(:observable_moment, :new_hire, momentable: employment_tenure, company: company) }
    
    it 'returns the associated teammate' do
      observees = ObservableMoments::ObservationStoryTemplateService.suggested_observees(moment)
      expect(observees).to include(teammate)
    end
  end
  
  describe '.suggested_privacy_level' do
    let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
    let(:moment) { create(:observable_moment, :new_hire, momentable: employment_tenure, company: company) }
    
    it 'returns public_to_company for celebratory moments' do
      privacy_level = ObservableMoments::ObservationStoryTemplateService.suggested_privacy_level(moment)
      expect(privacy_level).to eq('public_to_company')
    end
  end
end


