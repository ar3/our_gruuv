# frozen_string_literal: true

require "rails_helper"

RSpec.describe KudosWallDashboardCounts do
  let(:company) { create(:organization, :company) }
  let(:observer_person) { create(:person) }
  let(:observee_teammate) { create(:company_teammate, organization: company) }

  def build_public_kudos(observed_time:, observer:)
    obs = create(
      :observation,
      company: company,
      observer: observer,
      privacy_level: :public_to_company,
      published_at: Time.current,
      observation_type: :kudos,
      observed_at: observed_time,
      story: "Kudos story #{SecureRandom.hex(4)}"
    )
    obs.observees.destroy_all
    obs.observees.create!(teammate: observee_teammate)
    obs
  end

  describe "#rows" do
    it "returns zeros when person is nil" do
      rows = described_class.new(organization: company, person: nil).rows(org_display_name: "Acme")
      expect(rows[0][1..]).to eq([0, 0, 0])
    end

    it "counts Ive given and org totals" do
      build_public_kudos(observed_time: 3.days.ago, observer: observer_person)
      build_public_kudos(observed_time: 100.days.ago, observer: observee_teammate.person)

      rows = described_class.new(organization: company, person: observer_person).rows(org_display_name: "Acme")

      ive = rows.find { |r| r[0] == "I've given" }
      all_row = rows.find { |r| r[0].start_with?("All of ") }

      expect(ive[3]).to eq(1)
      expect(all_row[3]).to eq(2)
    end
  end
end
