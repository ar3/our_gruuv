# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::SuggestTeammatesFromText do
  let(:organization) { create(:organization) }
  let(:pat) do
    person = create(:person, full_name: "Pat Subject", preferred_name: "Pat")
    create(:company_teammate, person: person, organization: organization)
  end
  let(:other) do
    person = create(:person, full_name: "Sam Other")
    create(:company_teammate, person: person, organization: organization)
  end

  before do
    pat
    other
  end

  it "returns teammates whose names appear in the text" do
    results = described_class.call(
      organization: organization,
      plaintext: "Today Pat shipped the feature and everyone celebrated."
    )
    expect(results).to include(pat)
    expect(results).not_to include(other)
  end
end
