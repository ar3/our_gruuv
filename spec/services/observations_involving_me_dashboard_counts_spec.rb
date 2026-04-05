# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsInvolvingMeDashboardCounts do
  let(:company) { create(:organization, :company) }
  let(:viewer_person) { create(:person) }
  let(:viewer_teammate) { create(:company_teammate, :assigned_employee, organization: company, person: viewer_person) }
  let(:other_person) { create(:person) }

  def publish_observation!(observer:, observed_at:, privacy: :public_to_company, observee_teammate: nil)
    obs = create(
      :observation,
      company: company,
      observer: observer,
      privacy_level: privacy,
      published_at: Time.current,
      observed_at: observed_at,
      story: "OGO #{SecureRandom.hex(4)}"
    )
    obs.observees.destroy_all
    target = observee_teammate || create(:company_teammate, :assigned_employee, organization: company)
    obs.observees.create!(teammate: target)
    obs
  end

  describe "#rows" do
    it "returns zeros when company_teammate is nil" do
      rows = described_class.new(organization: company, person: viewer_person, company_teammate: nil).rows
      expect(rows).to eq([["I've given", 0, 0], ["About me", 0, 0]])
    end

    it "counts Ive given and About me within visible observations" do
      publish_observation!(observer: viewer_person, observed_at: 10.days.ago, observee_teammate: create(:company_teammate, :assigned_employee, organization: company))
      publish_observation!(observer: other_person, observed_at: 5.days.ago, observee_teammate: viewer_teammate)
      publish_observation!(observer: other_person, observed_at: 120.days.ago, observee_teammate: viewer_teammate)

      rows = described_class.new(
        organization: company,
        person: viewer_person,
        company_teammate: viewer_teammate,
        current_person: viewer_person
      ).rows

      ive = rows.find { |r| r[0] == "I've given" }
      about = rows.find { |r| r[0] == "About me" }

      expect(ive[1]).to eq(1)
      expect(ive[2]).to eq(1)
      expect(about[1]).to eq(1)
      expect(about[2]).to eq(2)
    end
  end
end
