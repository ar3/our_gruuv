require 'rails_helper'

RSpec.describe Teammate, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  
  describe 'associations' do
    it { should belong_to(:person) }
    it { should belong_to(:organization) }
    it { should have_many(:teammate_identities).dependent(:destroy) }
    it { should have_one(:one_on_one_link).dependent(:destroy) }
  end
  
  describe 'validations' do
    it 'validates uniqueness of person_id scoped to organization_id' do
      existing_access = create(:teammate, person: person, organization: company)
      duplicate_access = build(:teammate, person: person, organization: company)
      
      expect(duplicate_access).not_to be_valid
      expect(duplicate_access.errors[:person_id]).to include('has already been taken')
    end
  end
  
  describe 'scopes' do
    let(:person2) { create(:person) }
    let(:person3) { create(:person) }
    let(:person4) { create(:person) }
    
    let!(:access1) { create(:teammate, person: person, organization: company) }
    let!(:access2) { create(:teammate, person: person2, organization: team) }
    
    describe '.for_organization_hierarchy' do
      it 'returns access records for company' do
        # Since Organization.self_and_descendants now returns just [self] for companies,
        # and team is actually created as a Company (not STI Team), this only returns company access
        result = described_class.for_organization_hierarchy(company)
        expect(result).to include(access1)
      end
      
      it 'returns access records for specific organization' do
        # team is created with :team trait which now creates a Company
        result = described_class.for_organization_hierarchy(team)
        expect(result).to include(access2)
      end
    end
    
    describe '.with_employment_management' do
      let!(:employment_access) { create(:teammate, :employment_manager, person: person3, organization: company) }
      
      it 'returns only access records with employment management' do
        result = described_class.with_employment_management
        expect(result).to include(employment_access)
        expect(result).not_to include(access1, access2)
      end
    end
    
    describe '.with_maap_management' do
      let!(:maap_access) { create(:teammate, :maap_manager, person: person4, organization: team) }
      
      it 'returns only access records with MAAP management' do
        result = described_class.with_maap_management
        expect(result).to include(maap_access)
        expect(result).not_to include(access1, access2)
      end
    end

    describe '.with_prompts_management' do
      let(:person5) { create(:person) }
      let!(:prompts_access) { create(:teammate, person: person5, organization: company, can_manage_prompts: true) }

      it 'returns only access records with prompts management' do
        result = described_class.with_prompts_management
        expect(result).to include(prompts_access)
        expect(result).not_to include(access1, access2)
      end
    end

    describe '.with_departments_and_teams_management' do
      let(:person6) { create(:person) }
      let!(:dept_teams_access) { create(:teammate, person: person6, organization: company, can_manage_departments_and_teams: true) }

      it 'returns only access records with departments and teams management' do
        result = described_class.with_departments_and_teams_management
        expect(result).to include(dept_teams_access)
        expect(result).not_to include(access1, access2)
      end
    end

    describe '.with_customize_company' do
      let(:person7) { create(:person) }
      let!(:customize_access) { create(:teammate, person: person7, organization: company, can_customize_company: true) }

      it 'returns only access records with customize company permission' do
        result = described_class.with_customize_company
        expect(result).to include(customize_access)
        expect(result).not_to include(access1, access2)
      end
    end

    describe '.employed' do
      let(:person_employed) { create(:person) }
      let(:person_not_employed) { create(:person) }
      let(:person_terminated) { create(:person) }

      let!(:employed_teammate) { create(:company_teammate, person: person_employed, organization: company, first_employed_at: 1.year.ago, last_terminated_at: nil) }
      let!(:not_employed_teammate) { create(:company_teammate, person: person_not_employed, organization: company, first_employed_at: nil, last_terminated_at: nil) }
      let!(:terminated_teammate) { create(:company_teammate, person: person_terminated, organization: company, first_employed_at: 1.year.ago, last_terminated_at: 1.day.ago) }

      it 'returns only currently employed teammates' do
        result = described_class.employed
        expect(result).to include(employed_teammate)
        expect(result).not_to include(not_employed_teammate, terminated_teammate)
      end
    end
  end
  
  describe 'instance methods' do
    let(:access) { create(:teammate, person: person, organization: company) }
    
    describe '#can_manage_employment?' do
      it 'returns true when can_manage_employment is true' do
        access.update!(can_manage_employment: true)
        expect(access.can_manage_employment?).to be true
      end
      
      it 'returns false when can_manage_employment is false' do
        access.update!(can_manage_employment: false)
        expect(access.can_manage_employment?).to be false
      end
      
      it 'returns false when can_manage_employment is nil' do
        access.update!(can_manage_employment: nil)
        expect(access.can_manage_employment?).to be false
      end
    end
    
    describe '#can_manage_maap?' do
      it 'returns true when can_manage_maap is true' do
        access.update!(can_manage_maap: true)
        expect(access.can_manage_maap?).to be true
      end
      
      it 'returns false when can_manage_maap is false' do
        access.update!(can_manage_maap: false)
        expect(access.can_manage_maap?).to be false
      end
      
      it 'returns false when can_manage_maap is nil' do
        access.update!(can_manage_maap: nil)
        expect(access.can_manage_maap?).to be false
      end
    end
    
    describe '#can_manage_prompts?' do
      it 'returns true when can_manage_prompts is true' do
        access.update!(can_manage_prompts: true)
        expect(access.can_manage_prompts?).to be true
      end

      it 'returns false when can_manage_prompts is false' do
        access.update!(can_manage_prompts: false)
        expect(access.can_manage_prompts?).to be false
      end

      it 'returns false when can_manage_prompts is nil' do
        access.update!(can_manage_prompts: nil)
        expect(access.can_manage_prompts?).to be false
      end
    end

    describe '#can_manage_departments_and_teams?' do
      it 'returns true when can_manage_departments_and_teams is true' do
        access.update!(can_manage_departments_and_teams: true)
        expect(access.can_manage_departments_and_teams?).to be true
      end

      it 'returns false when can_manage_departments_and_teams is false' do
        access.update!(can_manage_departments_and_teams: false)
        expect(access.can_manage_departments_and_teams?).to be false
      end

      it 'returns false when can_manage_departments_and_teams is nil' do
        access.update!(can_manage_departments_and_teams: nil)
        expect(access.can_manage_departments_and_teams?).to be false
      end
    end

    describe '#can_customize_company?' do
      it 'returns true when can_customize_company is true' do
        access.update!(can_customize_company: true)
        expect(access.can_customize_company?).to be true
      end

      it 'returns false when can_customize_company is false' do
        access.update!(can_customize_company: false)
        expect(access.can_customize_company?).to be false
      end

      it 'returns false when can_customize_company is nil' do
        access.update!(can_customize_company: nil)
        expect(access.can_customize_company?).to be false
      end
    end

    describe 'TeammateIdentity helper methods' do
      let(:teammate) { create(:teammate, person: person, organization: company) }
      
      describe '#slack_identity' do
        it 'returns the Slack identity when it exists' do
          slack_identity = create(:teammate_identity, :slack, teammate: teammate)
          expect(teammate.slack_identity).to eq(slack_identity)
        end
        
        it 'returns nil when no Slack identity exists' do
          expect(teammate.slack_identity).to be_nil
        end
      end
      
      describe '#slack_user_id' do
        it 'returns the Slack user ID when Slack identity exists' do
          slack_identity = create(:teammate_identity, :slack, teammate: teammate, uid: 'U1234567890')
          expect(teammate.slack_user_id).to eq('U1234567890')
        end
        
        it 'returns nil when no Slack identity exists' do
          expect(teammate.slack_user_id).to be_nil
        end
      end
      
      describe '#has_slack_identity?' do
        it 'returns true when Slack identity exists' do
          create(:teammate_identity, :slack, teammate: teammate)
          expect(teammate.has_slack_identity?).to be true
        end
        
        it 'returns false when no Slack identity exists' do
          expect(teammate.has_slack_identity?).to be false
        end
      end
      
      describe '#jira_identity' do
        it 'returns the Jira identity when it exists' do
          jira_identity = create(:teammate_identity, :jira, teammate: teammate)
          expect(teammate.jira_identity).to eq(jira_identity)
        end
        
        it 'returns nil when no Jira identity exists' do
          expect(teammate.jira_identity).to be_nil
        end
      end
      
      describe '#jira_user_id' do
        it 'returns the Jira user ID when Jira identity exists' do
          jira_identity = create(:teammate_identity, :jira, teammate: teammate, uid: 'jira_user_123')
          expect(teammate.jira_user_id).to eq('jira_user_123')
        end
        
        it 'returns nil when no Jira identity exists' do
          expect(teammate.jira_user_id).to be_nil
        end
      end
      
      describe '#has_jira_identity?' do
        it 'returns true when Jira identity exists' do
          create(:teammate_identity, :jira, teammate: teammate)
          expect(teammate.has_jira_identity?).to be true
        end
        
        it 'returns false when no Jira identity exists' do
          expect(teammate.has_jira_identity?).to be false
        end
      end
      
      describe '#linear_identity' do
        it 'returns the Linear identity when it exists' do
          linear_identity = create(:teammate_identity, :linear, teammate: teammate)
          expect(teammate.linear_identity).to eq(linear_identity)
        end
        
        it 'returns nil when no Linear identity exists' do
          expect(teammate.linear_identity).to be_nil
        end
      end
      
      describe '#linear_user_id' do
        it 'returns the Linear user ID when Linear identity exists' do
          linear_identity = create(:teammate_identity, :linear, teammate: teammate, uid: 'linear_user_123')
          expect(teammate.linear_user_id).to eq('linear_user_123')
        end
        
        it 'returns nil when no Linear identity exists' do
          expect(teammate.linear_user_id).to be_nil
        end
      end
      
      describe '#has_linear_identity?' do
        it 'returns true when Linear identity exists' do
          create(:teammate_identity, :linear, teammate: teammate)
          expect(teammate.has_linear_identity?).to be true
        end
        
        it 'returns false when no Linear identity exists' do
          expect(teammate.has_linear_identity?).to be false
        end
      end
      
      describe '#asana_identity' do
        it 'returns the Asana identity when it exists' do
          asana_identity = create(:teammate_identity, :asana, teammate: teammate)
          expect(teammate.asana_identity).to eq(asana_identity)
        end
        
        it 'returns nil when no Asana identity exists' do
          expect(teammate.asana_identity).to be_nil
        end
      end
      
      describe '#asana_user_id' do
        it 'returns the Asana user ID when Asana identity exists' do
          asana_identity = create(:teammate_identity, :asana, teammate: teammate, uid: 'asana_user_123')
          expect(teammate.asana_user_id).to eq('asana_user_123')
        end
        
        it 'returns nil when no Asana identity exists' do
          expect(teammate.asana_user_id).to be_nil
        end
      end
      
      describe '#has_asana_identity?' do
        it 'returns true when Asana identity exists' do
          create(:teammate_identity, :asana, teammate: teammate)
          expect(teammate.has_asana_identity?).to be true
        end
        
        it 'returns false when no Asana identity exists' do
          expect(teammate.has_asana_identity?).to be false
        end
      end
      
      describe '#identity_for' do
        it 'returns the identity for a specific provider' do
          slack_identity = create(:teammate_identity, :slack, teammate: teammate)
          jira_identity = create(:teammate_identity, :jira, teammate: teammate)
          
          expect(teammate.identity_for('slack')).to eq(slack_identity)
          expect(teammate.identity_for('jira')).to eq(jira_identity)
          expect(teammate.identity_for('linear')).to be_nil
        end
        
        it 'handles string and symbol providers' do
          slack_identity = create(:teammate_identity, :slack, teammate: teammate)
          
          expect(teammate.identity_for('slack')).to eq(slack_identity)
          expect(teammate.identity_for(:slack)).to eq(slack_identity)
        end
      end

      describe '#profile_image_url' do
        context 'when teammate has Slack identity with profile image' do
          let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate, profile_image_url: 'https://slack.com/avatar.jpg') }

          it 'returns Slack profile image URL' do
            expect(teammate.profile_image_url).to eq('https://slack.com/avatar.jpg')
          end
        end

        context 'when teammate has no Slack identity but person has Google identity' do
          let!(:google_identity) { create(:person_identity, :google, person: person, profile_image_url: 'https://google.com/avatar.jpg') }

          it 'returns Google profile image URL' do
            expect(teammate.profile_image_url).to eq('https://google.com/avatar.jpg')
          end
        end

        context 'when teammate has Slack identity without profile image but person has Google identity' do
          let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate, profile_image_url: nil) }
          let!(:google_identity) { create(:person_identity, :google, person: person, profile_image_url: 'https://google.com/avatar.jpg') }

          it 'returns Google profile image URL' do
            expect(teammate.profile_image_url).to eq('https://google.com/avatar.jpg')
          end
        end

        context 'when teammate has no identities' do
          it 'returns nil' do
            expect(teammate.profile_image_url).to be_nil
          end
        end
      end
      
      describe 'cascade deletion' do
        it 'destroys teammate identities when teammate is destroyed' do
          slack_identity = create(:teammate_identity, :slack, teammate: teammate)
          jira_identity = create(:teammate_identity, :jira, teammate: teammate)
          
          expect { teammate.destroy }.to change { TeammateIdentity.count }.by(-2)
          expect(TeammateIdentity.exists?(slack_identity.id)).to be false
          expect(TeammateIdentity.exists?(jira_identity.id)).to be false
        end
      end
    end
  end
  
  describe 'class methods' do
    let!(:access) { create(:teammate, person: person, organization: company) }
    
    describe '.can_manage_employment?' do
      it 'returns true when person has employment management access' do
        access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment?(person, company)).to be true
      end
      
      it 'returns false when person does not have employment management access' do
        access.update!(can_manage_employment: false)
        expect(described_class.can_manage_employment?(person, company)).to be false
      end
      
      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_manage_employment?(person, company)).to be false
      end
    end
    
    describe '.can_manage_maap?' do
      it 'returns true when person has MAAP management access' do
        access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap?(person, company)).to be true
      end
      
      it 'returns false when person does not have MAAP management access' do
        access.update!(can_manage_maap: false)
        expect(described_class.can_manage_maap?(person, company)).to be false
      end
      
      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_manage_maap?(person, company)).to be false
      end
    end
    
    describe '.can_manage_employment_in_hierarchy?' do
      # Note: With departments/teams de-STI'd, hierarchy only checks self_and_descendants
      # which returns [self] for companies. Parent traversal only works for non-company orgs.
      
      it 'returns true when person has employment management access at organization level' do
        access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment_in_hierarchy?(person, company)).to be true
      end
      
      it 'returns true when person has employment management access at company level for company check' do
        access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment_in_hierarchy?(person, company)).to be true
      end
      
      it 'returns false when person has no employment management access in hierarchy' do
        access.update!(can_manage_employment: false)
        expect(described_class.can_manage_employment_in_hierarchy?(person, company)).to be false
      end
    end
    
    describe '.can_manage_maap_in_hierarchy?' do
      it 'returns true when person has MAAP management access at organization level' do
        access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap_in_hierarchy?(person, company)).to be true
      end
      
      it 'returns true when person has MAAP management access at company level for company check' do
        access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap_in_hierarchy?(person, company)).to be true
      end
      
      it 'returns false when person has no MAAP management access in hierarchy' do
        access.update!(can_manage_maap: false)
        expect(described_class.can_manage_maap_in_hierarchy?(person, company)).to be false
      end
    end

    describe '.can_manage_prompts_in_hierarchy?' do
      it 'returns true when person has prompts management access at organization level' do
        access.update!(can_manage_prompts: true)
        expect(described_class.can_manage_prompts_in_hierarchy?(person, company)).to be true
      end

      it 'returns true when person has prompts management access at company level for company check' do
        access.update!(can_manage_prompts: true)
        expect(described_class.can_manage_prompts_in_hierarchy?(person, company)).to be true
      end

      it 'returns false when person has no prompts management access in hierarchy' do
        access.update!(can_manage_prompts: false)
        expect(described_class.can_manage_prompts_in_hierarchy?(person, company)).to be false
      end
    end

    describe '.can_manage_departments_and_teams?' do
      it 'returns true when person has departments and teams management access' do
        access.update!(can_manage_departments_and_teams: true)
        expect(described_class.can_manage_departments_and_teams?(person, company)).to be true
      end

      it 'returns false when person does not have departments and teams management access' do
        access.update!(can_manage_departments_and_teams: false)
        expect(described_class.can_manage_departments_and_teams?(person, company)).to be false
      end

      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_manage_departments_and_teams?(person, company)).to be false
      end
    end

    describe '.can_manage_departments_and_teams_in_hierarchy?' do
      it 'returns true when person has departments and teams management access at organization level' do
        access.update!(can_manage_departments_and_teams: true)
        expect(described_class.can_manage_departments_and_teams_in_hierarchy?(person, company)).to be true
      end

      it 'returns true when person has departments and teams management access at company level for company check' do
        access.update!(can_manage_departments_and_teams: true)
        expect(described_class.can_manage_departments_and_teams_in_hierarchy?(person, company)).to be true
      end

      it 'returns false when person has no departments and teams management access in hierarchy' do
        access.update!(can_manage_departments_and_teams: false)
        expect(described_class.can_manage_departments_and_teams_in_hierarchy?(person, company)).to be false
      end
    end

    describe '.can_customize_company?' do
      it 'returns true when person has customize company access' do
        access.update!(can_customize_company: true)
        expect(described_class.can_customize_company?(person, company)).to be true
      end

      it 'returns false when person does not have customize company access' do
        access.update!(can_customize_company: false)
        expect(described_class.can_customize_company?(person, company)).to be false
      end

      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_customize_company?(person, company)).to be false
      end
    end

    describe '.can_customize_company_in_hierarchy?' do
      it 'returns true when person has customize company access at organization level' do
        access.update!(can_customize_company: true)
        expect(described_class.can_customize_company_in_hierarchy?(person, company)).to be true
      end

      it 'returns true when person has customize company access at company level for company check' do
        access.update!(can_customize_company: true)
        expect(described_class.can_customize_company_in_hierarchy?(person, company)).to be true
      end

      it 'returns false when person has no customize company access in hierarchy' do
        access.update!(can_customize_company: false)
        expect(described_class.can_customize_company_in_hierarchy?(person, company)).to be false
      end
    end
  end
end
