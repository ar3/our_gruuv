# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObserveWorkAnniversariesJob, type: :job do
  describe '.perform_and_get_result' do
    it 'calls ObserveWorkAnniversariesService for each organization when no arg' do
      create(:organization, :company)
      expect(ObservableMoments::ObserveWorkAnniversariesService).to receive(:call).at_least(:once).and_return({ created: 0 })
      described_class.perform_and_get_result
    end

    it 'calls ObserveWorkAnniversariesService for the given organization when organization_id given' do
      org = create(:organization, :company)
      expect(ObservableMoments::ObserveWorkAnniversariesService).to receive(:call).with(organization: org).and_return({ created: 0 })
      described_class.perform_and_get_result(org.id)
    end
  end
end
