# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::EmployeeOwnedGoalsQuery do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, organization: organization) }
  let(:direct) { create(:company_teammate, organization: organization) }
  let(:indirect) { create(:company_teammate, organization: organization) }

  before do
    create(
      :employment_tenure,
      company: organization,
      company_teammate: direct,
      manager_teammate: manager,
      ended_at: nil
    )
    create(
      :employment_tenure,
      company: organization,
      company_teammate: indirect,
      manager_teammate: direct,
      ended_at: nil
    )
  end

  describe ".direct_report_ids" do
    it "returns only direct reports" do
      expect(described_class.direct_report_ids(manager: manager, organization: organization))
        .to contain_exactly(direct.id)
    end
  end

  describe ".hierarchy_report_ids" do
    it "returns the full tree excluding the manager" do
      expect(described_class.hierarchy_report_ids(manager: manager, organization: organization))
        .to contain_exactly(direct.id, indirect.id)
    end
  end

  describe ".call" do
    it "returns active personal goals for the given owners" do
      active = create(
        :goal,
        creator: direct,
        owner: direct,
        company: organization,
        title: "Active",
        started_at: 1.week.ago
      )
      create(
        :goal,
        creator: direct,
        owner: direct,
        company: organization,
        title: "Draft",
        started_at: nil
      )
      create(
        :goal,
        creator: indirect,
        owner: indirect,
        company: organization,
        title: "Indirect",
        started_at: 1.week.ago
      )

      result = described_class.call(
        relation: Goal.where(company: organization),
        owner_ids: [direct.id]
      )

      expect(result).to contain_exactly(active)
    end

    it "excludes goals the viewer cannot see when viewer_person is provided" do
      visible = create(
        :goal,
        creator: direct,
        owner: direct,
        company: organization,
        title: "Managers can see",
        started_at: 1.week.ago,
        privacy_level: "only_creator_owner_and_managers"
      )
      create(
        :goal,
        creator: direct,
        owner: direct,
        company: organization,
        title: "Creator only",
        started_at: 1.week.ago,
        privacy_level: "only_creator"
      )

      result = described_class.call(
        relation: Goal.where(company: organization),
        owner_ids: [direct.id],
        viewer_person: manager.person
      )

      expect(result).to contain_exactly(visible)
    end
  end
end
