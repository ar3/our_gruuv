require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:company) { create(:organization, name: 'Acme Corp', type: 'Company') }
  let(:team) { create(:organization, name: 'Engineering', type: 'Team', parent: company) }
  let(:subteam) { create(:organization, name: 'Frontend', type: 'Team', parent: team) }

  describe '#display_name' do
    it 'returns just the name for organizations without parents' do
      expect(company.display_name).to eq('Acme Corp')
    end

    it 'returns hierarchical name for organizations with parents' do
      expect(team.display_name).to eq('Acme Corp > Engineering')
    end

    it 'returns full hierarchical path for deeply nested organizations' do
      expect(subteam.display_name).to eq('Acme Corp > Engineering > Frontend')
    end

    it 'handles multiple levels of nesting correctly' do
      department = create(:organization, name: 'Product', type: 'Team', parent: company)
      squad = create(:organization, name: 'Mobile', type: 'Team', parent: department)
      
      expect(squad.display_name).to eq('Acme Corp > Product > Mobile')
    end
  end

  describe '#company?' do
    it 'returns true for Company type' do
      expect(company.company?).to be true
    end

    it 'returns false for Team type' do
      expect(team.company?).to be false
    end
  end

  describe '#team?' do
    it 'returns true for Team type' do
      expect(team.team?).to be true
    end

    it 'returns false for Company type' do
      expect(company.team?).to be false
    end
  end

  describe '#root_company' do
    it 'returns self for company without parent' do
      expect(company.root_company).to eq(company)
    end

    it 'returns parent company for team' do
      expect(team.root_company).to eq(company)
    end

    it 'returns root company for deeply nested team' do
      expect(subteam.root_company).to eq(company)
    end
  end

  describe '#recent_huddle_playbooks' do
    let(:company) { create(:organization, :company, name: 'Test Company') }
    let(:team1) { create(:organization, :team, name: 'Team 1', parent: company) }
    let(:team2) { create(:organization, :team, name: 'Team 2', parent: company) }
    let(:subteam) { create(:organization, :team, name: 'Subteam', parent: team1) }
    
    let!(:company_playbook) { create(:huddle_playbook, organization: company) }
    let!(:team1_playbook) { create(:huddle_playbook, organization: team1) }
    let!(:team2_playbook) { create(:huddle_playbook, organization: team2) }
    let!(:subteam_playbook) { create(:huddle_playbook, organization: subteam) }
    
    let!(:company_huddle) { create(:huddle, huddle_playbook: company_playbook, started_at: 1.day.ago) }
    let!(:team1_huddle) { create(:huddle, huddle_playbook: team1_playbook, started_at: 2.days.ago) }
    let!(:team2_huddle) { create(:huddle, huddle_playbook: team2_playbook, started_at: 3.days.ago) }
    let!(:subteam_huddle) { create(:huddle, huddle_playbook: subteam_playbook, started_at: 4.days.ago) }
    
    # Create a separate playbook for the old huddle to avoid conflicts
    let!(:old_playbook) { create(:huddle_playbook, organization: company) }
    let!(:old_huddle) { create(:huddle, huddle_playbook: old_playbook, started_at: 7.weeks.ago) }

    context 'when include_descendants is false (default)' do
      it 'returns only playbooks from the current organization' do
        result = company.recent_huddle_playbooks(include_descendants: false)
        expect(result).to include(company_playbook)
        expect(result).not_to include(team1_playbook, team2_playbook, subteam_playbook)
      end

      it 'returns only playbooks with recent huddles' do
        result = company.recent_huddle_playbooks(include_descendants: false)
        expect(result).to include(company_playbook)
        expect(result).not_to include(old_huddle.huddle_playbook)
      end

      it 'includes organization associations' do
        result = company.recent_huddle_playbooks(include_descendants: false)
        expect(result.first.association(:organization).loaded?).to be true
      end
    end

    context 'when include_descendants is true' do
      it 'returns playbooks from the organization and all descendants' do
        result = company.recent_huddle_playbooks(include_descendants: true)
        expect(result).to include(company_playbook, team1_playbook, team2_playbook, subteam_playbook)
      end

      it 'returns only playbooks with recent huddles' do
        result = company.recent_huddle_playbooks(include_descendants: true)
        expect(result).to include(company_playbook, team1_playbook, team2_playbook, subteam_playbook)
        expect(result).not_to include(old_huddle.huddle_playbook)
      end

      it 'includes organization associations' do
        result = company.recent_huddle_playbooks(include_descendants: true)
        expect(result.first.association(:organization).loaded?).to be true
      end
    end

    context 'when called on a team' do
      it 'returns only playbooks from the team when include_descendants is false' do
        result = team1.recent_huddle_playbooks(include_descendants: false)
        expect(result).to include(team1_playbook)
        expect(result).not_to include(company_playbook, team2_playbook, subteam_playbook)
      end

      it 'returns playbooks from the team and its descendants when include_descendants is true' do
        result = team1.recent_huddle_playbooks(include_descendants: true)
        expect(result).to include(team1_playbook, subteam_playbook)
        expect(result).not_to include(company_playbook, team2_playbook)
      end
    end

    context 'with custom weeks_back parameter' do
      let!(:recent_huddle) { create(:huddle, huddle_playbook: company_playbook, started_at: 2.weeks.ago) }
      # Create a separate playbook for the old huddle to avoid conflicts
      let!(:old_playbook_2_weeks) { create(:huddle_playbook, organization: team1) }
      let!(:old_huddle_2_weeks) { create(:huddle, huddle_playbook: old_playbook_2_weeks, started_at: 3.weeks.ago) }

      it 'respects the weeks_back parameter' do
        result = company.recent_huddle_playbooks(include_descendants: true, weeks_back: 2)
        expect(result).to include(company_playbook)
        expect(result).not_to include(old_playbook_2_weeks) # 3 weeks ago is outside 2 week range
      end

      it 'defaults to 6 weeks when not specified' do
        result = company.recent_huddle_playbooks(include_descendants: true)
        expect(result).to include(company_playbook, team1_playbook, team2_playbook, subteam_playbook)
      end
    end

    context 'with no recent huddles' do
      let(:empty_company) { create(:organization, :company, name: 'Empty Company') }

      it 'returns empty array when no huddles exist' do
        result = empty_company.recent_huddle_playbooks(include_descendants: true)
        expect(result).to be_empty
      end
    end

    context 'with huddles but no playbooks' do
      let(:orphaned_huddle) { create(:huddle, huddle_playbook: nil, started_at: 1.day.ago) }

      it 'handles huddles without playbooks gracefully' do
        result = company.recent_huddle_playbooks(include_descendants: true)
        expect(result).not_to include(nil)
      end
    end
  end
end 