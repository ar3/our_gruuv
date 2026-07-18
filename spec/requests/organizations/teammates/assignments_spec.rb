# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

RSpec.describe "Organizations::Teammates::Assignments (1-by-1 check-in page)", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Key Outcome Alpha") }
  let!(:assignment_tenure) do
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 35)
  end

  before do
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
  end

  def assignment_show_path(**options)
    organization_teammate_assignment_path(organization, employee_teammate, assignment, **options)
  end

  describe "GET show" do
    context "when the employee has no open check-in" do
      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "still shows assignment energy allocation bars and page help" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="assignment-energy-allocation"')
        expect(response.body).to include("Planned Assignment-energy split")
        expect(response.body).to include("See and edit all assignments on bulk check-in")
        expect(response.body).to include("No open check-in")
        expect(response.body).not_to include('data-controller="check-in-autosave"')
      end
    end

    context "when a manager views the employee assignment page" do
      let(:manager_person) { create(:person) }
      let!(:manager_teammate) do
        create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true)
      end

      before do
        create(:employment_tenure,
          teammate: manager_teammate,
          company: organization,
          started_at: 1.year.ago,
          ended_at: nil)
        EmploymentTenure.find_by!(company_teammate: employee_teammate, company: organization).update!(manager_teammate: manager_teammate)
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.new(2026, 3, 15),
          employee_completed_at: nil,
          manager_completed_at: nil)
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "does not show assignment energy allocation bars" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('data-controller="assignment-energy-allocation"')
        expect(response.body).not_to include("See and edit all assignments on bulk check-in")
      end
    end

    context "when there is an open check-in" do
      before do
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.new(2026, 3, 15),
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_rating: nil,
          manager_private_notes: nil)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "accepts teammate_id me (and legacy my) for the signed-in teammate" do
        get organization_teammate_assignment_path(organization, "me", assignment)
        expect(response).to have_http_status(:success)

        get organization_teammate_assignment_path(organization, "my", assignment)
        expect(response).to have_http_status(:success)
      end

      it "shows the perspective context with assignment title" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="check-in-autosave"')
        expect(response.body).to match(/check-in-autosave#markDirty/)
        expect(response.body).to include('data-check-in-autosave-target="status"')
        expect(response.body).to include("This is your perspective on #{employee_person.casual_name} and #{assignment.title}")
        expect(response.body).to include("March 15, 2026")
        expect(response.body).to include("Your check-in on #{employee_person.casual_name} and #{assignment.title} is currently:")
        expect(response.body).to include("draft")
      end

      it "shows assignment energy allocation bars and bulk check-in link for the employee" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="assignment-energy-allocation"')
        expect(response.body).to include("data-assignment-energy-allocation-reflection-by-assignment-value")
        expect(response.body).to include("Planned Assignment-energy split")
        expect(response.body).to include("How you actually spent your energy")
        expect(response.body).to include("See and edit all assignments on bulk check-in")
        expect(response.body).to include(organization_company_teammate_check_ins_path(organization, employee_teammate))
        expect(response.body).to include("data-assignment-id=\"#{assignment.id}\"")
        expect(response.body).to include("data-assignment-energy-row")
        expect(response.body).to include('assignmentSingleItemCheckInPageHelp')
        expect(response.body).to include('What is MAAP?')
        expect(response.body).to include('Reflect Apart')
      end

      it "shows the object queue and people view switcher instead of the item dropdown" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("To get clear on")
        expect(response.body).to include("your turn")
        expect(response.body).to include("Full Up Next")
        expect(response.body).to include("Currently viewing")
        expect(response.body).not_to include("Checking-in on")
        expect(response.body).to include("1-by-1 clarity check-in")
        expect(response.body).to include('bi-eye')
      end

      it "shows an enabled delete link when other side is empty and assignment is not required" do
        get assignment_show_path
        expect(response.body).to include("... OR...")
        expect(response.body).to include("[Delete this check-in]")
        expect(response.body).not_to include("required assignment for this position")
        expect(response.body).to include(destroy_open_check_in_organization_teammate_assignment_path(organization, employee_teammate, assignment))
      end
    end

    context "when there is an open check-in and the assignment is required on the teammate's position" do
      let(:position_major_level) { create(:position_major_level) }
      let(:req_title) { create(:title, company: organization, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level) }
      let(:req_position) { create(:position, title: req_title, position_level: position_level) }

      before do
        EmploymentTenure.find_by!(company_teammate: employee_teammate, company: organization).update!(position: req_position)
        create(:position_assignment, position: req_position, assignment: assignment, assignment_type: "required")
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.new(2026, 3, 15),
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_rating: nil,
          manager_private_notes: nil)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "shows disabled delete with required-assignment tooltip" do
        get assignment_show_path
        expect(response.body).to include("[Delete this check-in]")
        expect(response.body).to include("required assignment for this position")
        expect(response.body).not_to include(destroy_open_check_in_organization_teammate_assignment_path(organization, employee_teammate, assignment))
      end

      it "renders position connection as narrative copy with blueprint energy" do
        PositionAssignment.find_by!(position: req_position, assignment: assignment).update!(
          min_estimated_energy: 20,
          max_estimated_energy: 40
        )
        get assignment_show_path
        doc = Nokogiri::HTML(response.body)
        connection = doc.at_css(".position-connection")
        expect(connection).to be_present
        normalized = connection.text.squish
        expect(normalized).to include("#{assignment.title} is required for #{req_title.external_title}")
        expect(normalized).to include("between 20% - 40%")
        expect(normalized).to include("According to the position blueprint")
        expect(connection.at_css("a.position-connection-key[href*='#{req_position.id}'][target='_blank']")).to be_present
      end
    end

    context "when latest finalized is crystal clear and the open check-in is fresh on the employee side" do
      let!(:_finalized_assignment_check_in) do
        create(:assignment_check_in, :finalized,
          teammate: employee_teammate,
          assignment: assignment,
          official_check_in_completed_at: 5.days.ago)
      end
      let!(:_open_assignment_check_in) do
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          official_check_in_completed_at: nil,
          actual_energy_percentage: 35,
          employee_rating: nil,
          manager_rating: nil,
          official_rating: nil,
          employee_personal_alignment: nil,
          employee_private_notes: nil,
          manager_private_notes: nil,
          shared_notes: nil,
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate: nil,
          finalized_by_teammate: nil)
      end

      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "shows the crystal-clear banner with assignment title and early check-in link" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("crystal clear on where they stand")
        expect(response.body).to include("thinking about them and #{assignment.title}")
        expect(response.body).to include("click here to check in early.")
        expect(response.body).to include("fresh-single-check-in-toggle-#{_open_assignment_check_in.id}")
      end

      it "renders Associated Goals on the teammate assignment page" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Associated Goals")
      end

      it "renders Consult OG evidence and a collapsed manual prompt between observations and linked goals" do
        create(:assignment_outcome, assignment: assignment, description: "Deliver weekly demos", outcome_type: "quantitative")
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Consult OG for evidence")
        expect(response.body).to include("Get evidence manually")
        expect(response.body).to include("Paste into Claude or another AI assistant")
        expect(response.body).to include("data-controller=\"clipboard\"")
        expect(response.body).to include("Copy prompt")
        expect(response.body).to include("observation-based check-in about")
        expect(response.body).to include("- Deliver weekly demos")

        body = response.body
        expect(body.index("research-observations")).to be < body.index("Consult OG for evidence")
        expect(body.index("Get evidence manually")).to be < body.index("Associated Goals")
      end

      it "renders expected outcomes as markdown in assignment details" do
        create(:assignment_outcome, assignment: assignment, description: "**Bold outcome**", outcome_type: "quantitative")
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("<strong>Bold outcome</strong>")
      end

      it "links current period observations to the observations index with observee and assignment (no timeframe)" do
        get assignment_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        link = doc.at_xpath("//a[contains(., 'View all observations involving')]")
        expect(link).to be_present
        expect(link.text).to include(employee_person.casual_name)
        expect(link.text).to include(assignment.title)

        href = link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(organization_observations_path(organization))
        expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
        expect(params["rateable_type"]).to eq("Assignment")
        expect(params["rateable_id"]).to eq(assignment.id.to_s)
        expect(params["timeframe"]).to be_nil
        expect(params["timeframe_start_date"]).to be_nil
        expect(params["timeframe_end_date"]).to be_nil
        expect(params["return_text"]).to eq("Back to 1-by-1 clarity check-in")
        expect(params["return_url"]).to eq(assignment_show_path)
      end

      it "links add observation from the observations card with observee and assignment" do
        get assignment_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        add_link = doc.at_xpath("//a[contains(., 'Add New Win, Challenge, or Note about')]")
        expect(add_link).to be_present
        expect(add_link.text).to include(employee_person.casual_name)
        expect(add_link.text).to include(assignment.title)

        href = add_link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(new_organization_observation_path(organization))
        expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
        expect(params["rateable_type"]).to eq("Assignment")
        expect(params["rateable_id"]).to eq(assignment.id.to_s)
        expect(params["return_text"]).to eq("Back to 1-by-1 clarity check-in")
        expect(params["return_url"]).to eq(assignment_show_path)
      end
    end

    context "with an associated goal" do
      let!(:associated_goal) do
        create(:goal,
          company_id: organization.id,
          creator: employee_teammate,
          owner: employee_teammate,
          title: "Linked Sample Goal",
          started_at: Time.current,
          goal_type: "inspirational_objective")
      end
      let!(:_goal_association) { create(:goal_association, associable: assignment, goal: associated_goal) }

      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "lists the goal with show link and View all goals for the teammate" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(organization_goal_path(organization, associated_goal))
        expect(response.body).to include("Linked Sample Goal")
        expect(response.body).to include(my_growth_goals_organization_company_teammate_path(organization, employee_teammate))
        expect(response.body).to include("View all of #{employee_person.casual_name}'s goals")
      end

      context "when another teammate's goal is also associated with the assignment" do
        let(:other_person) { create(:person) }
        let!(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }
        let!(:other_private_goal) do
          create(:goal, :only_creator_and_owner,
            company_id: organization.id,
            creator: other_teammate,
            owner: other_teammate,
            title: "Other Teammate Secret Goal")
        end
        let!(:_other_association) { create(:goal_association, associable: assignment, goal: other_private_goal) }

        it "does not list the other teammate's private goal on the subject's assignment page" do
          get assignment_show_path
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Linked Sample Goal")
          expect(response.body).not_to include("Other Teammate Secret Goal")
        end
      end
    end
  end

  describe "POST start_check_in" do
    let(:start_path) do
      start_check_in_organization_teammate_assignment_path(organization, employee_teammate, assignment)
    end

    before { sign_in_as_teammate_for_request(employee_person, organization) }

    it "shows the empty check-ins alert with Start a check-in when none exist yet" do
      get assignment_show_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("No Check-ins Found")
      expect(response.body).to include("Start a check-in")
      expect(response.body).to include(start_path)
      expect(AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment)).to be_empty
    end

    it "creates an open check-in and redirects back with notice when none exist yet" do
      expect(AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment)).to be_empty

      post start_path

      expect(response).to redirect_to(assignment_show_path(anchor: "check-in"))
      expect(flash[:notice]).to eq("Check-in started.")
      open = AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).open.first
      expect(open).to be_present

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your check-in")
    end

    it "is idempotent when an open check-in already exists" do
      existing = create(:assignment_check_in,
        teammate: employee_teammate,
        assignment: assignment,
        employee_completed_at: nil,
        manager_completed_at: nil,
        manager_rating: nil,
        manager_private_notes: nil)

      expect do
        post start_path
      end.not_to change { AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).count }

      expect(response).to redirect_to(assignment_show_path(anchor: "check-in"))
      expect(AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).open.first).to eq(existing)
    end

    context "when the teammate has no assignment tenure" do
      before { assignment_tenure.destroy }

      it "creates an open check-in without creating a tenure" do
        expect(AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment)).to be_empty

        post start_path

        expect(response).to redirect_to(assignment_show_path(anchor: "check-in"))
        expect(flash[:notice]).to eq("Check-in started.")
        open = AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).open.first
        expect(open).to be_present
        expect(open.actual_energy_percentage).to be_nil
        expect(AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment)).to be_empty

        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Your check-in")
      end
    end
  end

  describe "DELETE destroy_open_check_in" do
    let!(:open_check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }
    let(:delete_path) do
      destroy_open_check_in_organization_teammate_assignment_path(organization, employee_teammate, assignment)
    end

    context "when the other side has no values" do
      before do
        open_check_in.update!(
          manager_rating: nil,
          manager_private_notes: nil,
          actual_energy_percentage: 0
        )
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "deletes the current open check-in and redirects back to the same page" do
        deleted_id = open_check_in.id
        expect do
          delete delete_path
        end.to change { AssignmentCheckIn.where(id: deleted_id).count }.from(1).to(0)
        expect(response).to redirect_to(assignment_show_path)
        expect(flash[:notice]).to eq("That open check-in was deleted.")

        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).open.first).to be_nil
      end

      it "also destroys a same-day 0% active tenure created with the check-in" do
        assignment_tenure.update!(
          anticipated_energy_percentage: 0,
          started_at: open_check_in.check_in_started_on
        )

        expect do
          delete delete_path
        end.to change { AssignmentCheckIn.where(id: open_check_in.id).count }.from(1).to(0)
          .and change { AssignmentTenure.where(id: assignment_tenure.id).count }.from(1).to(0)

        expect(response).to redirect_to(assignment_show_path)
        expect(flash[:notice]).to eq("That open check-in was deleted.")
        expect(employee_teammate.assignment_tenures.active.where(assignment: assignment)).to be_empty
      end

      it "does not destroy an active tenure that started on a different day" do
        assignment_tenure.update!(
          anticipated_energy_percentage: 0,
          started_at: open_check_in.check_in_started_on - 1.day
        )

        expect do
          delete delete_path
        end.to change { AssignmentCheckIn.where(id: open_check_in.id).count }.from(1).to(0)

        expect(AssignmentTenure.where(id: assignment_tenure.id).count).to eq(1)
        expect(assignment_tenure.reload).to be_active
      end

      it "does not destroy an active tenure with non-zero energy" do
        assignment_tenure.update!(started_at: open_check_in.check_in_started_on)

        expect do
          delete delete_path
        end.to change { AssignmentCheckIn.where(id: open_check_in.id).count }.from(1).to(0)

        expect(AssignmentTenure.where(id: assignment_tenure.id).count).to eq(1)
        expect(assignment_tenure.reload).to be_active
      end
    end

    context "when the assignment is required on the teammate's position" do
      let(:position_major_level) { create(:position_major_level) }
      let(:req_title) { create(:title, company: organization, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level) }
      let(:req_position) { create(:position, title: req_title, position_level: position_level) }

      before do
        EmploymentTenure.find_by!(company_teammate: employee_teammate, company: organization).update!(position: req_position)
        create(:position_assignment, position: req_position, assignment: assignment, assignment_type: "required")
        open_check_in.update!(manager_rating: nil, manager_private_notes: nil, actual_energy_percentage: 0)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "does not delete" do
        expect do
          delete delete_path
        end.not_to change { AssignmentCheckIn.where(id: open_check_in.id).count }
        expect(response).to redirect_to(assignment_show_path)
        expect(flash[:alert]).to include("required assignment")
      end
    end

    context "when the other side has entered values" do
      before do
        open_check_in.update!(manager_private_notes: "Manager has input")
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "does not delete and shows a blocking alert" do
        expect do
          delete delete_path
        end.not_to change { AssignmentCheckIn.where(id: open_check_in.id).count }
        expect(response).to redirect_to(assignment_show_path)
        expect(flash[:alert]).to include("cannot be deleted yet")
      end
    end
  end
end
