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
        expect(response.body).to include("Current Check-in")
        expect(response.body).to include("Save and stay here")
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
        expect(response.body).to include("Save and stay here")
      end

      it "links current period observations to the observations index with observee and aspiration (no timeframe)" do
        get aspiration_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        link = doc.at_xpath("//a[contains(., 'Show all observations involving')]")
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

    context "when submitting Save and stay here with current_url in check_ins" do
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
            save_and_stay: "Save and stay here"
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
            save_and_stay: "Save and stay here"
          }
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
        expect(response.body).to include("Current Check-in")
      end
    end
  end
end
