require 'rails_helper'

RSpec.describe TeammateMilestonePolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find(create(:teammate, person: person, organization: organization).id) }
  let(:ability) { create(:ability, organization: organization) }
  let(:teammate_milestone) { create(:teammate_milestone, teammate: teammate, ability: ability) }
  
  let(:other_person) { create(:person) }
  let(:other_teammate) { CompanyTeammate.find(create(:teammate, person: other_person, organization: organization).id) }
  
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager_person, organization: organization).id) }

  permissions :new?, :create? do
    it 'allows any authenticated teammate to award milestones' do
      expect(subject).to permit(teammate, TeammateMilestone)
    end

    it 'denies if teammate is terminated' do
      teammate.update!(first_employed_at: 1.month.ago, last_terminated_at: Time.current)
      expect(subject).not_to permit(teammate, TeammateMilestone)
    end

    it 'denies if not authenticated' do
      expect(subject).not_to permit(nil, TeammateMilestone)
    end
  end

  permissions :show? do
    it 'allows the teammate who was awarded to view' do
      expect(subject).to permit(teammate, teammate_milestone)
    end

    it 'allows managers of the teammate to view' do
      # Set up manager relationship - need to ensure manager_teammate is a CompanyTeammate
      manager_teammate_company = CompanyTeammate.find(manager_teammate.id)
      create(:employment_tenure, 
             teammate: teammate, 
             company: organization, 
             manager_teammate: manager_teammate_company)
      
      expect(subject).to permit(manager_teammate_company, teammate_milestone)
    end

    it 'allows users with manage_employment permission to view' do
      admin_teammate = CompanyTeammate.find(create(:teammate, 
                              person: create(:person), 
                              organization: organization,
                              can_manage_employment: true).id)
      
      expect(subject).to permit(admin_teammate, teammate_milestone)
    end

    it 'denies other teammates from viewing unpublished milestones' do
      expect(subject).not_to permit(other_teammate, teammate_milestone)
    end

    it 'allows any teammate in the organization to view published milestones' do
      teammate_milestone.update!(published_at: Time.current, published_by_teammate: teammate_milestone.certifying_teammate)
      expect(subject).to permit(other_teammate, teammate_milestone)
    end

    it 'denies if viewing teammate is terminated' do
      teammate.update!(first_employed_at: 1.month.ago, last_terminated_at: Time.current)
      expect(subject).not_to permit(teammate, teammate_milestone)
    end
  end

  permissions :publish?, :unpublish? do
    it 'allows the receiver to publish/unpublish' do
      expect(subject).to permit(teammate, teammate_milestone)
    end

    it 'allows the certifier to publish/unpublish' do
      certifier_teammate = teammate_milestone.certifying_teammate
      expect(subject).to permit(certifier_teammate, teammate_milestone)
    end

    it 'allows managers to publish/unpublish' do
      manager_teammate_company = CompanyTeammate.find(manager_teammate.id)
      create(:employment_tenure, 
             teammate: teammate, 
             company: organization, 
             manager_teammate: manager_teammate_company)
      
      expect(subject).to permit(manager_teammate_company, teammate_milestone)
    end

    it 'allows users with manage_employment permission to publish/unpublish' do
      admin_teammate = CompanyTeammate.find(create(:teammate, 
                              person: create(:person), 
                              organization: organization,
                              can_manage_employment: true).id)
      
      expect(subject).to permit(admin_teammate, teammate_milestone)
    end

    it 'denies other teammates from publishing/unpublishing' do
      expect(subject).not_to permit(other_teammate, teammate_milestone)
    end
  end

  permissions :publish_to_public_profile? do
    it 'allows only the receiver to publish to public profile' do
      expect(subject).to permit(teammate, teammate_milestone)
    end

    it 'denies the certifier from publishing to public profile' do
      certifier_teammate = teammate_milestone.certifying_teammate
      expect(subject).not_to permit(certifier_teammate, teammate_milestone)
    end

    it 'denies managers from publishing to public profile' do
      manager_teammate_company = CompanyTeammate.find(manager_teammate.id)
      create(:employment_tenure, 
             teammate: teammate, 
             company: organization, 
             manager_teammate: manager_teammate_company)
      
      expect(subject).not_to permit(manager_teammate_company, teammate_milestone)
    end

    it 'denies other teammates from publishing to public profile' do
      expect(subject).not_to permit(other_teammate, teammate_milestone)
    end
  end

  describe 'Scope' do
    let(:scope) { Pundit.policy_scope(teammate, TeammateMilestone) }
    
    before do
      # Ensure teammates are CompanyTeammate instances
      teammate.reload if teammate.respond_to?(:reload)
      other_teammate.reload if other_teammate.respond_to?(:reload)
      
      # Create milestones for different teammates
      create(:teammate_milestone, teammate: teammate, ability: ability)
      create(:teammate_milestone, teammate: other_teammate, ability: ability)
    end

    context 'when user has manage_employment permission' do
      before do
        teammate.update!(can_manage_employment: true)
      end

      it 'returns all milestones in the organization' do
        expect(scope.count).to eq(2)
      end
    end

    context 'when user does not have manage_employment permission' do
      it 'returns only their own milestones' do
        expect(scope.count).to eq(1)
        expect(scope.first.teammate).to eq(teammate)
      end
    end
  end
end

