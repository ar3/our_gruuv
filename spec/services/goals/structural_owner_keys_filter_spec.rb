# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::StructuralOwnerKeysFilter do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:department) { create(:department, company: organization, name: "Engineering") }
  let(:team) { create(:team, company: organization, name: "Platform", department: department) }

  let!(:company_goal) do
    create(:goal, creator: teammate, owner: organization, title: "Company Goal",
                  privacy_level: "everyone_in_company", started_at: 1.week.ago)
  end
  let!(:department_goal) do
    create(:goal, creator: teammate, owner: department, title: "Department Goal",
                  privacy_level: "everyone_in_company", started_at: 1.week.ago)
  end
  let!(:team_goal) do
    create(:goal, creator: teammate, owner: team, title: "Team Goal",
                  privacy_level: "everyone_in_company", started_at: 1.week.ago)
  end
  let!(:personal_goal) do
    create(:goal, creator: teammate, owner: teammate, title: "Personal Goal", started_at: 1.week.ago)
  end

  describe ".normalize_keys" do
    it "keeps only valid Company/Department/Team keys" do
      expect(described_class.normalize_keys([
        "Company_#{organization.id}",
        "Department_#{department.id}",
        "Team_#{team.id}",
        "CompanyTeammate_#{teammate.id}",
        "bogus",
        ""
      ])).to eq([
        "Company_#{organization.id}",
        "Department_#{department.id}",
        "Team_#{team.id}"
      ])
    end
  end

  describe ".customized?" do
    it "is true only when more than one structural key is present" do
      expect(described_class.customized?(["Company_#{organization.id}"])).to eq(false)
      expect(described_class.customized?([
        "Company_#{organization.id}",
        "Team_#{team.id}"
      ])).to eq(true)
    end
  end

  describe ".call" do
    it "ORs company, department-related, and team owned goals" do
      relation = Goal.where(id: [company_goal.id, department_goal.id, team_goal.id, personal_goal.id])
      result = described_class.call(
        relation: relation,
        keys: ["Company_#{organization.id}", "Department_#{department.id}", "Team_#{team.id}"]
      )

      expect(result).to include(company_goal, department_goal, team_goal)
      expect(result).not_to include(personal_goal)
    end
  end
end
