# frozen_string_literal: true

require "rails_helper"

# Documents behavior: explicit blanks in PATCH/POST params persist as NULL on the viewer's
# columns without touching the other party's data (CoerceBlankCheckInAttrs + update path).
RSpec.describe "Organizations::CheckIns blank value persistence", type: :request do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: "Engineering") }
  let(:title) { create(:title, company: organization, external_title: "Software Engineer", position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago,
      ended_at: nil)
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    employment_tenure
  end

  describe "PATCH /organizations/:org_id/company_teammates/:id/check_ins" do
    context "assignment check-in" do
      let(:assignment) { create(:assignment, company: organization, title: "Persistence Assignment") }
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
      let!(:check_in) do
        ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        ci.update!(
          actual_energy_percentage: 40,
          employee_rating: "exceeding",
          employee_personal_alignment: "love",
          employee_private_notes: "Employee notes must survive manager blank-save",
          manager_rating: "meeting",
          manager_private_notes: "Manager notes to clear",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end

      it "as manager: blank manager_rating and manager_private_notes persist as nil; employee fields unchanged" do
        sign_in_as_teammate_for_request(manager_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              assignment_check_ins: {
                check_in.id.to_s => {
                  assignment_id: assignment.id,
                  manager_rating: "",
                  manager_private_notes: "",
                  status: "draft"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.manager_rating).to be_nil
        expect(check_in.manager_private_notes).to be_nil
        expect(check_in.employee_rating).to eq("exceeding")
        expect(check_in.employee_private_notes).to eq("Employee notes must survive manager blank-save")
        expect(check_in.actual_energy_percentage).to eq(40)
        expect(check_in.employee_personal_alignment).to eq("love")
      end

      it "as manager: blank manager_private_notes with status complete persist as nil and manager side completes" do
        sign_in_as_teammate_for_request(manager_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              assignment_check_ins: {
                check_in.id.to_s => {
                  assignment_id: assignment.id,
                  manager_rating: "meeting",
                  manager_private_notes: "",
                  status: "complete"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.manager_rating).to eq("meeting")
        expect(check_in.manager_private_notes).to be_nil
        expect(check_in.manager_completed_at).to be_present
        expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
        expect(check_in.employee_rating).to eq("exceeding")
        expect(check_in.employee_private_notes).to eq("Employee notes must survive manager blank-save")
      end

      it "as employee: blank employee fields persist as nil; manager fields unchanged" do
        check_in.update!(
          manager_rating: "exceeding",
          manager_private_notes: "Manager notes must survive employee blank-save",
          manager_completed_at: Time.current,
          manager_completed_by_teammate: manager_teammate
        )

        sign_in_as_teammate_for_request(employee_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              assignment_check_ins: {
                check_in.id.to_s => {
                  assignment_id: assignment.id,
                  employee_rating: "",
                  employee_private_notes: "",
                  actual_energy_percentage: "",
                  employee_personal_alignment: "",
                  status: "draft"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.employee_rating).to be_nil
        expect(check_in.employee_private_notes).to be_nil
        expect(check_in.actual_energy_percentage).to be_nil
        expect(check_in.employee_personal_alignment).to be_nil
        expect(check_in.manager_rating).to eq("exceeding")
        expect(check_in.manager_private_notes).to eq("Manager notes must survive employee blank-save")
      end
    end

    context "aspiration check-in" do
      let(:aspiration) { create(:aspiration, company: organization, name: "Persistence Aspiration") }
      let!(:check_in) do
        ci = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
        ci.update!(
          employee_rating: "meeting",
          employee_private_notes: "Employee aspiration notes",
          manager_rating: "exceeding",
          manager_private_notes: "Manager aspiration notes to clear",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end

      it "as manager: blank manager fields persist as nil; employee aspiration fields unchanged" do
        sign_in_as_teammate_for_request(manager_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              aspiration_check_ins: {
                check_in.id.to_s => {
                  aspiration_id: aspiration.id,
                  manager_rating: "",
                  manager_private_notes: "",
                  status: "draft"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.manager_rating).to be_nil
        expect(check_in.manager_private_notes).to be_nil
        expect(check_in.employee_rating).to eq("meeting")
        expect(check_in.employee_private_notes).to eq("Employee aspiration notes")
      end

      it "as employee: blank employee fields persist as nil; manager aspiration fields unchanged" do
        check_in.update!(
          manager_rating: "exceeding",
          manager_private_notes: "Manager aspiration survives employee blank-save",
          manager_completed_at: Time.current,
          manager_completed_by_teammate: manager_teammate
        )

        sign_in_as_teammate_for_request(employee_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              aspiration_check_ins: {
                check_in.id.to_s => {
                  aspiration_id: aspiration.id,
                  employee_rating: "",
                  employee_private_notes: "",
                  status: "draft"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.employee_rating).to be_nil
        expect(check_in.employee_private_notes).to be_nil
        expect(check_in.manager_rating).to eq("exceeding")
        expect(check_in.manager_private_notes).to eq("Manager aspiration survives employee blank-save")
      end
    end

    context "position check-in" do
      let!(:check_in) do
        ci = PositionCheckIn.find_or_create_open_for(employee_teammate)
        ci.update!(
          employee_rating: 1,
          employee_private_notes: "Employee position notes",
          manager_rating: 2,
          manager_private_notes: "Manager position notes to clear",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end

      it "as manager: blank manager_rating and manager_private_notes persist as nil; employee position fields unchanged" do
        sign_in_as_teammate_for_request(manager_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              position_check_in: {
                manager_rating: "",
                manager_private_notes: "",
                status: "draft"
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.manager_rating).to be_nil
        expect(check_in.manager_private_notes).to be_nil
        expect(check_in.employee_rating).to eq(1)
        expect(check_in.employee_private_notes).to eq("Employee position notes")
      end

      it "as employee: blank employee_rating and employee_private_notes persist as nil; manager position fields unchanged" do
        check_in.update!(
          manager_rating: 2,
          manager_private_notes: "Manager position survives employee blank-save",
          manager_completed_at: Time.current,
          manager_completed_by_teammate: manager_teammate
        )

        sign_in_as_teammate_for_request(employee_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              position_check_in: {
                employee_rating: "",
                employee_private_notes: "",
                status: "draft"
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.employee_rating).to be_nil
        expect(check_in.employee_private_notes).to be_nil
        expect(check_in.manager_rating).to eq(2)
        expect(check_in.manager_private_notes).to eq("Manager position survives employee blank-save")
      end
    end

    context "bulk PATCH: two assignment rows" do
      let(:assignment_a) { create(:assignment, company: organization, title: "Bulk Row A") }
      let(:assignment_b) { create(:assignment, company: organization, title: "Bulk Row B") }
      let!(:tenure_a) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_a, started_at: 6.months.ago) }
      let!(:tenure_b) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_b, started_at: 6.months.ago) }
      let!(:check_in_a) do
        ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment_a)
        ci.update!(
          employee_rating: "meeting",
          employee_private_notes: "A employee untouched",
          manager_rating: "exceeding",
          manager_private_notes: "A manager cleared by PATCH",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end
      let!(:check_in_b) do
        ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment_b)
        ci.update!(
          employee_rating: "working_to_meet",
          employee_private_notes: "B employee intact",
          manager_rating: "meeting",
          manager_private_notes: "B manager must stay",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end

      it "as manager: blank only row A manager fields; row B manager fields unchanged; employee columns on both rows unchanged" do
        sign_in_as_teammate_for_request(manager_person, organization)

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              assignment_check_ins: {
                check_in_a.id.to_s => {
                  assignment_id: assignment_a.id,
                  manager_rating: "",
                  manager_private_notes: "",
                  status: "draft"
                },
                check_in_b.id.to_s => {
                  assignment_id: assignment_b.id,
                  manager_rating: "meeting",
                  manager_private_notes: "B manager must stay",
                  status: "draft"
                }
              }
            },
            save_and_continue_editing: "Save All & Continue Editing"
          }

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in_a.reload
        check_in_b.reload
        expect(check_in_a.manager_rating).to be_nil
        expect(check_in_a.manager_private_notes).to be_nil
        expect(check_in_a.employee_rating).to eq("meeting")
        expect(check_in_a.employee_private_notes).to eq("A employee untouched")

        expect(check_in_b.manager_rating).to eq("meeting")
        expect(check_in_b.manager_private_notes).to eq("B manager must stay")
        expect(check_in_b.employee_rating).to eq("working_to_meet")
        expect(check_in_b.employee_private_notes).to eq("B employee intact")
      end
    end

    context "POST save_and_redirect (same update path as PATCH #update)" do
      let(:assignment) { create(:assignment, company: organization, title: "SaveRedirect Assignment") }
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
      let!(:check_in) do
        ci = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        ci.update!(
          employee_rating: "exceeding",
          employee_private_notes: "Will clear via save_and_redirect",
          manager_rating: "meeting",
          manager_private_notes: "Manager survives save_and_redirect",
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate_id: nil
        )
        ci
      end

      it "as employee: blank employee assignment fields persist as nil via save_and_redirect" do
        sign_in_as_teammate_for_request(employee_person, organization)

        post save_and_redirect_organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            redirect_url: organization_company_teammate_check_ins_path(organization, employee_teammate),
            check_ins: {
              assignment_check_ins: {
                check_in.id.to_s => {
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

        expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        check_in.reload
        expect(check_in.employee_rating).to be_nil
        expect(check_in.employee_private_notes).to be_nil
        expect(check_in.actual_energy_percentage).to be_nil
        expect(check_in.employee_personal_alignment).to be_nil
        expect(check_in.manager_rating).to eq("meeting")
        expect(check_in.manager_private_notes).to eq("Manager survives save_and_redirect")
      end
    end
  end
end
