require 'rails_helper'

RSpec.describe Team, type: :model do
  describe 'associations' do
    it { should belong_to(:company).class_name('Organization') }
    it { should have_many(:team_members).dependent(:destroy) }
    it { should have_many(:company_teammates).through(:team_members) }
    it { should have_many(:people).through(:company_teammates) }
    it { should have_many(:huddles).dependent(:destroy) }
    it { should have_many(:third_party_object_associations).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:company) }
  end

  describe 'scopes' do
    let!(:company) { create(:organization, :company) }
    let!(:other_company) { create(:organization, :company) }
    let!(:active_team) { create(:team, company: company) }
    let!(:archived_team) { create(:team, :archived, company: company) }
    let!(:other_team) { create(:team, company: other_company) }

    describe '.active' do
      it 'returns only active teams' do
        expect(described_class.active).to include(active_team, other_team)
        expect(described_class.active).not_to include(archived_team)
      end
    end

    describe '.archived' do
      it 'returns only archived teams' do
        expect(described_class.archived).to include(archived_team)
        expect(described_class.archived).not_to include(active_team, other_team)
      end
    end

    describe '.for_company' do
      it 'returns teams for the specified company' do
        expect(described_class.for_company(company)).to include(active_team, archived_team)
        expect(described_class.for_company(company)).not_to include(other_team)
      end
    end

    describe '.ordered' do
      let!(:team_z) { create(:team, company: company, name: 'Z Team') }
      let!(:team_a) { create(:team, company: company, name: 'A Team') }

      it 'returns teams ordered by name' do
        ordered = described_class.for_company(company).ordered
        names = ordered.map(&:name)
        expect(names).to eq(names.sort)
      end
    end
  end

  describe 'instance methods' do
    let(:team) { create(:team) }

    describe '#soft_delete!' do
      it 'sets deleted_at to current time' do
        expect { team.soft_delete! }.to change { team.deleted_at }.from(nil)
        expect(team.deleted_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#restore!' do
      let(:archived_team) { create(:team, :archived) }

      it 'sets deleted_at to nil' do
        expect { archived_team.restore! }.to change { archived_team.deleted_at }.to(nil)
      end
    end

    describe '#archived?' do
      it 'returns true when deleted_at is present' do
        team.deleted_at = Time.current
        expect(team.archived?).to be true
      end

      it 'returns false when deleted_at is nil' do
        expect(team.archived?).to be false
      end
    end

    describe '#active?' do
      it 'returns true when deleted_at is nil' do
        expect(team.active?).to be true
      end

      it 'returns false when deleted_at is present' do
        team.deleted_at = Time.current
        expect(team.active?).to be false
      end
    end

    describe '#display_name' do
      it 'returns the team name' do
        expect(team.display_name).to eq(team.name)
      end
    end

    describe '#to_param' do
      it 'returns id with parameterized name' do
        team = create(:team, name: 'Engineering Team')
        expect(team.to_param).to eq("#{team.id}-engineering-team")
      end
    end
  end
end
