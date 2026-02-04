require 'rails_helper'

RSpec.describe Observee, type: :model do
  let(:company) { create(:organization, :company) }
  let(:observation) { build(:observation, company: company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }
  let(:teammate) { create(:teammate, organization: company) }

  let(:observee) do
    build(:observee, observation: observation, teammate: teammate)
  end

  describe 'associations' do
    it { should belong_to(:observation) }
    it { should belong_to(:company_teammate) }
  end

  describe 'validations' do
    it { should validate_presence_of(:observation) }
    it { should validate_presence_of(:company_teammate) }
    
    it 'validates uniqueness of teammate_id scoped to observation_id' do
      observee.save!
      duplicate_observee = build(:observee, observation: observation, teammate: teammate)
      expect(duplicate_observee).not_to be_valid
      expect(duplicate_observee.errors[:teammate_id]).to include('has already been taken')
    end

    it 'validates teammate is in same company as observation' do
      other_company = create(:organization, :company)
      other_teammate = create(:teammate, organization: other_company)
      
      observee.teammate = other_teammate
      expect(observee).not_to be_valid
      expect(observee.errors[:company_teammate]).to include('must be in the same company as the observation')
    end

    it 'allows teammate from same company' do
      expect(observee).to be_valid
    end
  end

  describe 'uniqueness constraint' do
    before { observee.save! }

    it 'prevents duplicate teammate for same observation' do
      duplicate_observee = build(:observee, observation: observation, teammate: teammate)
      expect(duplicate_observee).not_to be_valid
      expect(duplicate_observee.errors[:teammate_id]).to include('has already been taken')
    end

    it 'allows same teammate for different observations' do
      other_observation = build(:observation, company: company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! }
      other_observee = build(:observee, observation: other_observation, teammate: teammate)
      expect(other_observee).to be_valid
    end
  end

  describe 'factory' do
    it 'creates valid observee' do
      expect(observee).to be_valid
    end

    it 'saves successfully' do
      expect { observee.save! }.not_to raise_error
    end
  end
end
