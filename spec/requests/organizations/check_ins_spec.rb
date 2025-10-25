require 'rails_helper'

RSpec.describe "Organizations::CheckIns", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person
    )
  end
  
  before do
    # Setup authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
    
    employment_tenure # ensure it exists
  end
  
  describe "PATCH /organizations/:org_id/people/:person_id/check_ins" do
    context "position check-in" do
      context "when marking as draft" do
        it "saves data but does not mark as completed" do
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Draft notes",
                      status: "draft"
                    }
                  }
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          
          # Assert database state
          expect(check_in.manager_rating).to eq(2)
          expect(check_in.manager_private_notes).to eq("Draft notes")
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
          
          # Assert response
          expect(response).to redirect_to(organization_person_check_ins_path(organization, employee_person))
          follow_redirect!
          expect(response.body).to include("Check-ins saved successfully")
        end
      end
      
      context "when marking as complete" do
        it "saves data and marks as completed with timestamp and person" do
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Complete notes",
                      status: "complete"
                    }
                  }
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          
          # Assert database state
          expect(check_in.manager_rating).to eq(2)
          expect(check_in.manager_private_notes).to eq("Complete notes")
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_within(1.second).of(Time.current)
          expect(check_in.manager_completed_by).to eq(manager_person)
          
          # Assert response
          expect(response).to redirect_to(organization_person_check_ins_path(organization, employee_person))
        end
      end
      
      context "when toggling from draft to complete" do
        it "properly updates completion status" do
          # First: Save as draft
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Notes",
                      status: "draft"
                    }
                  }
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          expect(check_in.manager_completed_at).to be_nil
          
          # Then: Mark as complete
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Notes",
                      status: "complete"
                    }
                  }
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by).to eq(manager_person)
        end
      end
      
      context "when toggling from complete back to draft" do
        it "unmarks completion" do
          # First: Mark as complete
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Notes",
                      status: "complete"
                    }
                  }
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          expect(check_in.manager_completed_at).to be_present
          
          # Then: Change back to draft
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Notes",
                      status: "draft"
                    }
                  }
                }
          
          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
        end
      end
      
      context "employee perspective" do
        before do
          allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
        end
        
        it "marks employee side as complete" do
          patch organization_person_check_ins_path(organization, employee_person),
                params: {
                  check_ins: {
                    position_check_in: {
                      employee_rating: 1,
                      employee_private_notes: "My notes",
                      status: "complete"
                    }
                  }
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          expect(check_in.employee_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_nil # Manager hasn't completed
        end
      end
    end
    
    context "authorization" do
      it "requires authentication" do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
        
        patch organization_person_check_ins_path(organization, employee_person),
              params: { check_ins: { position_check_in: { status: "draft" } } }
        
        expect(response).to have_http_status(:redirect)
      end
      
      it "requires proper permissions" do
        other_person = create(:person)
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(other_person)
        allow(other_person).to receive(:can_manage_employment?).with(organization).and_return(false)
        
        patch organization_person_check_ins_path(organization, employee_person),
              params: { check_ins: { position_check_in: { status: "draft" } } }
        
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
