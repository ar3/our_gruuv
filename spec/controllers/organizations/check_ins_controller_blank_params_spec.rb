# frozen_string_literal: true

require "rails_helper"

# Controller-level mirror of request blank persistence (desired behavior fails until update_* coerces blanks).
RSpec.describe Organizations::CompanyTeammates::CheckInsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, full_name: "Manager Person") }
  let(:employee) { create(:person, full_name: "Employee Person") }
  let(:title) { create(:title, company: organization, external_title: "Software Engineer") }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.2") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Ctrl Blank Assignment") }
  let(:aspiration) { create(:aspiration, company: organization, name: "Ctrl Blank Aspiration") }

  let(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:employment_tenure) do
    mt = CompanyTeammate.find(manager_teammate.id)
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: mt, position: position)
  end
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment) }

  before do
    manager_teammate
    employee_teammate
    employment_tenure
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
    sign_in_as_teammate(manager, organization)
  end

  describe "PATCH #update — blank manager assignment fields (manager session)" do
    let!(:assignment_check_in) do
      ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      ci.update!(
        employee_rating: "exceeding",
        employee_private_notes: "Preserve employee",
        manager_rating: "meeting",
        manager_private_notes: "Was set before blank PATCH"
      )
      ci
    end

    it "persists nil for blank manager_rating and manager_private_notes; leaves employee columns" do
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        check_ins: {
          assignment_check_ins: {
            assignment_check_in.id.to_s => {
              assignment_id: assignment.id,
              manager_rating: "",
              manager_private_notes: "",
              status: "draft"
            }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      assignment_check_in.reload
      expect(assignment_check_in.manager_rating).to be_nil
      expect(assignment_check_in.manager_private_notes).to be_nil
      expect(assignment_check_in.employee_rating).to eq("exceeding")
      expect(assignment_check_in.employee_private_notes).to eq("Preserve employee")
    end
  end

  describe "PATCH #update as employee — blank aspiration employee fields" do
    let!(:aspiration_check_in) do
      ci = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
      ci.update!(
        employee_rating: "meeting",
        employee_private_notes: "Clear me",
        manager_rating: "exceeding",
        manager_private_notes: "Keep manager copy"
      )
      ci
    end

    before { sign_in_as_teammate(employee, organization) }

    it "persists nil for blank employee_rating and employee_private_notes; leaves manager columns" do
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        check_ins: {
          aspiration_check_ins: {
            aspiration_check_in.id.to_s => {
              aspiration_id: aspiration.id,
              employee_rating: "",
              employee_private_notes: "",
              status: "draft"
            }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      aspiration_check_in.reload
      expect(aspiration_check_in.employee_rating).to be_nil
      expect(aspiration_check_in.employee_private_notes).to be_nil
      expect(aspiration_check_in.manager_rating).to eq("exceeding")
      expect(aspiration_check_in.manager_private_notes).to eq("Keep manager copy")
    end
  end

  describe "PATCH #update as employee — blank position employee fields" do
    let!(:position_check_in) do
      ci = PositionCheckIn.find_or_create_open_for(employee_teammate)
      ci.update!(
        employee_rating: 1,
        employee_private_notes: "Clear employee position",
        manager_rating: 2,
        manager_private_notes: "Keep manager position"
      )
      ci
    end

    before { sign_in_as_teammate(employee, organization) }

    it "persists nil for blank employee_rating and employee_private_notes; leaves manager columns" do
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        check_ins: {
          position_check_in: {
            employee_rating: "",
            employee_private_notes: "",
            status: "draft"
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      position_check_in.reload
      expect(position_check_in.employee_rating).to be_nil
      expect(position_check_in.employee_private_notes).to be_nil
      expect(position_check_in.manager_rating).to eq(2)
      expect(position_check_in.manager_private_notes).to eq("Keep manager position")
    end
  end

  describe "POST #save_and_redirect as employee — blank assignment employee fields" do
    let!(:assignment_check_in) do
      ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      ci.update!(
        employee_rating: "exceeding",
        employee_private_notes: "Via save_and_redirect",
        manager_rating: "meeting",
        manager_private_notes: "Manager row intact"
      )
      ci
    end

    before { sign_in_as_teammate(employee, organization) }

    it "persists nil for blank employee fields via save_and_redirect" do
      redirect_url = organization_company_teammate_check_ins_path(organization, employee_teammate)

      post :save_and_redirect, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        redirect_url: redirect_url,
        check_ins: {
          assignment_check_ins: {
            assignment_check_in.id.to_s => {
              assignment_id: assignment.id,
              employee_rating: "",
              employee_private_notes: "",
              actual_energy_percentage: "",
              employee_personal_alignment: "",
              status: "draft"
            }
          }
        }
      }

      expect(response).to redirect_to(redirect_url)
      assignment_check_in.reload
      expect(assignment_check_in.employee_rating).to be_nil
      expect(assignment_check_in.employee_private_notes).to be_nil
      expect(assignment_check_in.actual_energy_percentage).to be_nil
      expect(assignment_check_in.employee_personal_alignment).to be_nil
      expect(assignment_check_in.manager_rating).to eq("meeting")
      expect(assignment_check_in.manager_private_notes).to eq("Manager row intact")
    end
  end
end
