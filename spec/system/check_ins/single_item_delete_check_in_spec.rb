require "rails_helper"

RSpec.describe "Single-item delete check-in", type: :system do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person, full_name: "Manager Person") }
  let(:employee_person) { create(:person, full_name: "Employee Person") }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  before do
    employee_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager_person, position: position)

    manager_teammate = CompanyTeammate.find_by!(person: manager_person, organization: organization)
    manager_teammate.update!(first_employed_at: 1.year.ago, can_manage_employment: true)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
  end

  it "allows deleting assignment check-in when the other side has no values" do
    assignment = create(:assignment, company: organization, title: "Delete Allowed Assignment")
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
    check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
    check_in.update!(manager_rating: nil, manager_private_notes: nil, actual_energy_percentage: 0)

    sign_in_as(employee_person, organization)
    visit organization_teammate_assignment_path(organization, employee_teammate, assignment)

    click_link "[Delete this check-in]"

    expect(page).to have_current_path(
      organization_teammate_assignment_path(organization, employee_teammate, assignment),
      ignore_query: true
    )
    expect(page).to have_content("That open check-in was deleted.")
    expect(AssignmentCheckIn.where(id: check_in.id)).to be_empty
    expect(AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).open.first).to be_nil
  end

  it "shows disabled delete with tooltip guidance when other side has values" do
    aspiration = create(:aspiration, :with_department, company: organization, name: "Delete Blocked Aspiration")
    check_in = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
    check_in.update!(employee_private_notes: "Employee already entered values")

    sign_in_as(manager_person, organization)
    visit organization_teammate_aspiration_path(organization, employee_teammate, aspiration)

    expect(page).to have_content("[Delete this check-in]")
    expect(page).not_to have_link("[Delete this check-in]")
    expect(page).to have_css(
      "span[data-bs-title*='has to remove the values']"
    )
  end

  it "shows disabled delete for company aspirational values" do
    aspiration = create(:aspiration, company: organization, name: "Company Value No Delete")
    AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)

    sign_in_as(employee_person, organization)
    visit organization_teammate_aspiration_path(organization, employee_teammate, aspiration)

    expect(page).to have_content("[Delete this check-in]")
    expect(page).not_to have_link("[Delete this check-in]")
    expect(page).to have_css("span[data-bs-title*='company aspirational value']")
  end
end
