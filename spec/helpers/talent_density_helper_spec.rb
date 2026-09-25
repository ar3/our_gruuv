# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensityHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:current_period) { TalentDensityStance.current_period_month }

  describe "#talent_density_stance_history_chart_points" do
    it "returns empty when fewer than three rated reflections exist in the window" do
      history = [
        create(:talent_density_stance, company_teammate: teammate, company: company,
               period_month: current_period - 1.month, stance: :fine_either_way)
      ]
      current = TalentDensityStance.new(
        company_teammate: teammate,
        company: company,
        period_month: current_period,
        stance: :try_to_avoid_the_swap
      )

      expect(
        helper.talent_density_stance_history_chart_points(
          current: current,
          history: history,
          through_period: current_period
        )
      ).to eq([])
    end

    it "returns chronological points when three or more rated reflections exist" do
      history = [
        create(:talent_density_stance, company_teammate: teammate, company: company,
               period_month: current_period - 1.month, stance: :try_to_avoid_the_swap),
        create(:talent_density_stance, company_teammate: teammate, company: company,
               period_month: current_period - 2.months, stance: :fine_either_way),
        create(:talent_density_stance, company_teammate: teammate, company: company,
               period_month: current_period - 3.months, stance: :take_the_swap)
      ]
      current = TalentDensityStance.new(company_teammate: teammate, company: company, period_month: current_period)

      points = helper.talent_density_stance_history_chart_points(
        current: current,
        history: history,
        through_period: current_period
      )

      expect(points.size).to eq(3)
      expect(points.map { |p| p[:y] }).to eq([0, 1, 2])
      expect(points.last[:period]).to eq((current_period - 1.month).iso8601)
    end
  end
end
