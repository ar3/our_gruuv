# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::TeamsOverview do
  let(:company) { create(:organization, :company) }

  it "reports team count and average members" do
    create(:team, :with_members, company: company, member_count: 2)
    create(:team, :with_members, company: company, member_count: 4)

    result = described_class.new(
      organization: company,
      chart_range: 4.weeks.ago..Time.current
    ).call

    expect(result.teams_count).to eq(2)
    expect(result.average_members_per_team).to eq(3.0)
    expect(result.chart_data[:categories]).to be_present
    expect(result.chart_data[:series].map { |s| s[:name] }).to include(
      "Started",
      "Confidence checked",
      "Stale (Warning + Needs Attention)",
      "Completed"
    )
  end
end
