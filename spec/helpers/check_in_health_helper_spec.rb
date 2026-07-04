# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthHelper, type: :helper do
  describe '#check_in_health_clarity_popover_caption' do
    it 'describes Gruuv Health workflow columns' do
      text = helper.check_in_health_clarity_popover_caption
      expect(text).to include(EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s)
      expect(text).to include('Healthy Gruuv Health status')
    end
  end
end
