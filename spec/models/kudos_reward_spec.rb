require 'rails_helper'

RSpec.describe KudosReward, type: :model do
  let(:organization) { create(:organization) }

  describe 'validations' do
    it 'is valid with proper attributes' do
      reward = build(:kudos_reward, organization: organization)
      expect(reward).to be_valid
    end

    it 'requires a name' do
      reward = build(:kudos_reward, name: nil)
      expect(reward).not_to be_valid
      expect(reward.errors[:name]).to include("can't be blank")
    end

    it 'requires a cost_in_points' do
      reward = build(:kudos_reward, cost_in_points: nil)
      expect(reward).not_to be_valid
    end

    it 'requires cost_in_points to be positive' do
      reward = build(:kudos_reward, cost_in_points: 0)
      expect(reward).not_to be_valid
      expect(reward.errors[:cost_in_points]).to include("must be greater than 0")
    end

    it 'requires cost_in_points to be in 0.5 increments' do
      reward = build(:kudos_reward, cost_in_points: 10.3)
      expect(reward).not_to be_valid
      expect(reward.errors[:cost_in_points]).to include("must be in 0.5 increments")
    end

    it 'allows cost_in_points in 0.5 increments' do
      reward = build(:kudos_reward, cost_in_points: 10.5)
      expect(reward).to be_valid
    end

    it 'requires a valid reward_type' do
      reward = build(:kudos_reward, reward_type: 'invalid')
      expect(reward).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_reward) { create(:kudos_reward, organization: organization, active: true) }
    let!(:inactive_reward) { create(:kudos_reward, :inactive, organization: organization) }
    let!(:deleted_reward) { create(:kudos_reward, :deleted, organization: organization) }
    let!(:cheap_reward) { create(:kudos_reward, :cheap, organization: organization) }
    let!(:expensive_reward) { create(:kudos_reward, :expensive, organization: organization) }

    describe '.active' do
      it 'returns only active, non-deleted rewards' do
        expect(KudosReward.active).to include(active_reward, cheap_reward, expensive_reward)
        expect(KudosReward.active).not_to include(inactive_reward, deleted_reward)
      end
    end

    describe '.for_organization' do
      it 'filters by organization' do
        other_org = create(:organization)
        other_reward = create(:kudos_reward, organization: other_org)

        expect(KudosReward.for_organization(organization)).to include(active_reward)
        expect(KudosReward.for_organization(organization)).not_to include(other_reward)
      end
    end

    describe '.affordable_with' do
      it 'returns rewards that cost less than or equal to the given points' do
        affordable = KudosReward.affordable_with(100)
        expect(affordable).to include(cheap_reward, active_reward)
        expect(affordable).not_to include(expensive_reward)
      end
    end
  end

  describe 'instance methods' do
    let(:reward) { create(:kudos_reward, organization: organization, cost_in_points: 100) }

    describe '#available?' do
      it 'returns true for active, non-deleted rewards' do
        expect(reward.available?).to be true
      end

      it 'returns false for inactive rewards' do
        reward.update!(active: false)
        expect(reward.available?).to be false
      end

      it 'returns false for deleted rewards' do
        reward.soft_delete!
        expect(reward.available?).to be false
      end
    end

    describe '#soft_delete!' do
      it 'sets deleted_at' do
        expect { reward.soft_delete! }.to change { reward.deleted? }.from(false).to(true)
      end
    end

    describe '#cost_in_dollars' do
      it 'returns the cost in dollars (10 points = $1)' do
        expect(reward.cost_in_dollars).to eq(10.0)
      end
    end

    describe '#display_cost' do
      it 'returns a formatted cost string' do
        expect(reward.display_cost).to eq("100 points")
      end

      it 'shows decimal points if present' do
        reward.update!(cost_in_points: 10.5)
        expect(reward.display_cost).to include("10.5 points")
      end
    end

    describe 'type helpers' do
      it '#gift_card? returns true for gift_card type' do
        reward = build(:kudos_reward, :gift_card)
        expect(reward.gift_card?).to be true
        expect(reward.merchandise?).to be false
      end

      it '#merchandise? returns true for merchandise type' do
        reward = build(:kudos_reward, :merchandise)
        expect(reward.merchandise?).to be true
      end
    end

    describe 'metadata helpers' do
      let(:reward) { create(:kudos_reward, :gift_card, organization: organization) }

      it '#provider returns the provider from metadata' do
        expect(reward.provider).to eq('Tremendous')
      end

      it '#provider= sets the provider in metadata' do
        reward.provider = 'NewProvider'
        expect(reward.metadata['provider']).to eq('NewProvider')
      end
    end
  end
end
