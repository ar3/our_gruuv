# frozen_string_literal: true

require "rails_helper"

RSpec.describe DepartmentGroupedSelectsHelper, type: :helper do
  let(:organization) { create(:organization) }

  describe "#assignments_grouped_options_for_select" do
    it "groups company-wide first, then departments by name, titles within group" do
      dept = create(:department, company: organization, name: "Engineering")
      company_wide = create(:assignment, company: organization, title: "Zulu Work", department: nil)
      in_dept = create(:assignment, company: organization, title: "Alpha Work", department: dept)
      other = create(:assignment, company: organization, title: "Beta Work", department: dept)

      html = helper.assignments_grouped_options_for_select([in_dept, company_wide, other])

      expect(html).to include("Company-wide")
      expect(html).to include("optgroup")
      expect(html.index("Company-wide")).to be < html.index("Alpha Work")
      expect(html.index("Alpha Work")).to be < html.index("Beta Work")
    end
  end

  describe "#abilities_grouped_options_for_select" do
    it "groups company-wide first, then departments by name, ability names within group" do
      dept = create(:department, company: organization, name: "Engineering")
      company_wide = create(:ability, company: organization, name: "Zulu Skill", department: nil)
      in_dept = create(:ability, company: organization, name: "Alpha Skill", department: dept)
      other = create(:ability, company: organization, name: "Beta Skill", department: dept)

      html = helper.abilities_grouped_options_for_select([in_dept, company_wide, other])

      expect(html).to include("Company-wide")
      expect(html).to include("optgroup")
      expect(html.index("Company-wide")).to be < html.index("Alpha Skill")
      expect(html.index("Alpha Skill")).to be < html.index("Beta Skill")
    end
  end
end
