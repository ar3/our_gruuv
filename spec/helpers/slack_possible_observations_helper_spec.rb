# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackPossibleObservationsHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:subject_person) { create(:person, preferred_name: "Pat") }
  let(:manager_person) { create(:person, preferred_name: "Morgan") }
  let(:subject_tm) { create(:company_teammate, organization: organization, person: subject_person) }
  let(:manager_tm) { create(:company_teammate, organization: organization, person: manager_person) }
  let(:viewer) { create(:company_teammate, organization: organization) }

  before do
    create(
      :employment_tenure,
      company: organization,
      company_teammate: subject_tm,
      manager_teammate: manager_tm,
      started_at: 1.year.ago,
      ended_at: nil
    )
  end

  describe "#slack_pogo_visibility_tooltip" do
    it "explains public-channel audience with subject, manager, and managers" do
      moment = build(:slack_possible_observation, subject_company_teammate: subject_tm)

      expect(helper.slack_pogo_visibility_tooltip(moment, subject: subject_tm, viewer: viewer)).to eq(
        "Since this is in a public channel, Pat, Morgan, and their managers will see this pOGO on the check-in and pOGO pages"
      )
    end

    it "uses only you when the viewer is the sole private discoverer" do
      moment = build(
        :slack_possible_observation,
        :private_or_dm,
        subject_company_teammate: subject_tm,
        discoverer_company_teammate_ids: [viewer.id]
      )

      expect(helper.slack_pogo_visibility_tooltip(moment, subject: subject_tm, viewer: viewer)).to eq(
        "Since this is in a private channel or DM, only you will see this pOGO on the check-in and pOGO pages"
      )
    end

    it "lists discoverer casual names when more than one can see a private pOGO" do
      other = create(:company_teammate, organization: organization, person: create(:person, preferred_name: "Sam"))
      moment = create(
        :slack_possible_observation,
        :private_or_dm,
        organization: organization,
        subject_company_teammate: subject_tm,
        discoverer_company_teammate_ids: [viewer.id, other.id]
      )
      viewer.person.update!(preferred_name: "Alex")

      tooltip = helper.slack_pogo_visibility_tooltip(moment, subject: subject_tm, viewer: viewer)
      expect(tooltip).to start_with("Since this is in a private channel or DM, only ")
      expect(tooltip).to end_with(" will see this pOGO on the check-in and pOGO pages")
      expect(tooltip).to include("Alex")
      expect(tooltip).to include("Sam")
    end
  end

  describe "#slack_pogo_visibility_indicator" do
    it "renders an open eye for public moments and a slash eye for private" do
      public_moment = build(:slack_possible_observation, subject_company_teammate: subject_tm)
      private_moment = build(
        :slack_possible_observation,
        :private_or_dm,
        subject_company_teammate: subject_tm,
        discoverer_company_teammate_ids: [viewer.id]
      )

      public_html = helper.slack_pogo_visibility_indicator(public_moment, subject: subject_tm, viewer: viewer)
      private_html = helper.slack_pogo_visibility_indicator(private_moment, subject: subject_tm, viewer: viewer)

      expect(public_html).to include("bi-eye")
      expect(public_html).not_to include("bi-eye-slash")
      expect(public_html).to include("data-bs-toggle=\"tooltip\"")
      expect(private_html).to include("bi-eye-slash")
    end
  end
end
