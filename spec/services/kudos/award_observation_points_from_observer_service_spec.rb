require 'rails_helper'

RSpec.describe Kudos::AwardObservationPointsFromObserverService do
  let(:organization) { create(:organization) }
  let(:observer_person) { create(:person) }
  let!(:observer_teammate) { create(:company_teammate, person: observer_person, organization: organization) }

  def build_observation(org:, observer:, observees:, published: true)
    obs = Observation.new(
      company: org,
      observer: observer,
      story: "Great work! #{rand(1000)}",
      privacy_level: :observed_only,
      observed_at: Time.current,
      published_at: published ? Time.current : nil
    )
    observees.each do |teammate|
      obs.observees.build(company_teammate: teammate)
    end
    obs.save!
    obs
  end

  describe '.call' do
    context 'with a single observee' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 50.0, points_to_spend: 0)
      end

      it 'creates observer debit, point exchange, and kickback transactions' do
        expect {
          described_class.call(observation: observation, points_total: 10)
        }.to change(ObserverGiveTransaction, :count).by(1)
          .and change(PointsExchangeTransaction, :count).by(1)
          .and change(KickbackRewardTransaction, :count).by(1)
      end

      it 'returns a successful result' do
        result = described_class.call(observation: observation, points_total: 10)
        expect(result.ok?).to be true
        expect(result.value.count).to eq(3)
      end

      it 'deducts from observer points_to_give' do
        described_class.call(observation: observation, points_total: 10)
        expect(observer_teammate.kudos_ledger.reload.points_to_give).to eq(40.0)
      end

      it 'awards points to observee' do
        described_class.call(observation: observation, points_total: 10)
        expect(observee_teammate.kudos_ledger.reload.points_to_spend).to eq(10.0)
      end
    end

    context 'with multiple observees' do
      let(:observee_teammate1) { create(:company_teammate, organization: organization) }
      let(:observee_teammate2) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate1, observee_teammate2]) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 50.0, points_to_spend: 0)
      end

      it 'splits points equally between observees' do
        described_class.call(observation: observation, points_total: 10)
        expect(observee_teammate1.kudos_ledger.reload.points_to_spend).to eq(5.0)
        expect(observee_teammate2.kudos_ledger.reload.points_to_spend).to eq(5.0)
      end

      it 'deducts full total from observer' do
        described_class.call(observation: observation, points_total: 10)
        expect(observer_teammate.kudos_ledger.reload.points_to_give).to eq(40.0)
      end
    end

    context 'when observer is in observees list' do
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observer_teammate]) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 50.0, points_to_spend: 0)
      end

      it 'excludes observer from recipients and returns error' do
        result = described_class.call(observation: observation, points_total: 10)
        expect(result.ok?).to be false
        expect(result.error).to include('no observees')
        expect(PointsExchangeTransaction.exists?(observation: observation)).to be false
      end
    end

    context 'when insufficient balance' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 2.0, points_to_spend: 0)
      end

      it 'returns error and does not create transactions' do
        result = described_class.call(observation: observation, points_total: 10)
        expect(result.ok?).to be false
        expect(result.error).to be_present
        expect(PointsExchangeTransaction.exists?(observation: observation)).to be false
        expect(ObserverGiveTransaction.exists?(observation: observation)).to be false
      end
    end

    context 'when already processed' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate]) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 50.0, points_to_spend: 0)
        create(:points_exchange_transaction, observation: observation, company_teammate: observee_teammate, organization: organization, points_to_spend_delta: 10)
      end

      it 'returns error' do
        result = described_class.call(observation: observation, points_total: 5)
        expect(result.ok?).to be false
        expect(result.error).to include('already processed')
      end
    end

    context 'when observation is not published' do
      let(:observee_teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { build_observation(org: organization, observer: observer_person, observees: [observee_teammate], published: false) }

      before do
        create(:kudos_points_ledger, company_teammate: observer_teammate, organization: organization, points_to_give: 50.0, points_to_spend: 0)
      end

      it 'returns error' do
        result = described_class.call(observation: observation, points_total: 10)
        expect(result.ok?).to be false
        expect(result.error).to include('not published')
      end
    end
  end
end
