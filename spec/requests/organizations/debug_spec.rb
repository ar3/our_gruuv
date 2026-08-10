# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Debug", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:regular) { create(:person) }
  let!(:manager_teammate) do
    create(
      :teammate,
      person: manager,
      organization: organization,
      can_manage_employment: true,
      first_employed_at: 1.year.ago
    )
  end
  let!(:regular_teammate) do
    create(
      :teammate,
      person: regular,
      organization: organization,
      can_manage_employment: false,
      first_employed_at: 1.year.ago
    )
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  describe "GET /organizations/:organization_id/debug" do
    context "when user can manage employment" do
      before { sign_in_as_teammate_for_request(manager, organization) }

      it "renders the debug page with section headings" do
        get organization_debug_path(organization)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Debug")
        expect(response.body).to include("Active assignment tenures without active employment")
        expect(response.body).to include("Archived MAAP records with open check-ins")
        expect(response.body).to include("Clears nightly")
        expect(response.body).to include("Needs person")
      end

      it "shows a finding for no employment with active assignment" do
        orphan = create(
          :teammate,
          organization: organization,
          first_employed_at: 6.months.ago,
          last_terminated_at: 1.day.ago
        )
        assignment = create(:assignment, company: organization, title: "Orphaned Work")
        create(
          :assignment_tenure,
          teammate: orphan,
          assignment: assignment,
          started_at: 1.month.ago,
          ended_at: nil
        )

        get organization_debug_path(organization)

        expect(response.body).to include("Orphaned Work")
        expect(response.body).to include("Assignment management")
      end
    end

    context "when user cannot manage employment" do
      before { sign_in_as_teammate_for_request(regular, organization) }

      it "denies access" do
        get organization_debug_path(organization)
        expect(response).not_to have_http_status(:success)
      end
    end
  end
end
