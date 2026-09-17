# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MAAP Cleanup Inbox", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/maap_cleanup_inbox" do
    it "renders the beta inbox with seat ↔ position section" do
      get organization_maap_cleanup_inbox_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("MAAP Cleanup Inbox")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Seat ↔ Position Alignment")
      expect(response.body).to include("Active tenures where seat titles do not include the position title")
      expect(response.body).to include("Show")
      expect(response.body).to include("maapCleanupInboxPageHelp")
    end

    it "expands the mismatched subtype and shows thin Change Seat / Add Positions actions" do
      other_title = create(:title, company: organization)
      seat = create(:seat, title: other_title, seat_needed_by: Date.current + 2.months)
      tenure = create(
        :employment_tenure,
        company: organization,
        company_teammate: teammate,
        seat: seat,
        ended_at: nil
      )

      get organization_maap_cleanup_inbox_path(organization, expand: ["mismatched_seat_position"])

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hide")
      expect(response.body).to include(person.display_name)
      expect(CGI.unescapeHTML(response.body)).to include("Change #{person.casual_name}'s Seat")
      expect(response.body).to include("Add Positions to #{seat.display_name}")
      expect(response.body).to include(
        edit_organization_company_teammate_employment_tenure_path(organization, teammate, tenure)
      )
      expect(response.body).to include(manage_titles_organization_seat_path(organization, seat))
      expect(response.body).to include("btn-link")
      expect(response.body).to include("link-primary")
      expect(response.body).to include("text-decoration-underline")
      expect(response.body).to include("bi-box-arrow-up-right")
    end

    it "is linked from Beta navigation" do
      get organization_start_here_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_maap_cleanup_inbox_path(organization))
      expect(response.body).to include("MAAP Cleanup Inbox")
    end
  end
end
