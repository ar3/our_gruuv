require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }
  let(:teammate1) { create(:teammate, person: person1, organization: team) }
  let(:teammate2) { create(:teammate, person: person2, organization: team) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: team) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
  let!(:huddle_participant1) { create(:huddle_participant, huddle: huddle, teammate: teammate1) }
  let!(:huddle_participant2) { create(:huddle_participant, huddle: huddle, teammate: teammate2) }

  describe '#huddle_participants' do
    it 'returns people who participated in huddles within the organization' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'includes participants from child organizations' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'returns distinct participants' do
      # Create another huddle with a different playbook to avoid validation issues
      another_playbook = create(:huddle_playbook, organization: team)
      another_huddle = create(:huddle, huddle_playbook: another_playbook)
      create(:huddle_participant, huddle: another_huddle, teammate: teammate1)
      
      expect(company.huddle_participants.count).to eq(2) # person1 and person2, not duplicated
    end

    it 'returns empty when no huddles exist' do
      empty_company = create(:organization, :company)
      expect(empty_company.huddle_participants).to be_empty
    end
  end

  describe '#just_huddle_participants' do
    it 'returns only huddle participants who are not active employees' do
      # Create an employment tenure for person1 (making them an employee)
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      position_type = create(:position_type, organization: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, position_type: position_type, position_level: position_level)
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      
      # person2 has no employment tenure (just a huddle participant)
      
      expect(company.just_huddle_participants).to include(person2)
      expect(company.just_huddle_participants).not_to include(person1)
    end

    it 'returns empty when all huddle participants are employees' do
      # Make both people employees
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      position_type = create(:position_type, organization: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, position_type: position_type, position_level: position_level)
      
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      create(:employment_tenure, teammate: teammate2, company: company, position: position)
      
      expect(company.just_huddle_participants).to be_empty
    end
  end
end 