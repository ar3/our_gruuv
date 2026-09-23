# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmploymentHistoryCorrectionHelper, type: :helper do
  describe '#employment_history_duration_label' do
    it 'formats multi-year spans' do
      expect(helper.employment_history_duration_label(400.days.to_i)).to eq('1.1 years')
    end
  end
end
