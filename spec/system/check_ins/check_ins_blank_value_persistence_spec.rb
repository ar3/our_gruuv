# frozen_string_literal: true

require "rails_helper"

# System-level 1-by-1 flows: clearing viewer fields via real browser submit.
# Fails until blank params persist as NULL (same as request/controller specs).
RSpec.describe "Check-ins blank value persistence (system)", type: :system do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, full_name: "Manager Person") }
  let(:employee) { create(:person, full_name: "Employee Person") }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  context "manager on assignment 1-by-1" do
    let(:assignment) { create(:assignment, company: organization, title: "System Blank Assignment") }

    before do
      employee_teammate.update!(first_employed_at: 1.year.ago)
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position)

      manager_teammate = CompanyTeammate.find_by!(person: manager, organization: organization)
      manager_teammate.update!(
        first_employed_at: 1.year.ago,
        can_manage_employment: true
      )
      create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)

      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)

      ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      ci.update!(
        employee_rating: "exceeding",
        employee_private_notes: "Employee wrote this — must remain after manager clears",
        actual_energy_percentage: 25,
        employee_personal_alignment: "like",
        manager_rating: "meeting",
        manager_private_notes: "Manager will clear this via UI",
        employee_completed_at: nil,
        manager_completed_at: nil,
        manager_completed_by_teammate_id: nil
      )
      @check_in = ci

      sign_in_as(manager, organization)
    end

    it "manager clears manager rating and notes; employee side unchanged in DB" do
      visit organization_teammate_assignment_path(organization, employee_teammate, assignment)

      if page.has_link?("click here to check in early", wait: 0)
        click_link "click here to check in early"
      end

      find("select[name='check_ins[assignment_check_ins][#{@check_in.id}][manager_rating]']").select("Select rating")
      find("textarea[name='check_ins[assignment_check_ins][#{@check_in.id}][manager_private_notes]']").set("")

      click_button "Save as Draft and stay here"

      expect(page).to have_current_path(organization_teammate_assignment_path(organization, employee_teammate, assignment), ignore_query: true)

      @check_in.reload
      expect(@check_in.manager_rating).to be_nil
      expect(@check_in.manager_private_notes).to be_nil
      expect(@check_in.employee_rating).to eq("exceeding")
      expect(@check_in.employee_private_notes).to eq("Employee wrote this — must remain after manager clears")
      expect(@check_in.actual_energy_percentage).to eq(25)
      expect(@check_in.employee_personal_alignment).to eq("like")
    end
  end

  context "employee on aspiration 1-by-1" do
    let(:aspiration) { create(:aspiration, company: organization, name: "System Blank Aspiration") }

    before do
      employee_teammate.update!(first_employed_at: 1.year.ago)
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position)

      manager_teammate = CompanyTeammate.find_by!(person: manager, organization: organization)
      manager_teammate.update!(first_employed_at: 1.year.ago, can_manage_employment: true)
      create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)

      ci = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
      ci.update!(
        employee_rating: "meeting",
        employee_private_notes: "Employee will clear via UI",
        manager_rating: "exceeding",
        manager_private_notes: "Manager must survive employee clears",
        employee_completed_at: nil,
        manager_completed_at: nil,
        manager_completed_by_teammate_id: nil
      )
      @aspiration_check_in = ci

      sign_in_as(employee, organization)
    end

    it "employee clears rating and notes; manager aspiration fields unchanged in DB" do
      visit organization_teammate_aspiration_path(organization, employee_teammate, aspiration)

      if page.has_link?("click here to check in early", wait: 0)
        click_link "click here to check in early"
      end

      find("select[name='check_ins[aspiration_check_ins][#{@aspiration_check_in.id}][employee_rating]']").select("Select rating")
      find("textarea[name='check_ins[aspiration_check_ins][#{@aspiration_check_in.id}][employee_private_notes]']").set("")

      click_button "Save as Draft and stay here"

      expect(page).to have_current_path(organization_teammate_aspiration_path(organization, employee_teammate, aspiration), ignore_query: true)

      @aspiration_check_in.reload
      expect(@aspiration_check_in.employee_rating).to be_nil
      expect(@aspiration_check_in.employee_private_notes).to be_nil
      expect(@aspiration_check_in.manager_rating).to eq("exceeding")
      expect(@aspiration_check_in.manager_private_notes).to eq("Manager must survive employee clears")
    end
  end
end
