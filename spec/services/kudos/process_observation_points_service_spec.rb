require 'rails_helper'

RSpec.describe Kudos::ProcessObservationPointsService do
  let(:organization) { create(:organization) }
  let(:observer_person) { create(:person) }
  # Use let! to ensure observer_teammate is created before observation is built
  let!(:observer_teammate) { create(:company_teammate, person: observer_person, organization: organization) }

  # Build observation manually to control observees explicitly
  def build_observation(org:, observer:, observees:, published: true, observable_moment: nil)
    obs = Observation.new(
      company: org,
      observer: observer,
      story: "Great work! #{rand(1000)}",
      privacy_level: :observed_only,
      observed_at: Time.current,
      published_at: published ? Time.current : nil,
      observable_moment: observable_moment
    )
    observees.each do |teammate|
      obs.observees.build(company_teammate: teammate)
    end
    obs.save!
    obs
  end

  describe '.call' do
    context 'with a recognition observation (positive ratings)' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      it 'creates point exchange and kickback transactions' do
        expect {
          described_class.call(observation: observation)
        }.to change(KudosTransaction, :count).by(2)
      end

      it 'returns a successful result' do
        result = described_class.call(observation: observation)

        expect(result.ok?).to be true
        expect(result.value.count).to eq(2)
      end

      it 'awards points to observee' do
        described_class.call(observation: observation)

        ledger = observee_teammate.kudos_ledger.reload
        expect(ledger.points_to_spend).to eq(10.0)  # Default recognition points
      end

      it 'awards kickback to observer' do
        described_class.call(observation: observation)

        ledger = observer_teammate.kudos_ledger.reload
        expect(ledger.points_to_give).to eq(5.0)  # 10 * 0.5 = 5 kickback
      end

      it 'creates correct transaction types' do
        result = described_class.call(observation: observation)

        exchange = result.value.find { |t| t.is_a?(PointsExchangeTransaction) }
        kickback = result.value.find { |t| t.is_a?(KickbackRewardTransaction) }

        expect(exchange).to be_present
        expect(kickback).to be_present
        expect(exchange.company_teammate).to eq(observee_teammate)
        expect(kickback.company_teammate).to eq(observer_teammate)
      end
    end

    context 'with a constructive observation (negative ratings)' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:ability) { create(:ability, company: organization) }
      let(:observation) do
        obs = build_observation(org: organization, observer: observer_person, observees: [observee_teammate])
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        obs.reload
      end

      it 'awards points to observee from company bank' do
        described_class.call(observation: observation)

        ledger = observee_teammate.kudos_ledger.reload
        expect(ledger.points_to_spend).to eq(5.0)  # Default constructive points
      end

      it 'awards larger kickback to observer' do
        described_class.call(observation: observation)

        ledger = observer_teammate.kudos_ledger.reload
        expect(ledger.points_to_give).to eq(2.0)   # Constructive kickback
        expect(ledger.points_to_spend).to eq(2.0)  # Constructive kickback
      end
    end

    context 'with multiple observees' do
      let(:observee_teammate1) { create(:company_teammate, organization: organization) }
      let(:observee_teammate2) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate1, observee_teammate2]) }

      it 'splits points among observees (rounded up to 0.5)' do
        described_class.call(observation: observation)

        ledger1 = observee_teammate1.kudos_ledger.reload
        ledger2 = observee_teammate2.kudos_ledger.reload

        # 10 points / 2 observees = 5 each
        expect(ledger1.points_to_spend).to eq(5.0)
        expect(ledger2.points_to_spend).to eq(5.0)
      end

      it 'scales observer kickback by total points given' do
        described_class.call(observation: observation)

        ledger = observer_teammate.kudos_ledger.reload
        # 2 observees * 5 points each = 10 total, * 0.5 = 5 kickback
        expect(ledger.points_to_give).to eq(5.0)
      end
    end

    context 'when observation is not published' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate], published: false) }

      it 'returns an error result' do
        result = described_class.call(observation: observation)

        expect(result.ok?).to be false
        expect(result.error).to include("not published")
      end
    end

    context 'when points were already processed' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      before do
        create(:points_exchange_transaction,
          company_teammate: observee_teammate,
          organization: organization,
          observation: observation)
      end

      it 'returns an error result' do
        result = described_class.call(observation: observation)

        expect(result.ok?).to be false
        expect(result.error).to include("already processed")
      end

      it 'does not create duplicate transactions' do
        expect {
          described_class.call(observation: observation)
        }.not_to change(KudosTransaction, :count)
      end
    end

    context 'when observer is not a teammate' do
      let(:outside_person) { create(:person) }
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: outside_person, observees: [observee_teammate]) }

      it 'returns an error result' do
        result = described_class.call(observation: observation)

        expect(result.ok?).to be false
        expect(result.error).to include("not a teammate")
      end
    end

    context 'with organization-specific configuration' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      before do
        organization.update!(kudos_celebratory_config: {
          'observation_recognition' => {
            'points_per_observee' => 20,
            'observer_kickback_give' => 1.0
          }
        })
      end

      it 'uses organization-specific configuration' do
        described_class.call(observation: observation)

        observee_ledger = observee_teammate.kudos_ledger.reload
        observer_ledger = observer_teammate.kudos_ledger.reload

        expect(observee_ledger.points_to_spend).to eq(20.0)
        expect(observer_ledger.points_to_give).to eq(20.0)  # 20 * 1.0 = 20
      end
    end
  end
end
