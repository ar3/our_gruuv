require 'rails_helper'

RSpec.describe "Organizations::CheckIns", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago,
      ended_at: nil
    )
  end

  before do
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for employee (via employment_tenure let block)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    # Setup authentication
    sign_in_as_teammate_for_request(manager_person, organization)
    
    employment_tenure # ensure it exists
  end
  
  describe "PATCH /organizations/:org_id/company_teammates/:company_teammate_id/check_ins" do
    context "position check-in" do
      context "when marking as draft" do
        it "saves data but does not mark as completed" do
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Draft notes",
                      status: "draft"
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          
          # Assert database state
          expect(check_in.manager_rating).to eq(2)
          expect(check_in.manager_private_notes).to eq("Draft notes")
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by_teammate).to be_nil
          
          # Assert response
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
          follow_redirect!
          expect(response.body).to include("Check-ins saved successfully")
        end
      end
      
      context "when marking as complete" do
        it "saves data and marks as completed with timestamp and person" do
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 2,
                      manager_private_notes: "Complete notes",
                      status: "complete"
                    }
                  },
                  redirect_to: organization_company_teammate_check_ins_path(organization, employee_teammate)
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          
          # Assert database state
          expect(check_in.manager_rating).to eq(2)
          expect(check_in.manager_private_notes).to eq("Complete notes")
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_at).to be_within(1.second).of(Time.current)
          expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
          
          # Assert response
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end
      end
      
      context "when toggling from draft to complete" do
        it "properly updates completion status" do
          # First: Save as draft
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
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
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
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
          expect(check_in.manager_completed_by_teammate_id).to eq(manager_teammate.id)
        end
      end
      
      context "when toggling from complete back to draft" do
        it "unmarks completion" do
          # First: Mark as complete
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
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
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
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
          expect(check_in.manager_completed_by_teammate).to be_nil
        end
      end
      
      context "employee perspective" do
        before do
          sign_in_as_teammate_for_request(employee_person, organization)
        end
        
        it "marks employee side as complete" do
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
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

      context "when clicking 'Save All & Continue Editing' button" do
        it "saves data and redirects back to check-ins page" do
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    position_check_in: {
                      manager_rating: 3,
                      manager_private_notes: "Continue editing notes",
                      status: "draft"
                    }
                  },
                  save_and_continue_editing: "Save All & Continue Editing"
                }
          
          check_in = PositionCheckIn.find_by(teammate: employee_teammate)
          
          # Assert database state
          expect(check_in.manager_rating).to eq(3)
          expect(check_in.manager_private_notes).to eq("Continue editing notes")
          
          # Assert response redirects to check-ins page
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
          follow_redirect!
          expect(response.body).to include("Check-ins saved successfully")
        end

        it "saves assignment check-ins and redirects back to check-ins page" do
          assignment = create(:assignment, company: organization, title: 'Test Assignment')
          assignment_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago)
          check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    assignment_check_ins: {
                      check_in.id.to_s => {
                        assignment_id: assignment.id,
                        manager_rating: 'meeting',
                        manager_private_notes: "Assignment notes",
                        status: "draft"
                      }
                    }
                  },
                  save_and_continue_editing: "Save All & Continue Editing"
                }
          
          check_in.reload
          
          # Assert database state
          expect(check_in.manager_rating).to eq('meeting')
          expect(check_in.manager_private_notes).to eq("Assignment notes")
          
          # Assert response redirects to check-ins page
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end

        it "saves aspiration check-ins and redirects back to check-ins page" do
          aspiration = create(:aspiration, company: organization, name: 'Test Aspiration')
          check_in = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
          
          patch organization_company_teammate_check_ins_path(organization, employee_teammate),
                params: {
                  check_ins: {
                    aspiration_check_ins: {
                      check_in.id.to_s => {
                        aspiration_id: aspiration.id,
                        manager_rating: 'exceeding',
                        manager_private_notes: "Aspiration notes",
                        status: "draft"
                      }
                    }
                  },
                  save_and_continue_editing: "Save All & Continue Editing"
                }
          
          check_in.reload
          
          # Assert database state
          expect(check_in.manager_rating).to eq('exceeding')
          expect(check_in.manager_private_notes).to eq("Aspiration notes")
          
          # Assert response redirects to check-ins page
          expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, employee_teammate))
        end
      end
    end
    
    context "authorization" do
      it "requires authentication" do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: { check_ins: { position_check_in: { status: "draft" } } }
        
        expect(response).to have_http_status(:redirect)
      end
      
      it "requires proper permissions" do
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, organization)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: { check_ins: { position_check_in: { status: "draft" } } }
        
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "GET /organizations/:org_id/company_teammates/:company_teammate_id/check_ins" do
    let!(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
    let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
    let!(:aspiration) { create(:aspiration, company: organization, name: 'Test Aspiration') }
    let!(:assignment_check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }
    let!(:aspiration_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }

    context "wizard header links" do
      before do
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "uses the correct teammate in step links" do
        # Create another teammate to ensure we're not accidentally using the wrong one
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization)
        
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # Verify Step 1 link uses the correct teammate
        step1_path = organization_company_teammate_check_ins_path(organization, employee_teammate)
        expect(html).to include(step1_path)
        expect(html).not_to include(organization_company_teammate_check_ins_path(organization, other_teammate))
        
        # Verify Step 2 link uses the correct teammate
        step2_path = organization_company_teammate_finalization_path(organization, employee_teammate)
        expect(html).to include(step2_path)
        expect(html).not_to include(organization_company_teammate_finalization_path(organization, other_teammate))
        
        # Verify Step 3 link uses the correct teammate
        step3_path = audit_organization_employee_path(organization, employee_teammate)
        expect(html).to include(step3_path)
        expect(html).not_to include(audit_organization_employee_path(organization, other_teammate))
      end
    end

    context "manager viewing employee check-ins" do
      before do
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "shows only manager fields and hides employee fields" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # Should see manager section headers in table headers
        expect(html).to include('Manager Rating')
        expect(html).to include('Manager Notes')
        
        # Should NOT see employee section headers in table headers
        expect(html).not_to include('Employee Rating')
        expect(html).not_to include('Employee Notes')
        
        # Should see manager fields for aspirations
        expect(html).to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[manager_rating\]/)
        expect(html).to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[manager_private_notes\]/)
        
        # Should NOT see employee fields for aspirations
        expect(html).not_to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[employee_rating\]/)
        expect(html).not_to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[employee_private_notes\]/)
      end
    end

    context "employee viewing their own check-ins" do
      before do
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "shows only employee fields and hides manager fields" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # Should see employee section headers in table headers
        expect(html).to include('Employee Rating')
        expect(html).to include('Employee Notes')
        
        # Should NOT see manager section headers in table headers
        expect(html).not_to include('Manager Rating')
        expect(html).not_to include('Manager Notes')
        
        # Should see employee fields for aspirations
        expect(html).to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[employee_rating\]/)
        expect(html).to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[employee_private_notes\]/)
        
        # Should NOT see manager fields for aspirations
        expect(html).not_to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[manager_rating\]/)
        expect(html).not_to match(/name=["']check_ins\[aspiration_check_ins\]\[#{aspiration_check_in.id}\]\[manager_private_notes\]/)
      end
    end

    context "critical bug test: manager should not see both sections" do
      before do
        sign_in_as_teammate_for_request(manager_person, organization)
        # Ensure check-ins are NOT completed so they go through the in_progress partial
        assignment_check_in.update!(manager_completed_at: nil, employee_completed_at: nil)
        aspiration_check_in.update!(manager_completed_at: nil, employee_completed_at: nil)
      end

      it "does not show both Employee Assessment and Manager Assessment sections" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # In table view, check for both section headers (they might appear in different contexts)
        # The key is that we should NOT see both "Employee Rating" and "Manager Rating" in the same row/context
        # when viewing as manager
        
        # Manager should see Manager Rating header
        expect(html).to include('Manager Rating')
        
        # Manager should NOT see Employee Rating header (unless in readonly mode showing both)
        # But since we're testing manager view mode, we should only see manager fields
        expect(html).not_to include('Employee Rating')
        expect(html).not_to include('Employee Notes')
      end
      
    end

    context "button visibility" do
      before do
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "shows 'Save All & Continue Editing' button on the check-ins page" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # Should see the new "Save All & Continue Editing" button (check for name attribute and text, accounting for HTML escaping)
        expect(html).to match(/name=["']save_and_continue_editing["']/)
        # Check for button text with HTML entity encoding
        expect(html).to match(/Save All (&amp;|&) Continue Editing/)
        
        # Should also see the existing "Save All & Proceed to Review Check-Ins" button
        expect(html).to match(/Save All (&amp;|&) Proceed to Review Check-Ins/)
      end

      it "shows both buttons in all three sections (position, assignment, aspiration)" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:success)
        html = response.body
        
        # Count occurrences of the continue editing button name attribute - should appear 3 times (once per section)
        continue_editing_count = html.scan(/name=["']save_and_continue_editing["']/).count
        
        # Count submit buttons - the proceed button doesn't have a name attribute, so count submit buttons in button rows
        # Each section should have 2 submit buttons (continue editing + proceed to review)
        # We can verify by checking for the button container pattern (.d-flex.gap-2) which should appear 3 times
        button_container_count = html.scan(/d-flex gap-2/).count
        
        expect(continue_editing_count).to eq(3), "Expected 'save_and_continue_editing' button to appear 3 times"
        expect(button_container_count).to be >= 3, "Expected at least 3 button containers (one per section)"
      end
    end
  end
end
