# frozen_string_literal: true

require "rails_helper"

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
    end

    it "renders the show template" do
      get position_check_in_organization_teammate_path(organization, teammate)
      expect(response).to render_template("organizations/teammates/position_check_ins/show")
    end
  end
end
