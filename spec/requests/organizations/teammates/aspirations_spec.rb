# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

RSpec.describe "Organizations::Teammates::Aspirations (values page)", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let!(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:aspiration) { create(:aspiration, company: organization, name: "Test Value") }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago) if manager_teammate.respond_to?(:first_employed_at)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
  end

  def aspiration_show_path
    organization_teammate_aspiration_path(organization, employee_teammate, aspiration)
  end

  describe "GET show (teammate aspiration / values page)" do
    context "when there are no check-ins yet" do
      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "returns success and loads the page (find_or_create_open_for creates an open check-in)" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="confirm-leave"')
        expect(response.body).to match(/confirm-leave#markDirty/)
        expect(response.body).to include(aspiration.name)
        expect(response.body).to include("Associated Goals")
        expect(response.body).to include(my_growth_goals_organization_company_teammate_path(organization, employee_teammate))
        expect(response.body).to include("View all of #{employee_person.casual_name}'s goals")
        expect(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).count).to eq(1)
        expect(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).open.count).to eq(1)
      end
    end

    context "when there is an open check-in" do
      before do
        create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "returns success and shows the current check-in form" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="confirm-leave"')
        expect(response.body).to match(/confirm-leave#markDirty/)
        expect(response.body).to include("Current Check-in")
        expect(response.body).to include("Save as Draft and stay here")
      end

      it "shows disabled delete for company aspirational values" do
        get aspiration_show_path
        expect(response.body).to include("... OR...")
        expect(response.body).to include("[Delete this check-in]")
        expect(response.body).to include("company aspirational value")
        expect(response.body).not_to include(destroy_open_check_in_organization_teammate_aspiration_path(organization, employee_teammate, aspiration))
      end

      it "shows the perspective context in a notes strip above the form" do
        get aspiration_show_path
        expect(response.body).to include('class="check-in-perspective-notes mb-3"')
        expect(response.body).to include("This is your perspective on #{employee_person.casual_name} and #{aspiration.name}")
        expect(response.body).to include("until now.")
        expect(response.body).to include("Your check-in on #{employee_person.casual_name} and #{aspiration.name} is currently:")
        expect(response.body).to include('class="badge bg-warning text-dark rounded-pill me-1"')
        expect(response.body).to include("draft")
        expect(response.body).to include("click the blue button below to mark it ready for review")
      end
    end

    context "when manager has values and employee views the page (department aspiration)" do
      let(:aspiration) { create(:aspiration, :with_department, company: organization, name: "Dept Value") }

      before do
        create(:aspiration_check_in,
          teammate: employee_teammate,
          aspiration: aspiration,
          manager_private_notes: "I entered notes")
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "renders a disabled delete control with tooltip guidance" do
        get aspiration_show_path
        expect(response.body).to include("[Delete this check-in]")
        expect(response.body).to include("has to remove the values")
      end
    end

    context "when latest finalized is crystal clear and the open check-in is still fresh on the employee side" do
      let!(:_finalized_aspiration_check_in) do
        create(:aspiration_check_in, :finalized,
          teammate: employee_teammate,
          aspiration: aspiration,
          official_check_in_completed_at: 5.days.ago)
      end
      let!(:_open_aspiration_check_in) do
        create(:aspiration_check_in,
          teammate: employee_teammate,
          aspiration: aspiration,
          check_in_started_on: Date.current)
      end

      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "shows the crystal-clear banner and check-in early link instead of leading with the form" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("crystal clear on where they stand")
        expect(response.body).to include("thinking about them and #{aspiration.name}")
        expect(response.body).to include("click here to check in early.")
        expect(response.body).to include("fresh-single-check-in-toggle-#{_open_aspiration_check_in.id}")
        expect(response.body).to include("Save as Draft and stay here")
      end

      it "links current period observations to the observations index with observee and aspiration (no timeframe)" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        link = doc.at_xpath("//a[contains(., 'View all observations involving')]")
        expect(link).to be_present
        expect(link.text).to include(employee_person.casual_name)
        expect(link.text).to include(aspiration.name)

        href = link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(organization_observations_path(organization))
        expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
        expect(params["rateable_type"]).to eq("Aspiration")
        expect(params["rateable_id"]).to eq(aspiration.id.to_s)
        expect(params["timeframe"]).to be_nil
        expect(params["timeframe_start_date"]).to be_nil
        expect(params["timeframe_end_date"]).to be_nil
        expect(params["return_text"]).to eq("Back to 1-by-1 check-in")
        expect(params["return_url"]).to eq(aspiration_show_path)
      end

      it "links add observation from the observations card with observee and aspiration" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        add_link = doc.at_xpath("//a[contains(., 'Add New Win, Challenge, or Note about')]")
        expect(add_link).to be_present
        expect(add_link.text).to include(employee_person.casual_name)
        expect(add_link.text).to include(aspiration.name)

        href = add_link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(new_organization_observation_path(organization))
        expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
        expect(params["rateable_type"]).to eq("Aspiration")
        expect(params["rateable_id"]).to eq(aspiration.id.to_s)
        expect(params["return_text"]).to eq("Back to 1-by-1 check-in")
        expect(params["return_url"]).to eq(aspiration_show_path)
      end
    end

    context "when employee has marked ready for review and views the page" do
      before do
        create(:aspiration_check_in, :employee_completed, teammate: employee_teammate, aspiration: aspiration)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "shows the success pill and save-and-keep copy for the viewer side" do
        get aspiration_show_path
        expect(response.body).to include('class="badge bg-success rounded-pill me-1"')
        expect(response.body).to include("ready for review")
        expect(response.body).to include("click the blue button below to save and keep it ready for review")
      end
    end

    context "when check-in is completed by employee only" do
      before do
        create(:aspiration_check_in, :employee_completed, teammate: employee_teammate, aspiration: aspiration)
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it "returns success and shows the form for manager input" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Manager Rating")
      end

      it "shows counterparty ready-for-review clause and draft pill for manager side" do
        get aspiration_show_path
        expect(response.body).to include("#{employee_person.casual_name} has reflected on this and marked their check-in ready for review")
        expect(response.body).to include('class="badge bg-warning text-dark rounded-pill me-1"')
        expect(response.body).to include("draft")
      end
    end

    context "when check-in is completed by manager only" do
      before do
        create(:aspiration_check_in, :manager_completed, teammate: employee_teammate, aspiration: aspiration)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "returns success and shows the form for employee input" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("My Rating")
      end
    end

    context "when manager has completed their side of the check-in" do
      before do
        create(:aspiration_check_in, :manager_completed, teammate: employee_teammate, aspiration: aspiration)
      end

      it "loads the page successfully for the employee" do
        sign_in_as_teammate_for_request(employee_person, organization)
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end

      it "loads the page successfully for the manager" do
        sign_in_as_teammate_for_request(manager_person, organization)
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end

    context "when check-in is ready for finalization (both sides completed)" do
      before do
        create(:aspiration_check_in, :ready_for_finalization, teammate: employee_teammate, aspiration: aspiration)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "returns success and shows Ready for review / Finalize" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Ready for Finalization").or include("Finalize")
      end
    end

    context "when there is one finalized check-in that is not acknowledged" do
      let!(:snapshot) do
        create(:maap_snapshot,
          employee_company_teammate: employee_teammate,
          creator_company_teammate: manager_teammate,
          company: organization,
          change_type: 'aspiration_management',
          effective_date: 1.day.ago,
          employee_acknowledged_at: nil)
      end

      before do
        create(:aspiration_check_in, :finalized, teammate: employee_teammate, aspiration: aspiration, maap_snapshot: snapshot)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "returns success and behaves like there is no open check-in — find_or_create_open_for creates a new open one" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        open_check_ins = AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).open
        expect(open_check_ins.count).to eq(1)
        expect(open_check_ins.first.id).not_to eq(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).closed.first.id)
      end

      it "shows Current Check-in form so a new check-in can be started and saved" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Current Check-in")
      end
    end
  end

  describe "PATCH check_ins (save from values page)" do
    let(:open_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }

    before { sign_in_as_teammate_for_request(employee_person, organization) }

    context "when submitting Save as Draft and stay here with current_url in check_ins" do
      it "saves and redirects back to the aspiration (values) page, not review" do
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              current_url: aspiration_show_path,
              current_type: "aspiration",
              current_id: aspiration.id.to_s,
              aspiration_check_ins: {
                open_check_in.id.to_s => {
                  aspiration_id: aspiration.id.to_s,
                  employee_rating: "meeting",
                  employee_private_notes: "My notes",
                  status: "draft"
                }
              }
            },
            save_and_draft_stay: "Save as Draft and stay here"
          }

        expect(response).to redirect_to(aspiration_show_path)
        expect(flash[:notice]).to eq("Check-ins saved successfully.")
        open_check_in.reload
        expect(open_check_in.employee_rating).to eq("meeting")
        expect(open_check_in.employee_private_notes).to eq("My notes")
      end
    end

    context "when returning to the page after save" do
      it "loads the page successfully without error" do
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
          params: {
            check_ins: {
              current_url: aspiration_show_path,
              current_type: "aspiration",
              current_id: aspiration.id.to_s,
              aspiration_check_ins: {
                open_check_in.id.to_s => {
                  aspiration_id: aspiration.id.to_s,
                  status: "draft"
                }
              }
            },
            save_and_draft_stay: "Save as Draft and stay here"
          }
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
        expect(response.body).to include("Current Check-in")
      end
    end
  end

  describe "DELETE destroy_open_check_in" do
    context "department aspiration when the other side has no values" do
      let(:aspiration) { create(:aspiration, :with_department, company: organization, name: "Dept Value Delete") }
      let!(:open_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }
      let(:delete_path) do
        destroy_open_check_in_organization_teammate_aspiration_path(organization, employee_teammate, aspiration)
      end

      before do
        open_check_in.update!(manager_rating: nil, manager_private_notes: nil)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "deletes the current open check-in and redirects back to the same page" do
        deleted_id = open_check_in.id
        expect do
          delete delete_path
        end.to change { AspirationCheckIn.where(id: deleted_id).count }.from(1).to(0)
        expect(response).to redirect_to(aspiration_show_path)
        expect(flash[:notice]).to eq("That open check-in was deleted.")

        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).open.first).to be_nil
      end
    end

    context "department aspiration when the other side has entered values" do
      let(:aspiration) { create(:aspiration, :with_department, company: organization, name: "Dept Value Blocked") }
      let!(:open_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }
      let(:delete_path) do
        destroy_open_check_in_organization_teammate_aspiration_path(organization, employee_teammate, aspiration)
      end

      before do
        open_check_in.update!(manager_rating: "meeting")
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "does not delete and shows a blocking alert" do
        expect do
          delete delete_path
        end.not_to change { AspirationCheckIn.where(id: open_check_in.id).count }
        expect(response).to redirect_to(aspiration_show_path)
        expect(flash[:alert]).to include("cannot be deleted yet")
      end
    end

    context "company-level aspiration" do
      let!(:open_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }
      let(:delete_path) do
        destroy_open_check_in_organization_teammate_aspiration_path(organization, employee_teammate, aspiration)
      end

      before do
        open_check_in.update!(manager_rating: nil, manager_private_notes: nil)
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it "does not delete" do
        expect do
          delete delete_path
        end.not_to change { AspirationCheckIn.where(id: open_check_in.id).count }
        expect(response).to redirect_to(aspiration_show_path)
        expect(flash[:alert]).to include("company aspirational value")
      end
    end
  end
end
