require 'rails_helper'

RSpec.describe "Organizations::AssignmentCheckIns", type: :request do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
  let(:assignment_tenure) do
    create(:assignment_tenure,
      teammate: employee_teammate,
      assignment: assignment,
      anticipated_energy_percentage: 50,
      started_at: 1.month.ago
    )
  end
  
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }

  before do
    # Set up manager with employment management permission
    manager_teammate.update!(can_manage_employment: true)
    sign_in_as_teammate_for_request(manager_person, organization)
    
    assignment_tenure # ensure it exists
    # Create an open check-in
    AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
  end
  
  describe "PATCH /organizations/:org_id/company_teammates/:company_teammate_id/check_ins" do
    context "assignment check-in" do
      context "when marking as draft" do
        it "saves data but does not mark as completed" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Draft notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in.reload
          expect(check_in.manager_rating).to eq("meeting")
          expect(check_in.manager_private_notes).to eq("Draft notes")
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by_teammate).to be_nil
          
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end
      end
      
      context "when marking as complete" do
        it "saves data and marks as completed" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Complete notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in.reload
          expect(check_in.manager_rating).to eq("exceeding")
          expect(check_in.manager_private_notes).to eq("Complete notes")
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_within(1.second).of(Time.current)
          expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
          
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end
      end
      
      context "employee perspective" do
        before do
          sign_in_as_teammate_for_request(employee_person, organization)
        end
        
        it "marks employee side as complete" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        employee_rating: "meeting",
                        actual_energy_percentage: 60,
                        employee_personal_alignment: "love",
                        employee_private_notes: "My notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in.reload
          expect(check_in.employee_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_nil # Manager hasn't completed
        end
      end
      
      context "when toggling from draft to complete" do
        it "properly updates completion status" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          redirect_path = organization_company_teammate_check_ins_path(organization, employee_teammate)
          
          # First: Save as draft
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: redirect_path
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          
          # Then: Mark as complete
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: redirect_path
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
        end
      end
      
      context "when toggling from complete back to draft" do
        it "unmarks completion" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          redirect_path = organization_company_teammate_check_ins_path(organization, employee_teammate)
          
          # First: Mark as complete
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: redirect_path
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_present
          
          # Then: Change back to draft
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: redirect_path
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by_teammate).to be_nil
        end
      end

      context "when no assignment tenure exists" do
        before do
          # Destroy the tenure and create a check-in without a tenure
          AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
          AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
          # Create check-in directly (matching load_or_build_assignment_check_ins behavior)
          AssignmentCheckIn.create!(
            teammate: employee_teammate,
            assignment: assignment,
            check_in_started_on: Date.current,
            actual_energy_percentage: nil
          )
        end

        it "saves assignment check-in data successfully without tenure" do
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          expect(check_in).to be_present
          expect(AssignmentTenure.most_recent_for(employee_teammate, assignment)).to be_nil
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Saved without tenure",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in.reload
          expect(check_in.manager_rating).to eq("meeting")
          expect(check_in.manager_private_notes).to eq("Saved without tenure")
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
          
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end

        it "creates new check-in when updating if none exists and no tenure exists" do
          # Destroy the check-in we created in before block
          AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      'new_check_in' => {
                        assignment_id: assignment.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Created without tenure",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
          expect(check_in).to be_present
          expect(check_in.manager_rating).to eq("exceeding")
          expect(check_in.manager_private_notes).to eq("Created without tenure")
          expect(check_in.manager_completed_at).to be_nil
          
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end
      end
    end
    
    context "authorization" do
      it "requires authentication" do
        sign_out_teammate_for_request
        
        check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  assignment_check_ins: {
                    check_in.id.to_s => {
                      assignment_id: assignment.id,
                      status: "draft"
                    }
                  }
                }
              }
        
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
