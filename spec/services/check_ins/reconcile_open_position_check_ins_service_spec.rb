# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::ReconcileOpenPositionCheckInsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, person: create(:person), organization: organization) }
  let!(:active_tenure) do
    create(:employment_tenure, company_teammate: teammate, company: organization, ended_at: nil)
  end

  before do
    allow(Sentry).to receive(:set_context)
    allow(Sentry).to receive(:capture_message)
  end

  describe '.call' do
    context 'when there are no open position check-ins' do
      it 'returns no correction' do
        result = described_class.call(teammate: teammate)
        expect(result).to eq(merged: false, repointed: false, details: {})
      end

      it 'does not call Sentry' do
        described_class.call(teammate: teammate)
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    context 'when there is one open check-in attached to active tenure' do
      let!(:open_check_in) do
        create(:position_check_in, company_teammate: teammate, employment_tenure: active_tenure)
      end

      it 'returns no correction' do
        result = described_class.call(teammate: teammate)
        expect(result).to eq(merged: false, repointed: false, details: {})
      end

      it 'does not call Sentry' do
        described_class.call(teammate: teammate)
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    context 'when there is one open check-in attached to an ended tenure' do
      let!(:ended_tenure) do
        create(:employment_tenure, :inactive, company_teammate: teammate, company: organization)
      end
      let!(:open_check_in) do
        create(:position_check_in, company_teammate: teammate, employment_tenure: ended_tenure)
      end

      it 'repoints the check-in to the active tenure' do
        result = described_class.call(teammate: teammate)
        expect(result[:repointed]).to be true
        expect(result[:merged]).to be false
        open_check_in.reload
        expect(open_check_in.employment_tenure_id).to eq(active_tenure.id)
      end

      it 'sends a warning to Sentry with correction details' do
        described_class.call(teammate: teammate)
        expect(Sentry).to have_received(:set_context).with(
          'reconcile_open_position_check_ins',
          hash_including(
            teammate_id: teammate.id,
            merged: false,
            repointed: true,
            keeper_check_in_id: open_check_in.id,
            previous_employment_tenure_id: ended_tenure.id,
            employment_tenure_id: active_tenure.id
          )
        )
        expect(Sentry).to have_received(:capture_message).with(
          /Position check-in tenure correction:.*repointed.*open check-in\(s\) for teammate #{teammate.id}/,
          level: :warning,
          extra: hash_including(
            teammate_id: teammate.id,
            keeper_check_in_id: open_check_in.id,
            previous_employment_tenure_id: ended_tenure.id,
            employment_tenure_id: active_tenure.id
          )
        )
      end
    end

    context 'when there are two open check-ins (bad data)' do
      let!(:check_in_a) do
        create(:position_check_in,
          company_teammate: teammate,
          employment_tenure: active_tenure,
          check_in_started_on: 5.days.ago.to_date,
          employee_rating: 1,
          employee_private_notes: 'From A',
          updated_at: 2.days.ago)
      end
      let!(:check_in_b) do
        # Create as closed so "only one open" validation passes, then reopen via update_column
        create(:position_check_in, :closed,
          company_teammate: teammate,
          employment_tenure: active_tenure,
          check_in_started_on: 3.days.ago.to_date,
          manager_rating: 2,
          manager_private_notes: 'From B',
          updated_at: 1.day.ago)
      end

      before do
        check_in_b.update_columns(official_check_in_completed_at: nil, official_rating: nil, shared_notes: nil, finalized_by_teammate_id: nil)
      end

      it 'merges into one check-in and destroys the other' do
        expect(PositionCheckIn.where(company_teammate: teammate).open.count).to eq(2)
        result = described_class.call(teammate: teammate)
        expect(result[:merged]).to be true
        expect(PositionCheckIn.where(company_teammate: teammate).open.count).to eq(1)
        remaining = PositionCheckIn.where(company_teammate: teammate).open.first
        expect(remaining.id).to eq(check_in_a.id).or eq(check_in_b.id)
        expect(remaining.employment_tenure_id).to eq(active_tenure.id)
      end

      it 'uses earliest check_in_started_on and merges attributes by latest updated_at' do
        described_class.call(teammate: teammate)
        remaining = PositionCheckIn.where(company_teammate: teammate).open.first
        expect(remaining.check_in_started_on).to eq(5.days.ago.to_date)
        # When both have a value we take from the record with later updated_at (B)
        expect(remaining.manager_rating).to eq(2)
        expect(remaining.manager_private_notes).to eq('From B')
        expect(remaining.employment_tenure_id).to eq(active_tenure.id)
      end

      it 'sends a warning to Sentry with merge details' do
        described_class.call(teammate: teammate)
        expect(Sentry).to have_received(:capture_message).with(
          /Position check-in tenure correction:.*merged/,
          level: :warning,
          extra: hash_including(teammate_id: teammate.id, destroyed_check_in_ids: kind_of(Array))
        )
      end
    end

    context 'when there are two open check-ins and no active tenure (e.g. terminated)' do
      let!(:ended_tenure) do
        create(:employment_tenure, :inactive, company_teammate: teammate, company: organization)
      end
      let!(:check_in_1) do
        create(:position_check_in, company_teammate: teammate, employment_tenure: ended_tenure)
      end
      let!(:check_in_2) do
        create(:position_check_in, :closed, company_teammate: teammate, employment_tenure: ended_tenure)
      end

      before do
        active_tenure.update!(ended_at: 1.day.ago)
        check_in_2.update_columns(official_check_in_completed_at: nil, official_rating: nil, shared_notes: nil, finalized_by_teammate_id: nil)
      end

      it 'merges to one open check-in without changing employment_tenure_id' do
        expect(teammate.active_employment_tenure).to be_nil
        expect(PositionCheckIn.where(company_teammate: teammate).open.count).to eq(2)
        result = described_class.call(teammate: teammate)
        expect(result[:merged]).to be true
        expect(PositionCheckIn.where(company_teammate: teammate).open.count).to eq(1)
        remaining = PositionCheckIn.where(company_teammate: teammate).open.first
        expect(remaining.employment_tenure_id).to eq(ended_tenure.id)
      end
    end
  end
end
