# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::ReconcileOpenPositionCheckInsJob, type: :job do
  describe '#perform' do
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:company_teammate, person: create(:person), organization: organization) }
    let!(:employment_tenure) { create(:employment_tenure, company_teammate: teammate, company: organization) }

    it 'calls ReconcileOpenPositionCheckInsService for each teammate with open position check-ins' do
      create(:position_check_in, company_teammate: teammate, employment_tenure: employment_tenure)
      other_teammate = create(:company_teammate, person: create(:person), organization: organization)
      other_tenure = create(:employment_tenure, company_teammate: other_teammate, company: organization)
      create(:position_check_in, company_teammate: other_teammate, employment_tenure: other_tenure)

      expect(CheckIns::ReconcileOpenPositionCheckInsService).to receive(:call).with(teammate: teammate).and_return({ merged: false, repointed: false, details: {} })
      expect(CheckIns::ReconcileOpenPositionCheckInsService).to receive(:call).with(teammate: other_teammate).and_return({ merged: false, repointed: false, details: {} })

      described_class.perform_now
    end

    it 'skips when teammate record is not found (e.g. orphaned check-in)' do
      allow(PositionCheckIn).to receive_message_chain(:open, :distinct, :pluck).with(:teammate_id).and_return([999_999])

      expect(CompanyTeammate).to receive(:find_by).with(id: 999_999).and_return(nil)
      expect(CheckIns::ReconcileOpenPositionCheckInsService).not_to receive(:call)
      expect { described_class.perform_now }.not_to raise_error
    end

    it 'does nothing when there are no open position check-ins' do
      expect(CheckIns::ReconcileOpenPositionCheckInsService).not_to receive(:call)
      described_class.perform_now
    end
  end
end
