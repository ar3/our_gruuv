require 'rails_helper'

RSpec.describe KudosRedemption, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:reward) { create(:kudos_reward, organization: organization, cost_in_points: 100) }

  describe 'validations' do
    it 'is valid with proper attributes' do
      redemption = build(:kudos_redemption,
        organization: organization,
        company_teammate: teammate,
        kudos_reward: reward,
        points_spent: 100)
      expect(redemption).to be_valid
    end

    it 'requires points_spent' do
      redemption = build(:kudos_redemption, points_spent: nil)
      expect(redemption).not_to be_valid
    end

    it 'requires points_spent to be positive' do
      redemption = build(:kudos_redemption, points_spent: 0)
      expect(redemption).not_to be_valid
    end

    it 'requires points_spent to be an integer' do
      redemption = build(:kudos_redemption, points_spent: 10.3)
      expect(redemption).not_to be_valid
      expect(redemption.errors[:points_spent]).to include("must be an integer")
    end

    it 'requires a valid status' do
      redemption = build(:kudos_redemption, status: 'invalid')
      expect(redemption).not_to be_valid
    end

    it 'requires reward to be in the same organization' do
      other_org = create(:organization)
      other_reward = create(:kudos_reward, organization: other_org)
      # Build directly without factory to avoid auto-correction
      redemption = KudosRedemption.new(
        organization: organization,
        company_teammate: teammate,
        kudos_reward: other_reward,
        points_spent: 100,
        status: 'pending')
      expect(redemption).not_to be_valid
      expect(redemption.errors[:kudos_reward]).to include("must belong to the same organization")
    end

    it 'requires teammate to be in the same organization' do
      other_org = create(:organization)
      other_teammate = create(:company_teammate, organization: other_org)
      # Build directly without factory to avoid auto-correction
      redemption = KudosRedemption.new(
        organization: organization,
        company_teammate: other_teammate,
        kudos_reward: reward,
        points_spent: 100,
        status: 'pending')
      expect(redemption).not_to be_valid
      expect(redemption.errors[:company_teammate]).to include("must belong to the same organization")
    end
  end

  describe 'scopes' do
    let!(:pending_redemption) { create(:kudos_redemption, :pending, organization: organization, company_teammate: teammate, kudos_reward: reward) }
    let!(:fulfilled_redemption) { create(:kudos_redemption, :fulfilled, organization: organization, company_teammate: teammate, kudos_reward: reward) }
    let!(:cancelled_redemption) { create(:kudos_redemption, :cancelled, organization: organization, company_teammate: teammate, kudos_reward: reward) }

    describe '.pending' do
      it 'returns only pending redemptions' do
        expect(KudosRedemption.pending).to include(pending_redemption)
        expect(KudosRedemption.pending).not_to include(fulfilled_redemption)
      end
    end

    describe '.fulfilled' do
      it 'returns only fulfilled redemptions' do
        expect(KudosRedemption.fulfilled).to include(fulfilled_redemption)
        expect(KudosRedemption.fulfilled).not_to include(pending_redemption)
      end
    end

    describe '.active' do
      it 'returns pending and processing redemptions' do
        expect(KudosRedemption.active).to include(pending_redemption)
        expect(KudosRedemption.active).not_to include(fulfilled_redemption, cancelled_redemption)
      end
    end

    describe '.completed' do
      it 'returns fulfilled, failed, and cancelled redemptions' do
        expect(KudosRedemption.completed).to include(fulfilled_redemption, cancelled_redemption)
        expect(KudosRedemption.completed).not_to include(pending_redemption)
      end
    end
  end

  describe 'state transitions' do
    let(:redemption) { create(:kudos_redemption, :pending, organization: organization, company_teammate: teammate, kudos_reward: reward) }

    describe '#mark_processing!' do
      it 'transitions from pending to processing' do
        expect { redemption.mark_processing! }.to change { redemption.status }.from('pending').to('processing')
      end

      it 'raises error if not pending' do
        redemption.update!(status: 'fulfilled')
        expect { redemption.mark_processing! }.to raise_error(KudosRedemption::InvalidStateTransition)
      end
    end

    describe '#mark_fulfilled!' do
      it 'transitions to fulfilled' do
        expect { redemption.mark_fulfilled! }.to change { redemption.status }.to('fulfilled')
        expect(redemption.fulfilled_at).to be_present
      end

      it 'sets external reference if provided' do
        redemption.mark_fulfilled!(external_ref: 'ext_123')
        expect(redemption.external_reference).to eq('ext_123')
      end
    end

    describe '#mark_failed!' do
      it 'transitions to failed' do
        expect { redemption.mark_failed!(reason: 'Test failure') }.to change { redemption.status }.to('failed')
        expect(redemption.notes).to include('Test failure')
      end
    end

    describe '#mark_cancelled!' do
      it 'transitions to cancelled' do
        expect { redemption.mark_cancelled!(reason: 'User request') }.to change { redemption.status }.to('cancelled')
        expect(redemption.notes).to include('User request')
      end

      it 'raises error if already fulfilled' do
        redemption.mark_fulfilled!
        expect { redemption.mark_cancelled! }.to raise_error(KudosRedemption::InvalidStateTransition)
      end
    end
  end

  describe 'instance methods' do
    let(:redemption) { create(:kudos_redemption, organization: organization, company_teammate: teammate, kudos_reward: reward, points_spent: 100) }

    describe '#redeemer_name' do
      it 'returns the teammate display name' do
        expect(redemption.redeemer_name).to eq(teammate.person.display_name)
      end
    end

    describe '#reward_name' do
      it 'returns the reward name' do
        expect(redemption.reward_name).to eq(reward.name)
      end
    end

    describe '#points_spent_in_dollars' do
      it 'returns the dollar value (10 points = $1)' do
        expect(redemption.points_spent_in_dollars).to eq(10.0)
      end
    end
  end
end
