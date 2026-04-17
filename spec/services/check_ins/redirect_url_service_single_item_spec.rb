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

    it "save_and_view_position returns the 1-by-1 position check-in path" do
      url = described_class.call(
        button_name: "save_and_view_position",
        organization: organization,
        teammate: teammate,
        params: {}
      )
      expect(url).to eq(
        Rails.application.routes.url_helpers.position_check_in_organization_teammate_path(organization, teammate)
      )
    end

    it "save_and_view_observations_position redirects to position 1-by-1 observations section" do
      url = described_class.call(
        button_name: "save_and_view_observations_position",
        organization: organization,
        teammate: teammate,
        params: {}
      )

      expected = Rails.application.routes.url_helpers.position_check_in_organization_teammate_path(organization, teammate)
      expect(url).to eq("#{expected}#current-period-observations")
    end

    it "save_and_view_observations_assignment redirects to assignment 1-by-1 observations section" do
      assignment = create(:assignment, company: organization)
      url = described_class.call(
        button_name: "save_and_view_observations_assignment_#{assignment.id}",
        organization: organization,
        teammate: teammate,
        params: {}
      )

      expected = Rails.application.routes.url_helpers.organization_teammate_assignment_path(
        organization,
        teammate,
        assignment.id
      )
      expect(url).to eq("#{expected}#current-period-observations")
    end

    it "save_and_view_observations_aspiration redirects to aspiration 1-by-1 observations section" do
      aspiration = create(:aspiration, company: organization)
      url = described_class.call(
        button_name: "save_and_view_observations_aspiration_#{aspiration.id}",
        organization: organization,
        teammate: teammate,
        params: {}
      )

      expected = Rails.application.routes.url_helpers.organization_teammate_aspiration_path(
        organization,
        teammate,
        aspiration.id
      )
      expect(url).to eq("#{expected}#current-period-observations")
    end

    it "save_and_view_observations_ability redirects to ability 1-by-1 observations section" do
      ability = create(:ability, company: organization)
      url = described_class.call(
        button_name: "save_and_view_observations_ability_#{ability.id}",
        organization: organization,
        teammate: teammate,
        params: {}
      )

      expected = Rails.application.routes.url_helpers.organization_teammate_ability_path(
        organization,
        teammate,
        ability.id
      )
      expect(url).to eq("#{expected}#current-period-observations")
    end

    it "save_and_go_to_next returns teammate check-ins page when no items require check-in" do
      allow(CheckIns::SingleItemCheckInNextItemService).to receive(:call).and_return(
        {
          next_requires_check_in: false,
          show_check_in_status_done: false,
          next_url: "/organizations/#{organization.id}/teammates/#{teammate.id}/position_check_in"
        }
      )

      url = described_class.call(
        button_name: "save_and_go_to_next",
        organization: organization,
        teammate: teammate,
        params: {
          current_person: teammate.person,
          current_type: "aspiration",
          current_id: "123"
        }
      )

      expect(url).to eq(
        Rails.application.routes.url_helpers.organization_company_teammate_check_ins_path(organization, teammate)
      )
    end

    it "save_and_go_to_next returns teammate check-ins page when current is red but all other items are green" do
      allow(CheckIns::SingleItemCheckInNextItemService).to receive(:call).and_return(
        {
          next_requires_check_in: true,
          show_check_in_status_done: true,
          next_url: "/organizations/#{organization.id}/teammates/#{teammate.id}/aspirations/1"
        }
      )

      url = described_class.call(
        button_name: "save_and_go_to_next",
        organization: organization,
        teammate: teammate,
        params: {
          current_person: teammate.person,
          current_type: "aspiration",
          current_id: "1"
        }
      )

      expect(url).to eq(
        Rails.application.routes.url_helpers.organization_company_teammate_check_ins_path(organization, teammate)
      )
    end
  end
end
