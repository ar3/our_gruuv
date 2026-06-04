require 'rails_helper'

RSpec.describe "Organizations::CheckIns", type: :request do
  let(:organization) { create(:organization) }
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
    context "auto-save (JSON)" do
      it "persists check-in data and returns ok without redirecting" do
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  position_check_in: {
                    manager_rating: 2,
                    manager_private_notes: "Auto-saved notes",
                    status: "draft"
                  }
                },
                autosave: "1",
                save_and_continue_editing: "1"
              },
              headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["ok"]).to be true
        expect(body["saved_at"]).to be_present

        check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
        expect(check_in.manager_rating).to eq(2)
        expect(check_in.manager_private_notes).to eq("Auto-saved notes")
      end

      it "returns errors as JSON when validation fails" do
        check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
        allow(PositionCheckIn).to receive(:find_or_create_open_for).with(employee_teammate).and_return(check_in)
        invalid_record = check_in
        invalid_record.errors.add(:base, "Something went wrong")
        allow(check_in).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))

        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  position_check_in: {
                    manager_rating: 2,
                    manager_private_notes: "Bad save",
                    status: "draft"
                  }
                },
                autosave: "1",
                save_and_continue_editing: "1"
              },
              headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["ok"]).to be false
        expect(body["errors"]).to be_present
      end
    end

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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
          
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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
          
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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
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
          
          check_in = PositionCheckIn.find_by(company_teammate: employee_teammate)
          
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
        # Another teammate in the org: bulk header lists their check-ins URL, but wizard steps stay on the selected employee
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization)

        get organization_company_teammate_check_ins_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        html = response.body

        # Verify Step 1 link uses the correct teammate (header teammate switcher also links other viewable teammates)
        step1_path = organization_company_teammate_check_ins_path(organization, employee_teammate)
        expect(html).to include(step1_path)
        
        # Verify Step 2 link uses the correct teammate
        step2_path = organization_company_teammate_finalization_path(organization, employee_teammate)
        expect(html).to include(step2_path)
        expect(html).not_to include(organization_company_teammate_finalization_path(organization, other_teammate))
        
        # Verify Step 3 link uses the correct teammate
        step3_path = audit_organization_employee_path(organization, employee_teammate)
        expect(html).to include(step3_path)
        expect(html).not_to include(audit_organization_employee_path(organization, other_teammate))
      end

      it "shows bulk vs status intro with link to the check-in status page" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="check-in-autosave"')
        expect(response.body).to match(/check-in-autosave#markDirty/)
        expect(response.body).to include('data-check-in-autosave-target="status"')
        expect(response.body).to include(" - Bulk clarity check-in")
        expect(response.body).to include("complete clarity check-ins on as many or as few")
        expect(response.body).to include("Go to the clarity check-in status page")
        expect(response.body).to include("recent clarity check-ins in an easy to understand table")
        expect(response.body).to include(review_most_recent_organization_company_teammate_check_ins_path(organization, employee_teammate))
      end
    end

    context "employee viewing own bulk check-in" do
      before do
        sign_in_as_teammate_for_request(employee_person, organization)
        assignment_tenure.update!(anticipated_energy_percentage: 70)
      end

      it "shows the assignment energy allocation panel" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="assignment-energy-allocation"')
        expect(response.body).to include('bulk-assignment-check-in-energy-section')
        expect(response.body).to include('Planned Assignment-energy split')
        expect(response.body).to include('How you actually spent your energy')
        expect(response.body).to include('assignment-energy-allocation-panel')
      end
    end

    context "manager viewing employee check-ins" do
      before do
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "does not show the assignment energy allocation panel" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('data-controller="assignment-energy-allocation"')
        expect(response.body).not_to include('Planned Assignment-energy split')
      end

      it "uses save_and_view_position on the position name submit" do
        get organization_company_teammate_check_ins_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to match(/save_and_view_position/)
      end

      it "redirects to the 1-by-1 position check-in page after save when using the position name submit" do
        position_label = position.display_name
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  save_and_view_position: position_label,
                  position_check_in: {
                    manager_rating: 2,
                    manager_private_notes: "notes from position submit",
                    status: "draft"
                  }
                }
              }

        expect(response).to redirect_to(
          position_check_in_organization_teammate_path(organization, employee_teammate)
        )
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
        expect(html).to match(/Save All (&amp;|&) Proceed to Review clarity check-ins/)
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

  describe "GET /organizations/:org_id/company_teammates/:company_teammate_id/check_ins/review_most_recent" do
    let!(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
    let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
    let!(:aspiration) { create(:aspiration, company: organization, name: 'Test Aspiration') }

    let!(:paired_assignment_check_in) do
      create(
        :assignment_check_in,
        teammate: employee_teammate,
        assignment: assignment,
        employee_completed_at: 12.days.ago,
        manager_completed_at: 11.days.ago,
        manager_completed_by_teammate: manager_teammate,
        official_check_in_completed_at: 10.days.ago,
        finalized_by_teammate: manager_teammate,
        official_rating: 'meeting',
        check_in_started_on: 14.days.ago.to_date
      )
    end

    let!(:employee_only_assignment_check_in) do
      create(
        :assignment_check_in,
        teammate: employee_teammate,
        assignment: assignment,
        employee_completed_at: 2.days.ago,
        manager_completed_at: nil,
        check_in_started_on: 3.days.ago.to_date
      )
    end

    let!(:employee_only_aspiration_check_in) do
      create(
        :aspiration_check_in,
        :employee_completed,
        teammate: employee_teammate,
        aspiration: aspiration,
        check_in_started_on: 3.days.ago.to_date
      )
    end

    it "renders the check-in statuses table and waiting copy for unpaired aspiration employee completion" do
      sign_in_as_teammate_for_request(manager_person, organization)

      get review_most_recent_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(" - Clarity check-in statuses")
      expect(response.body).to include(employee_person.casual_name)
      expect(response.body).not_to include('id="teammate_switcher"')
      expect(response.body).to include('Start a clarity check-in on any single assignment, value, or position one at a time')
      expect(response.body).to include('Go to the Bulk clarity check-in page')
      expect(response.body).to include('complete a clarity check-in on just one item or all of them at once')
      expect(response.body).to include('Clarity Check-Ins (Active)')
      expect(response.body).to include('Last Reviewed')
      expect(response.body).to include("Last Check-In by #{employee_person.casual_name}")
      expect(response.body).to include(organization_teammate_aspiration_path(organization, employee_teammate, aspiration))
      expect(response.body).to include('completed a new check-in')
      expect(response.body).to include('is waiting on')
    end

    it "shows the same core table columns when viewed by the employee" do
      sign_in_as_teammate_for_request(employee_person, organization)

      get review_most_recent_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Go to the Bulk clarity check-in page')
      expect(response.body).to include('Last Reviewed')
      expect(response.body).to include("Last Check-In by #{employee_person.casual_name}")
      expect(response.body).to include('Last Check-In by')
    end

    it "shows a joint-review outline button in Last Reviewed when both sides completed the open assignment check-in" do
      assignment_ready = create(:assignment, company: organization, title: 'Joint Review Assignment')
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_ready, started_at: 6.months.ago)

      create(
        :assignment_check_in,
        teammate: employee_teammate,
        assignment: assignment_ready,
        employee_completed_at: 60.days.ago,
        manager_completed_at: 59.days.ago,
        manager_completed_by_teammate: manager_teammate,
        official_check_in_completed_at: 58.days.ago,
        finalized_by_teammate: manager_teammate,
        official_rating: 'meeting',
        check_in_started_on: 62.days.ago.to_date
      )
      create(
        :assignment_check_in,
        teammate: employee_teammate,
        assignment: assignment_ready,
        employee_completed_at: 2.days.ago,
        manager_completed_at: 1.day.ago,
        manager_completed_by_teammate: manager_teammate,
        official_check_in_completed_at: nil,
        check_in_started_on: 2.days.ago.to_date
      )

      sign_in_as_teammate_for_request(manager_person, organization)
      get review_most_recent_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      button_text = "Time for #{employee_person.casual_name} and #{manager_person.casual_name} to review Joint Review Assignment together!"
      expect(response.body).to include(button_text)
      expect(response.body).to include('btn-outline-warning')
      expect(response.body).to include(organization_company_teammate_finalization_path(organization, employee_teammate))
    end
  end

  describe "GET /organizations/:org_id/company_teammates/:company_teammate_id/check_ins/hub" do
    before do
      sign_in_as_teammate_for_request(manager_person, organization)
    end

    it "renders the Clarity Check-Ins with key action links" do
      get hub_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(" - Clarity Check-Ins")
      expect(response.body).to include("Clarity Check-Ins (Active)")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Five ways to check in")
      expect(response.body).to include("Five ways to check in below")
      expect(response.body).not_to include("Choose one of these 5 actions")
      expect(response.body).to include("See full queue")
      expect(response.body).to include("up next for #{employee_person.casual_name} and #{manager_person.casual_name}")
      expect(response.body).to include(up_next_organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(response.body).to include(organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(response.body).to include(review_most_recent_organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(response.body).to include(organization_company_teammate_finalization_path(organization, employee_teammate))
      expect(response.body).to include(audit_organization_employee_path(organization, employee_teammate))
      expect(response.body).to include("One on One Hub")
    end
  end

  describe "GET /organizations/:org_id/company_teammates/:company_teammate_id/check_ins/up_next" do
    before do
      sign_in_as_teammate_for_request(manager_person, organization)
    end

    it "renders the up next explainer with both perspectives and links" do
      assignment = create(:assignment, company: organization, title: "Up Next Assignment")
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago)
      aspiration = create(:aspiration, company: organization, name: "Up Next Aspiration")
      AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
      AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      PositionCheckIn.find_or_create_open_for(employee_teammate)

      get up_next_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(" - Clarity Check-ins... Up Next")
      expect(response.body).to include("Clarity Check-Ins (Active)")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Status pill on each item")
      expect(response.body).to include("#{employee_person.casual_name} perspective")
      expect(response.body).to include("#{manager_person.casual_name} perspective")
      expect(response.body).to include("#{employee_person.casual_name} should do a check-in right now")
      expect(response.body).to include("#{manager_person.casual_name} should do a check-in right now")
      expect(response.body).to include('badge rounded-pill')
      expect(response.body).not_to match(/1\. Up Next Aspiration/)
      expect(response.body).to include("Therefore this is")
      expect(response.body).to include("Required status:")
      expect(response.body).to include("/organizations/#{organization.to_param}/teammates/#{employee_teammate.id}/assignments/#{assignment.id}")
      expect(response.body).to include("/organizations/#{organization.to_param}/teammates/#{employee_teammate.id}/aspirations/#{aspiration.id}")
      expect(response.body).to include(position_check_in_organization_teammate_path(organization, employee_teammate))
      expect(response.body).to include(
        "Don't see an Assignment that you are ready to start / do a check-in on?"
      )
      expect(response.body).to include(
        assignment_selection_organization_company_teammate_path(organization, employee_teammate)
      )
    end

    it "shows a review-together button when an open check-in is ready for finalization" do
      aspiration = create(:aspiration, company: organization, name: "Ready Aspiration")
      create(
        :aspiration_check_in,
        :ready_for_finalization,
        teammate: employee_teammate,
        aspiration: aspiration,
        manager_completed_by_teammate: manager_teammate
      )

      get up_next_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(
        "Ready Aspiration is ready for #{employee_person.casual_name} and #{manager_person.casual_name} to review together"
      )
      expect(response.body).to include(
        organization_company_teammate_finalization_path(organization, employee_teammate)
      )
      expect(response.body).to include("bi-box-arrow-up-right")
    end
  end
end
