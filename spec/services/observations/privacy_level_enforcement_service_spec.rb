require 'rails_helper'

RSpec.describe Observations::PrivacyLevelEnforcementService do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_teammate) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }

  describe '.call' do
    context 'when privacy level is not public_to_world' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        obs
      end

      it 'returns false' do
        expect(described_class.call(observation)).to be false
      end

      it 'does not change privacy level' do
        expect { described_class.call(observation) }.not_to change { observation.reload.privacy_level }
      end
    end

    context 'when privacy level is public_to_world but no negative ratings exist' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_agree)
        create(:observation_rating, observation: obs, rateable: assignment, rating: :agree)
        obs
      end

      it 'returns false' do
        expect(described_class.call(observation)).to be false
      end

      it 'does not change privacy level' do
        expect { described_class.call(observation) }.not_to change { observation.reload.privacy_level }
      end
    end

    context 'when privacy level is public_to_world but only neutral ratings exist' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :na)
        obs
      end

      it 'returns false' do
        expect(described_class.call(observation)).to be false
      end

      it 'does not change privacy level' do
        expect { described_class.call(observation) }.not_to change { observation.reload.privacy_level }
      end
    end

    context 'when privacy level is public_to_world and negative ratings exist' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        obs
      end

      it 'returns true' do
        expect(described_class.call(observation)).to be true
      end

      it 'changes privacy level to observed_and_managers' do
        expect { described_class.call(observation) }.to change { observation.reload.privacy_level }.from('public_to_world').to('observed_and_managers')
      end
    end

    context 'when privacy level is public_to_world with mixed ratings including negative' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_agree)
        create(:observation_rating, observation: obs, rateable: assignment, rating: :disagree)
        obs
      end

      it 'returns true' do
        expect(described_class.call(observation)).to be true
      end

      it 'changes privacy level to observed_and_managers' do
        expect { described_class.call(observation) }.to change { observation.reload.privacy_level }.from('public_to_world').to('observed_and_managers')
      end
    end

    context 'when privacy level is public_to_world with strongly_disagree rating' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_disagree)
        obs
      end

      it 'returns true' do
        expect(described_class.call(observation)).to be true
      end

      it 'changes privacy level to observed_and_managers' do
        expect { described_class.call(observation) }.to change { observation.reload.privacy_level }.from('public_to_world').to('observed_and_managers')
      end
    end

    context 'when observation_ratings association is not loaded' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        # Clear association to simulate not loaded
        obs.association(:observation_ratings).reset
        obs
      end

      it 'reloads the association and detects negative ratings' do
        expect(described_class.call(observation)).to be true
        expect(observation.reload.privacy_level).to eq('observed_and_managers')
      end
    end

    context 'when observation has no ratings' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'returns false' do
        expect(described_class.call(observation)).to be false
      end

      it 'does not change privacy level' do
        expect { described_class.call(observation) }.not_to change { observation.reload.privacy_level }
      end
    end
  end
end

