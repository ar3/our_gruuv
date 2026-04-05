# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyGoalsDashboardService do
  include ActiveSupport::Testing::TimeHelpers

  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: company) }

  def owned_goal_base
    { owner: teammate, creator: teammate, company: company, goal_type: "quantitative_key_result" }
  end

  describe "#counts" do
    it "returns zeros when teammate is nil" do
      expect(described_class.new(teammate: nil).counts).to eq(
        with_recent_check_in: 0,
        without_recent_check_in: 0,
        draft: 0,
        completed: 0
      )
    end

    it "counts draft / unstarted goals owned by teammate" do
      create(:goal, **owned_goal_base, started_at: nil, completed_at: nil, deleted_at: nil)
      create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)

      c = described_class.new(teammate: teammate).counts
      expect(c[:draft]).to eq(1)
    end

    it "counts active goals with a check-in in the rolling 14-day window (Monday cutoff)" do
      travel_to Time.zone.local(2026, 4, 3, 12, 0, 0) do
        cutoff = (Date.current - 14.days).beginning_of_week(:monday)

        g_recent = create(
          :goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil
        )
        create(:goal_check_in, goal: g_recent, check_in_week_start: Date.current.beginning_of_week(:monday))

        g_stale = create(
          :goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil
        )
        create(:goal_check_in, goal: g_stale, check_in_week_start: cutoff - 7.days)

        c = described_class.new(teammate: teammate).counts
        expect(c[:with_recent_check_in]).to eq(1)
        expect(c[:without_recent_check_in]).to eq(1)
      end
    end

    it "treats active goals with no check-ins as without recent check-in" do
      create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)

      c = described_class.new(teammate: teammate).counts
      expect(c[:with_recent_check_in]).to eq(0)
      expect(c[:without_recent_check_in]).to eq(1)
    end

    it "counts completed goals owned by teammate" do
      create(
        :goal,
        **owned_goal_base,
        started_at: 1.week.ago,
        completed_at: 1.day.ago,
        deleted_at: nil
      )

      expect(described_class.new(teammate: teammate).counts[:completed]).to eq(1)
    end

    it "does not count goals owned by someone else" do
      other = create(:company_teammate, organization: company)
      create(
        :goal,
        owner: other,
        creator: other,
        company: company,
        goal_type: "quantitative_key_result",
        started_at: 1.day.ago,
        completed_at: nil,
        deleted_at: nil
      )

      expect(described_class.new(teammate: teammate).counts[:without_recent_check_in]).to eq(0)
    end
  end
end
