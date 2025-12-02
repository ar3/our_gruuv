require 'rails_helper'

RSpec.describe "Organizations::AspirationCheckIns", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:aspiration) { create(:aspiration, organization: organization, name: 'Test Aspiration') }
  
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }

  before do
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for employee
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    # Setup authentication
    sign_in_as_teammate_for_request(manager_person, organization)
    
    # Create an open check-in
    AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
  end
  
  describe "PATCH /organizations/:org_id/people/:person_id/check_ins" do
    context "aspiration check-in" do
      context "when marking as draft" do
        it "saves data but does not mark as completed" do
          check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
          
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Draft notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_rating).to eq("meeting")
          expect(check_in.manager_private_notes).to eq("Draft notes")
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
          
          expect(response).to redirect_to(organization_person_check_ins_path(organization, employee_person))
        end
      end
      
      context "when marking as complete" do
        it "saves data and marks as completed" do
          check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
          
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Complete notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_rating).to eq("exceeding")
          expect(check_in.manager_private_notes).to eq("Complete notes")
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_within(1.second).of(Time.current)
          expect(check_in.manager_completed_by).to eq(manager_person)
          
          expect(response).to redirect_to(organization_person_check_ins_path(organization, employee_person))
        end
      end
      
      context "employee perspective" do
        before do
          sign_in_as_teammate_for_request(employee_person, organization)
        end
        
        it "marks employee side as complete" do
          check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
          
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        employee_rating: "meeting",
                        employee_private_notes: "My notes",
                        status: "complete"
                      }
                    }
                  }
                }
          
          check_in.reload
          expect(check_in.employee_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_nil # Manager hasn't completed
        end
      end
      
      context "when toggling from draft to complete" do
        it "properly updates completion status" do
          check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
          
          # First: Save as draft
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          
          # Then: Mark as complete
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "meeting",
                        manager_private_notes: "Notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by).to eq(manager_person)
        end
      end
      
      context "when toggling from complete back to draft" do
        it "unmarks completion" do
          check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
          
          # First: Mark as complete
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Notes",
                        status: "complete"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_present
          
          # Then: Change back to draft
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: "exceeding",
                        manager_private_notes: "Notes",
                        status: "draft"
                      }
                    }
                  },
                  redirect_to: organization_person_check_ins_path(organization, employee_person)
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
        end
      end
    end
    
    context "authorization" do
      it "requires authentication" do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
        
        check_in = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration)
        
        patch organization_person_check_ins_path(organization, employee_person),
              params: {
                check_ins: {
                  aspiration_check_ins: {
                    check_in.id.to_s => {
                      aspiration_id: aspiration.id,
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

