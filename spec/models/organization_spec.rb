require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:company) { create(:organization, :company) }
  let(:standalone_team) { create(:team, company: company) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }
  let(:teammate1) { create(:teammate, person: person1, organization: company) }
  let(:teammate2) { create(:teammate, person: person2, organization: company) }
  let(:huddle) { create(:huddle, team: standalone_team) }
  let!(:huddle_participant1) { create(:huddle_participant, huddle: huddle, teammate: teammate1) }
  let!(:huddle_participant2) { create(:huddle_participant, huddle: huddle, teammate: teammate2) }

  describe '#huddle_participants' do
    it 'returns people who participated in huddles within the organization' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'includes participants from teams in the organization' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'returns distinct participants' do
      # Create another team and huddle to avoid validation issues
      another_team = create(:team, company: company)
      another_huddle = create(:huddle, team: another_team)
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
      title = create(:title, company: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, title: title, position_level: position_level)
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      
      # person2 has no employment tenure (just a huddle participant)
      
      expect(company.just_huddle_participants).to include(person2)
      expect(company.just_huddle_participants).not_to include(person1)
    end

    it 'returns empty when all huddle participants are employees' do
      # Make both people employees
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      title = create(:title, company: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, title: title, position_level: position_level)
      
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      create(:employment_tenure, teammate: teammate2, company: company, position: position)
      
      expect(company.just_huddle_participants).to be_empty
    end
  end

  describe '#teammate_milestones_for_person' do
    let(:ability) { create(:ability, company: company) }
    let(:certifier) { create(:person) }

    it 'returns milestones for a person in the organization' do
      # Create a milestone for person1
      certifier_teammate = create(:company_teammate, person: certifier, organization: company)
      teammate_milestone = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: ability, 
        certifying_teammate: certifier_teammate, 
        milestone_level: 2,
        attained_at: 30.days.ago
      )

      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(1)
      expect(result.first).to eq(teammate_milestone)
    end

    it 'returns empty collection when person has no teammate record' do
      person_without_teammate = create(:person)
      
      result = company.teammate_milestones_for_person(person_without_teammate)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result).to be_empty
    end

    it 'only returns milestones for abilities in the organization' do
      # Create ability in different organization
      other_company = create(:organization, :company)
      other_ability = create(:ability, company: other_company)
      
      # Create milestones for both abilities
      certifier_teammate = create(:company_teammate, person: certifier, organization: company)
      milestone_in_company = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: ability, 
        certifying_teammate: certifier_teammate, 
        milestone_level: 2,
        attained_at: 30.days.ago
      )
      milestone_in_other_company = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: other_ability, 
        certifying_teammate: certifier_teammate, 
        milestone_level: 3,
        attained_at: 30.days.ago
      )

      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to include(milestone_in_company)
      expect(result).not_to include(milestone_in_other_company)
    end

    it 'returns empty collection when teammate has no milestones' do
      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result).to be_empty
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format' do
      company = create(:organization, :company, name: 'Test Company')
      expect(company.to_param).to eq("#{company.id}-test-company")
    end

    it 'handles special characters in name' do
      company = create(:organization, :company, name: 'Test & Company!')
      expect(company.to_param).to eq("#{company.id}-test-company")
    end
  end

  describe '.find_by_param' do
    let(:company) { create(:organization, :company, name: 'Test Company') }

    it 'finds by numeric id' do
      found = Organization.find_by_param(company.id.to_s)
      expect(found.id).to eq(company.id)
      expect(found).to be_a(Organization)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{company.id}-test-company"
      found = Organization.find_by_param(param)
      expect(found.id).to eq(company.id)
      expect(found).to be_a(Organization)
    end

    it 'extracts id from id-name format' do
      param = "#{company.id}-some-other-name"
      found = Organization.find_by_param(param)
      expect(found.id).to eq(company.id)
      expect(found).to be_a(Organization)
    end

    it 'raises error for invalid id' do
      expect {
        Organization.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'Slack group associations' do
    let(:slack_group) { create(:third_party_object, :slack_group, organization: company, third_party_id: 'S123456') }

    describe '#slack_group_association' do
      it 'returns nil when no association exists' do
        expect(company.slack_group_association).to be_nil
      end

      it 'returns the association when it exists' do
        association = create(:third_party_object_association,
                            third_party_object: slack_group,
                            associatable: company,
                            association_type: 'slack_group')
        expect(company.slack_group_association).to eq(association)
      end
    end

    describe '#slack_group' do
      it 'returns nil when no association exists' do
        expect(company.slack_group).to be_nil
      end

      it 'returns the group when association exists' do
        create(:third_party_object_association,
               third_party_object: slack_group,
               associatable: company,
               association_type: 'slack_group')
        expect(company.slack_group).to eq(slack_group)
      end
    end

    describe '#slack_group_id' do
      it 'returns nil when no association exists' do
        expect(company.slack_group_id).to be_nil
      end

      it 'returns the group id when association exists' do
        create(:third_party_object_association,
               third_party_object: slack_group,
               associatable: company,
               association_type: 'slack_group')
        expect(company.slack_group_id).to eq('S123456')
      end
    end

    describe '#slack_group_id=' do
      it 'creates association when group_id is provided' do
        # Ensure the group exists before setting
        slack_group
        company.slack_group_id = 'S123456'
        company.save!
        
        expect(company.reload.slack_group_id).to eq('S123456')
        expect(company.slack_group).to eq(slack_group)
      end

      it 'removes association when group_id is empty' do
        create(:third_party_object_association,
               third_party_object: slack_group,
               associatable: company,
               association_type: 'slack_group')
        
        company.slack_group_id = ''
        company.save!
        
        expect(company.slack_group_id).to be_nil
      end

      it 'updates association when group_id changes' do
        new_group = create(:third_party_object, :slack_group, organization: company, third_party_id: 'S789012')
        create(:third_party_object_association,
               third_party_object: slack_group,
               associatable: company,
               association_type: 'slack_group')
        
        company.slack_group_id = 'S789012'
        company.save!
        
        expect(company.slack_group_id).to eq('S789012')
        expect(company.slack_group).to eq(new_group)
      end
    end
  end

  describe '.find_by_slack_workspace_id' do
    let(:workspace_id) { 'T123456' }

    context 'when Slack configuration exists' do
      let!(:slack_config) { create(:slack_configuration, organization: company, workspace_id: workspace_id) }

      it 'returns the organization' do
        result = Organization.find_by_slack_workspace_id(workspace_id)
        expect(result).to be_a(Organization)
        expect(result.id).to eq(company.id)
      end
    end

    context 'when Slack configuration does not exist' do
      it 'returns nil' do
        expect(Organization.find_by_slack_workspace_id(workspace_id)).to be_nil
      end
    end
  end

  describe 'archiving' do
    let(:department) { create(:organization, :department, parent: company) }
    let(:sub_department) { create(:organization, :department, parent: department) }

    describe 'scopes' do
      describe '.active' do
        it 'returns only organizations without deleted_at' do
          archived_org = create(:organization, :department, parent: company, deleted_at: Time.current)

          active_orgs = Organization.active
          expect(active_orgs).to include(company, department, sub_department)
          expect(active_orgs).not_to include(archived_org)
        end
      end

      describe '.archived' do
        it 'returns only organizations with deleted_at' do
          archived_org = create(:organization, :department, parent: company, deleted_at: Time.current)

          archived_orgs = Organization.archived
          expect(archived_orgs).to include(archived_org)
          expect(archived_orgs).not_to include(company, department, sub_department)
        end
      end
    end

    describe '#soft_delete!' do
      it 'sets deleted_at timestamp' do
        expect(department.deleted_at).to be_nil
        department.soft_delete!
        expect(department.reload.deleted_at).to be_present
      end
    end

    describe '#restore!' do
      it 'clears deleted_at timestamp' do
        department.update!(deleted_at: Time.current)
        department.restore!
        expect(department.reload.deleted_at).to be_nil
      end
    end

    describe '#archived?' do
      it 'returns true when deleted_at is present' do
        department.update!(deleted_at: Time.current)
        expect(department.archived?).to be true
      end

      it 'returns false when deleted_at is nil' do
        expect(department.archived?).to be false
      end
    end

    describe '#descendants' do
      it 'returns empty array for Organization (departments are now separate model)' do
        # Since departments are now a separate model, Organization.descendants returns []
        # This test verifies the current behavior
        expect(company.descendants).to eq([])
        expect(department.descendants).to eq([])
      end
    end
  end
end 