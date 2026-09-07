# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeammateModalityHeaderHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, first_name: "Alex") }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    without_partial_double_verification do
      allow(helper).to receive(:current_organization).and_return(organization)
      allow(helper).to receive(:current_company_teammate).and_return(teammate)
      allow(helper).to receive(:teammate_route_param).and_return(teammate)
    end
  end

  describe "#teammate_modality_path_for_teammate_switch" do
    it "uses preferred path when modality is allowed" do
      allow(helper).to receive(:teammate_modality_allowed?).with(teammate, :kudos).and_return(true)

      path = helper.teammate_modality_path_for_teammate_switch(
        organization, teammate, preferred_path: "/preferred", modality_key: :kudos
      )

      expect(path).to eq("/preferred")
    end

    it "falls back to internal when preferred modality is not allowed" do
      allow(helper).to receive(:teammate_modality_allowed?).with(teammate, :kudos).and_return(false)
      allow(helper).to receive(:policy).with(teammate).and_return(double(internal?: true))

      path = helper.teammate_modality_path_for_teammate_switch(
        organization, teammate, preferred_path: "/kudos", modality_key: :kudos
      )

      expect(path).to eq(internal_organization_company_teammate_path(organization, teammate))
    end
  end

  describe "#people_current_modality_key" do
    it "maps kudos_points to :kudos" do
      allow(helper).to receive(:controller_name).and_return("company_teammates")
      allow(helper).to receive(:action_name).and_return("kudos_points")
      expect(helper.people_current_modality_key).to eq(:kudos)
    end

    it "maps internal to :teammate" do
      allow(helper).to receive(:controller_name).and_return("company_teammates")
      allow(helper).to receive(:action_name).and_return("internal")
      allow(helper).to receive(:clarity_check_ins_view_active?).and_return(false)
      expect(helper.people_current_modality_key).to eq(:teammate)
    end
  end

  describe "#teammate_modality_closed_label" do
    it "strips the teammate casual possessive from the closed header label" do
      casual = teammate.person.casual_name
      allow(helper).to receive(:people_current_view_name).and_return("#{casual}'s Growth")
      expect(helper.teammate_modality_closed_label(teammate)).to eq("Growth")
    end

    it "leaves labels without the casual possessive unchanged" do
      allow(helper).to receive(:people_current_view_name).and_return("Clarity Check-ins")
      expect(helper.teammate_modality_closed_label(teammate)).to eq("Clarity Check-ins")
    end
  end

  describe "#can_set_assignments_for_teammate?" do
    it "is false when viewing self without manage_employment" do
      allow(helper).to receive(:policy).with(organization).and_return(double(manage_employment?: false))

      expect(helper.can_set_assignments_for_teammate?(teammate)).to eq(false)
    end

    it "is true when viewer is in the managerial hierarchy" do
      report = create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
      allow(helper).to receive(:policy).with(organization).and_return(double(manage_employment?: false))
      allow(teammate).to receive(:in_managerial_hierarchy_of?).with(report).and_return(true)

      expect(helper.can_set_assignments_for_teammate?(report)).to eq(true)
    end

    it "is true for self when viewer has manage_employment" do
      allow(helper).to receive(:policy).with(organization).and_return(double(manage_employment?: true))

      expect(helper.can_set_assignments_for_teammate?(teammate)).to eq(true)
    end
  end
end
