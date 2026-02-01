require 'rails_helper'

RSpec.describe TeamMember, type: :model do
  describe 'associations' do
    it { should belong_to(:team) }
    it { should belong_to(:company_teammate).class_name('Teammate') }
  end

  describe 'validations' do
    let(:team) { create(:team) }
    let(:company_teammate) { create(:company_teammate, organization: team.company) }
    subject { build(:team_member, team: team, company_teammate: company_teammate) }

    it { should validate_presence_of(:team) }
    it { should validate_presence_of(:company_teammate) }
    it { should validate_uniqueness_of(:company_teammate_id).scoped_to(:team_id).with_message('is already a member of this team') }
  end

  describe 'delegations' do
    let(:company) { create(:organization, :company) }
    let(:person) { create(:person) }
    let(:company_teammate) { create(:company_teammate, organization: company, person: person) }
    let(:team) { create(:team, company: company) }
    let(:team_member) { create(:team_member, team: team, company_teammate: company_teammate) }

    it 'delegates person to company_teammate' do
      expect(team_member.person).to eq(person)
    end
  end

  describe 'scopes' do
    let(:company) { create(:organization, :company) }
    let(:team1) { create(:team, company: company) }
    let(:team2) { create(:team, company: company) }
    let(:teammate1) { create(:company_teammate, organization: company) }
    let(:teammate2) { create(:company_teammate, organization: company) }
    let!(:member1) { create(:team_member, team: team1, company_teammate: teammate1) }
    let!(:member2) { create(:team_member, team: team1, company_teammate: teammate2) }
    let!(:member3) { create(:team_member, team: team2, company_teammate: teammate1) }

    describe '.for_team' do
      it 'returns members for the specified team' do
        expect(described_class.for_team(team1)).to include(member1, member2)
        expect(described_class.for_team(team1)).not_to include(member3)
      end
    end

    describe '.for_teammate' do
      it 'returns memberships for the specified teammate' do
        expect(described_class.for_teammate(teammate1)).to include(member1, member3)
        expect(described_class.for_teammate(teammate1)).not_to include(member2)
      end
    end
  end
end
