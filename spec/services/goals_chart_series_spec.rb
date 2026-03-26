require 'rails_helper'

RSpec.describe GoalsChartSeries do
  let(:company) { create(:organization) }

  describe '.stacked_series' do
    it 'returns categories and series arrays' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company)
      data = described_class.stacked_series(range, scope)
      expect(data[:categories]).to be_a(Array)
      expect(data[:series]).to be_a(Array)
      expect(data[:series].map { |s| s[:name] }).to include('Started that week')
    end
  end

  describe '.owner_check_in_series' do
    it 'returns two series for goal-level counts' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.owner_check_in_series(range, scope)
      expect(data[:series].size).to eq(2)
      expect(data[:series].first[:name]).to include('no check-in')
    end
  end
end
