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
          abilities_health?: true,
          milestones_health?: true,
          view_assignments?: true,
          assignments_health?: true,
          view_aspirations?: true,
          values_health?: true
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

    it "maps Assignments lenses" do
      expect(helper.object_lens_path(organization, :assignments, :list)).to eq(organization_assignments_path(organization))
      expect(helper.object_lens_path(organization, :assignments, :health)).to eq(organization_assignments_health_path(organization))
      expect(helper.object_lens_path(organization, :assignments, :insights)).to eq(organization_insights_assignments_path(organization))
    end

    it "maps Values lenses" do
      expect(helper.object_lens_path(organization, :values, :list)).to eq(organization_aspirations_path(organization))
      expect(helper.object_lens_path(organization, :values, :health)).to eq(organization_values_health_path(organization))
      expect(helper.object_lens_path(organization, :values, :insights)).to eq(organization_insights_values_path(organization))
    end

    it "maps Milestones and Abilities lenses" do
      expect(helper.object_lens_path(organization, :milestones, :list)).to eq(celebrate_milestones_organization_path(organization))
      expect(helper.object_lens_path(organization, :milestones, :health)).to eq(organization_milestones_health_path(organization))
      expect(helper.object_lens_path(organization, :milestones, :insights)).to eq(organization_insights_milestones_path(organization))
      expect(helper.object_lens_path(organization, :abilities, :list)).to eq(organization_abilities_path(organization))
      expect(helper.object_lens_path(organization, :abilities, :health)).to eq(organization_abilities_health_path(organization))
      expect(helper.object_lens_path(organization, :abilities, :insights)).to eq(organization_insights_abilities_path(organization))
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
            abilities_health?: false,
            milestones_health?: false,
            view_assignments?: false,
            assignments_health?: false,
            view_aspirations?: false,
            values_health?: false
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

    it "marks Abilities with a divider before (org catalog vs person-scoped objects)" do
      menu = helper.object_lens_menu_objects(organization, current_object: :goals, current_lens: :list)
      abilities = menu.find { |o| o[:key] == :abilities }
      expect(abilities[:divider_before]).to eq(true)
      expect(menu.find { |o| o[:key] == :milestones }[:divider_before]).to eq(false)
      expect(menu.find { |o| o[:key] == :assignments }[:divider_before]).to eq(false)
      keys = menu.map { |o| o[:key] }
      expect(keys.index(:milestones)).to be < keys.index(:abilities)
      expect(keys.index(:abilities)).to be < keys.index(:assignments)
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
