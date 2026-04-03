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
      names = data[:series].map { |s| s[:name] }
      expect(names).to include('Started that week (on track)')
      expect(names).to include('Completed that week')
      expect(names).to include('Ongoing, no check-in — overdue')
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

  describe '.lifecycle_series' do
    it 'returns five lifecycle segments' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.lifecycle_series(range, scope)
      expect(data[:series].map { |s| s[:name] }).to include(
        'Created (started in same week)',
        'Completed that week'
      )
      expect(data[:series].size).to eq(5)
    end
  end

  describe '.employees_goal_weekly_status_series' do
    it 'returns three employee segments' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.employees_goal_weekly_status_series(range, scope)
      expect(data[:series].size).to eq(3)
      expect(data[:series].map { |s| s[:name] }).to include('Has active started goal(s)')
    end
  end

  describe '.association_structure_series' do
    it 'returns nine association × status segments' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.association_structure_series(range, scope)
      expect(data[:series].size).to eq(9)
      expect(data[:series].first[:name]).to include('Top-level, no prompt')
    end
  end
end
