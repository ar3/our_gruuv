# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::RedirectUrlService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }

  describe "single-item check-in redirects" do
    it "save_and_stay returns current_url when provided" do
      current_url = "/organizations/1/teammates/2/position_check_in"
      url = described_class.call(
        button_name: "save_and_stay",
        organization: organization,
        teammate: teammate,
        params: { current_url: current_url }
      )
      expect(url).to eq(current_url)
    end

    it "save_and_go_to_bulk_check_in returns check_ins path" do
      url = described_class.call(
        button_name: "save_and_go_to_bulk_check_in",
        organization: organization,
        teammate: teammate,
        params: {}
      )
      expect(url).to eq(Rails.application.routes.url_helpers.organization_company_teammate_check_ins_path(organization, teammate))
    end

    it "save_and_go_to_review_check_ins returns finalization path" do
      url = described_class.call(
        button_name: "save_and_go_to_review_check_ins",
        organization: organization,
        teammate: teammate,
        params: {}
      )
      expect(url).to eq(Rails.application.routes.url_helpers.organization_company_teammate_finalization_path(organization, teammate))
    end
  end
end
