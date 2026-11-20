# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeammateNameAlias, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) do
    person = create(:person, first_name: "Casey", last_name: "Jones", preferred_name: "Casey")
    create(:company_teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
  end

  it "stores a learnable nickname" do
    row = described_class.create!(company_teammate: teammate, name: "CJ", source: "transcript_learn")
    expect(row.normalized_name).to eq("cj")
  end

  it "rejects names that already match the person" do
    row = described_class.new(company_teammate: teammate, name: "Casey", source: "manual")
    expect(row).not_to be_valid
  end

  it "rejects blocked team words" do
    row = described_class.new(company_teammate: teammate, name: "the team", source: "manual")
    expect(row).not_to be_valid
  end
end
