# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyOperationalCleanupJob, type: :job do
  describe '#perform' do
    it 'calls ObserveBirthdaysJob and ObserveWorkAnniversariesJob via perform_and_get_result' do
      expect(ObserveBirthdaysJob).to receive(:perform_and_get_result).with(no_args).and_return({ created: 0 })
      expect(ObserveWorkAnniversariesJob).to receive(:perform_and_get_result).with(no_args).and_return({ created: 0 })
      described_class.perform_and_get_result
    end

    it 'does not use perform_now or perform_later for child jobs' do
      allow(ObserveBirthdaysJob).to receive(:perform_and_get_result).and_return({ created: 0 })
      allow(ObserveWorkAnniversariesJob).to receive(:perform_and_get_result).and_return({ created: 0 })
      expect(ObserveBirthdaysJob).not_to receive(:perform_now)
      expect(ObserveBirthdaysJob).not_to receive(:perform_later)
      expect(ObserveWorkAnniversariesJob).not_to receive(:perform_now)
      expect(ObserveWorkAnniversariesJob).not_to receive(:perform_later)
      described_class.perform_and_get_result
    end
  end
end
