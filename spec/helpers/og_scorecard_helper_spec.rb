# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgScorecardHelper, type: :helper do
  let(:organization) { build_stubbed(:company) }

  before do
    assign(:organization, organization)
    allow(helper).to receive(:params).and_return(ActionController::Parameters.new(param_hash).permit!)
  end

  let(:param_hash) { {} }

  describe '#og_scorecard_display_mode' do
    it 'defaults to values' do
      expect(helper.og_scorecard_display_mode).to eq('values')
      expect(helper.og_scorecard_percent_mode?).to be(false)
    end

    context 'when display=percent' do
      let(:param_hash) { { display: 'percent' } }

      it 'returns percent' do
        expect(helper.og_scorecard_display_mode).to eq('percent')
        expect(helper.og_scorecard_percent_mode?).to be(true)
      end
    end
  end

  describe '#og_scorecard_percent_display_eligible?' do
    it 'is true for unique-teammate rows' do
      row = { key: 'unique_ogo_publishers_this_week', supports_percent: true }
      expect(helper.og_scorecard_percent_display_eligible?(row)).to be(true)
    end

    it 'excludes active_teammates' do
      row = { key: 'active_teammates', supports_percent: true }
      expect(helper.og_scorecard_percent_display_eligible?(row)).to be(false)
    end

    it 'is false when supports_percent is false' do
      row = { key: 'milestones_earned_this_week', supports_percent: false }
      expect(helper.og_scorecard_percent_display_eligible?(row)).to be(false)
    end
  end

  describe '#og_scorecard_percent_of_teammates' do
    it 'rounds to 0 decimals' do
      expect(helper.og_scorecard_percent_of_teammates(1, 3)).to eq('33%')
      expect(helper.og_scorecard_percent_of_teammates(1, 2)).to eq('50%')
    end

    it 'returns em dash when no active teammates' do
      expect(helper.og_scorecard_percent_of_teammates(5, 0)).to eq('—')
    end
  end

  describe '#og_scorecard_cell_detail_tooltip' do
    it 'includes count, headcount, and percentage' do
      expect(helper.og_scorecard_cell_detail_tooltip(12, 48)).to eq('12 of 48 teammates (25%)')
    end
  end

  describe '#og_scorecard_weekly_cell_display' do
    let(:row) { { key: 'unique_ogo_publishers_this_week', supports_percent: true } }

    it 'shows raw counts by default' do
      expect(helper.og_scorecard_weekly_cell_display(12, 48, row: row)).to eq(12)
    end

    context 'in percent mode' do
      let(:param_hash) { { display: 'percent' } }

      it 'shows percentage for eligible rows' do
        expect(helper.og_scorecard_weekly_cell_display(12, 48, row: row)).to eq('25%')
      end

      it 'keeps active teammates as counts' do
        active_row = { key: 'active_teammates', supports_percent: true }
        expect(helper.og_scorecard_weekly_cell_display(48, 48, row: active_row)).to eq(48)
      end
    end
  end

  describe '#og_scorecard_six_week_avg_display' do
    let(:row) do
      {
        key: 'unique_ogo_publishers_this_week',
        supports_percent: true,
        six_week_avg: 6.0,
        weekly_values: [10, 10, 10, 10, 10, 10],
        weekly_active_counts: [40, 40, 40, 40, 40, 40]
      }
    end

    it 'shows count average by default' do
      expect(helper.og_scorecard_six_week_avg_display(row)).to eq(6.0)
    end

    context 'in percent mode' do
      let(:param_hash) { { display: 'percent' } }

      it 'averages weekly percentages with 0 decimals' do
        expect(helper.og_scorecard_six_week_avg_display(row)).to eq('25%')
      end
    end
  end

  describe '#og_scorecard_path_with_filters' do
    let(:param_hash) { { display: 'percent', timeframe: 'year' } }

    before do
      allow(helper).to receive(:organization_insights_og_scorecard_path) do |_org, **kwargs|
        kwargs
      end
    end

    it 'preserves percent display by default' do
      expect(helper.og_scorecard_path_with_filters[:display]).to eq('percent')
    end

    it 'can switch back to real values' do
      expect(helper.og_scorecard_path_with_filters(display: 'values')).not_to have_key(:display)
    end
  end
end
