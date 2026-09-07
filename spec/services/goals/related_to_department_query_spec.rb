# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::RelatedToDepartmentQuery do
  let(:organization) { create(:organization, :company) }
  let(:root_dept) { create(:department, company: organization, name: "Engineering") }
  let(:child_dept) { create(:department, company: organization, name: "Platform", parent_department: root_dept) }
  let(:other_dept) { create(:department, company: organization, name: "Sales") }
  let(:creator) { create(:company_teammate, organization: organization) }

  def create_goal!(owner:, title:, privacy_level: "everyone_in_company")
    create(
      :goal,
      creator: creator,
      owner: owner,
      company: organization,
      title: title,
      started_at: 1.week.ago,
      privacy_level: privacy_level
    )
  end

  it "includes department-owned, descendant-owned, team-owned, and company-visible personal goals in the tree" do
    dept_goal = create_goal!(owner: root_dept, title: "Dept owned")
    child_dept_goal = create_goal!(owner: child_dept, title: "Child dept owned")
    team = create(:team, company: organization, department: child_dept, name: "Platform Team")
    team_goal = create_goal!(owner: team, title: "Team owned")

    person = create(:person, first_name: "Jordan")
    teammate = create(:company_teammate, person: person, organization: organization)
    tenure = create(:employment_tenure, company_teammate: teammate, company: organization)
    tenure.position.title.update!(department: child_dept)
    public_personal = create_goal!(
      owner: teammate,
      title: "Public personal",
      privacy_level: "everyone_in_company"
    )
    private_personal = create_goal!(
      owner: teammate,
      title: "Private personal",
      privacy_level: "only_creator_owner_and_managers"
    )

    other_team = create(:team, company: organization, department: other_dept, name: "Sales Team")
    other_team_goal = create_goal!(owner: other_team, title: "Sales team")
    other_dept_goal = create_goal!(owner: other_dept, title: "Sales dept")

    relation = Goal.where(company: organization)
    result = described_class.call(relation: relation, department: root_dept)

    expect(result).to include(dept_goal, child_dept_goal, team_goal, public_personal)
    expect(result).not_to include(private_personal, other_team_goal, other_dept_goal)
  end

  it "returns none when department is blank" do
    expect(described_class.call(relation: Goal.all, department: nil)).to eq(Goal.none)
  end
end
