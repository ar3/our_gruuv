# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

RSpec.describe "Organizations::Teammates::PositionCheckIns", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: teammate,
      company: organization,
      position: position,
      employment_type: "full_time",
      started_at: 1.year.ago)
  end

  before do
    teammate.reload
    teammate.update!(first_employed_at: 1.year.ago) if teammate.respond_to?(:first_employed_at) && !teammate.first_employed_at
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
    allow_any_instance_of(Organizations::OrganizationNamespaceBaseController).to receive(:current_company_teammate).and_return(teammate)
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(teammate.person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  describe "GET position_check_in_organization_teammate_path" do
    it "returns http success" do
      get position_check_in_organization_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="confirm-leave"')
      expect(response.body).to match(/confirm-leave#markDirty/)
    end

    it "shows the perspective context for the open position check-in" do
      get position_check_in_organization_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("This is your perspective on #{person.casual_name} and #{title.external_title}")
      expect(response.body).to include("Your check-in on #{person.casual_name} and #{title.external_title} is currently:")
      expect(response.body).to include("draft")
    end

    it "renders the show template" do
      get position_check_in_organization_teammate_path(organization, teammate)
      expect(response).to render_template("organizations/teammates/position_check_ins/show")
    end

    context "when latest finalized is crystal clear and the open check-in is fresh on the employee side" do
      let!(:_finalized_position_check_in) do
        create(:position_check_in, :closed,
          teammate: teammate,
          employment_tenure: employment_tenure,
          official_check_in_completed_at: 5.days.ago)
      end
      let!(:_open_position_check_in) do
        create(:position_check_in,
          teammate: teammate,
          employment_tenure: employment_tenure,
          check_in_started_on: Date.current,
          employee_rating: nil,
          employee_private_notes: nil,
          manager_rating: nil,
          manager_private_notes: nil,
          employee_completed_at: nil,
          manager_completed_at: nil,
          official_check_in_completed_at: nil,
          official_rating: nil,
          shared_notes: nil,
          manager_completed_by_teammate: nil,
          finalized_by_teammate: nil)
      end

      it "shows the crystal-clear banner and early check-in link" do
        get position_check_in_organization_teammate_path(organization, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("crystal clear on where they stand")
        expect(response.body).to include("click here to check in early.")
        expect(response.body).to include("fresh-single-check-in-toggle-#{_open_position_check_in.id}")
      end

      it "links current period observations to the observations index with observee only (no rateable or timeframe)" do
        path = position_check_in_organization_teammate_path(organization, teammate)
        get path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        link = doc.at_xpath("//a[contains(., 'View all observations involving')]")
        expect(link).to be_present
        expect(link.text).to eq("View all observations involving #{person.casual_name}")

        href = link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(organization_observations_path(organization))
        expect(params["observee_ids"]).to eq([teammate.id.to_s])
        expect(params["rateable_type"]).to be_nil
        expect(params["rateable_id"]).to be_nil
        expect(params["timeframe"]).to be_nil
        expect(params["timeframe_start_date"]).to be_nil
        expect(params["timeframe_end_date"]).to be_nil
        expect(params["return_text"]).to eq("Back to 1-by-1 check-in")
        expect(params["return_url"]).to eq(path)
      end

      it "links add observation from the observations card with observee only (no rateable)" do
        path = position_check_in_organization_teammate_path(organization, teammate)
        get path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        add_link = doc.at_xpath("//a[contains(., 'Add New Win, Challenge, or Note about')]")
        expect(add_link).to be_present
        expect(add_link.text).to eq("+ Add New Win, Challenge, or Note about #{person.casual_name}")

        href = add_link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(new_organization_observation_path(organization))
        expect(params["observee_ids"]).to eq([teammate.id.to_s])
        expect(params["rateable_type"]).to be_nil
        expect(params["rateable_id"]).to be_nil
        expect(params["return_text"]).to eq("Back to 1-by-1 check-in")
        expect(params["return_url"]).to eq(path)
      end
    end
  end
end
