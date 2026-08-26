# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObjectLensHeaderHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    without_partial_double_verification do
      allow(helper).to receive(:current_company_teammate).and_return(teammate)
      allow(helper).to receive(:policy).with(organization).and_return(
        double(
          show?: true,
          protect_flow?: true,
          view_observations?: true,
          view_goals?: true,
          goals_health?: true,
          observations_health?: true,
          check_ins_health?: true,
          view_abilities?: true,
          milestones_health?: true
        )
      )
      allow(helper).to receive(:policy).with(teammate).and_return(double(view_check_ins?: true))
    end
  end

  describe "#object_lens_path" do
    it "maps Overall and Goals lenses" do
      expect(helper.object_lens_path(organization, :overall, :directory)).to eq(organization_sitemap_path(organization))
      expect(helper.object_lens_path(organization, :overall, :health)).to eq(organization_protect_flow_path(organization))
      expect(helper.object_lens_path(organization, :overall, :insights)).to eq(organization_insights_og_scorecard_path(organization))
      expect(helper.object_lens_path(organization, :goals, :list)).to eq(organization_goals_path(organization))
      expect(helper.object_lens_path(organization, :goals, :health)).to eq(organization_goals_health_path(organization))
      expect(helper.object_lens_path(organization, :goals, :insights)).to eq(organization_insights_goals_path(organization))
    end
  end

  describe "#object_lens_resolve_lens" do
    it "maps Directory to List when switching to Goals" do
      expect(helper.object_lens_resolve_lens(organization, :goals, :directory)).to eq(:list)
    end

    it "maps List to Directory when switching to Overall" do
      expect(helper.object_lens_resolve_lens(organization, :overall, :list)).to eq(:directory)
    end

    it "falls back when preferred lens is missing" do
      without_partial_double_verification do
        allow(helper).to receive(:policy).with(organization).and_return(
          double(
            show?: true,
            protect_flow?: false,
            view_observations?: true,
            view_goals?: true,
            goals_health?: false,
            observations_health?: false,
            check_ins_health?: false,
            view_abilities?: false,
            milestones_health?: false
          )
        )
      end

      expect(helper.object_lens_resolve_lens(organization, :goals, :health)).to eq(:insights)
    end
  end

  describe "#object_lens_menu_objects" do
    it "preserves Health when changing object" do
      goals = helper.object_lens_menu_objects(organization, current_object: :overall, current_lens: :health).find { |o| o[:key] == :goals }
      expect(goals[:path]).to eq(organization_goals_health_path(organization))
    end
  end

  describe "#object_lens_menu_lenses" do
    it "labels Overall browse as Directory" do
      labels = helper.object_lens_menu_lenses(organization, current_object: :overall, current_lens: :directory).map { |l| l[:label] }
      expect(labels).to eq(%w[Directory Health Insights])
    end

    it "labels Goals browse as List" do
      labels = helper.object_lens_menu_lenses(organization, current_object: :goals, current_lens: :list).map { |l| l[:label] }
      expect(labels).to eq(%w[List Health Insights])
    end
  end
end
