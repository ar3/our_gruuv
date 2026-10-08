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
      expect(names).to include('Completed and hit that week')
      expect(names).to include('Completed and missed that week')
      expect(names).to include('Ongoing, no confidence check — overdue')
    end
  end

  describe '.owner_check_in_series' do
    it 'returns two series for goal-level counts' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.owner_check_in_series(range, scope)
      expect(data[:series].size).to eq(2)
      expect(data[:series].first[:name]).to include('no confidence check')
    end
  end

  describe '.lifecycle_series' do
    it 'returns six lifecycle segments with hit/miss completions' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.lifecycle_series(range, scope)
      expect(data[:series].map { |s| s[:name] }).to include(
        'Created (started in same week)',
        'Completed and hit that week',
        'Completed and missed that week'
      )
      expect(data[:series].size).to eq(6)
    end
  end

  describe '.employees_goal_weekly_status_series' do
    it 'returns four employee segments with hit/miss completions' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.employees_goal_weekly_status_series(range, scope)
      expect(data[:series].size).to eq(4)
      expect(data[:series].map { |s| s[:name] }).to include(
        'Completed and hit a goal this week',
        'Completed and missed a goal this week',
        'Has active started goal(s)'
      )
    end
  end

  describe '.association_structure_series' do
    it 'returns twelve association × status segments with hit/miss completions' do
      range = 2.weeks.ago..Time.current
      scope = GoalsChartSeries.goals_base_scope(company).none
      data = described_class.association_structure_series(range, scope)
      expect(data[:series].size).to eq(12)
      expect(data[:series].first[:name]).to include('Top-level, no prompt')
      expect(data[:series].map { |s| s[:name] }).to include(
        'Top-level, no prompt — completed and hit (this week)',
        'Top-level, no prompt — completed and missed (this week)'
      )
    end
  end
end
