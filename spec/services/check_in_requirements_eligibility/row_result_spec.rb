# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInRequirementsEligibility::RowResult do
  it "uses RowCategory label when label not provided" do
    result = described_class.new(row_id: 1, category: CheckInRequirementsEligibility::RowCategory::EXCEEDING)
    expect(result.label).to eq("Exceeding 🎉")
    expect(result.exceeding?).to be true
  end

  it "uses custom label when provided" do
    result = described_class.new(row_id: 1, category: CheckInRequirementsEligibility::RowCategory::MEETING, label: "Custom")
    expect(result.label).to eq("Custom")
  end

  it "exposes predicate for each category" do
    cat = CheckInRequirementsEligibility::RowCategory
    expect(described_class.new(row_id: 1, category: cat::UNKNOWN).unknown?).to be true
    expect(described_class.new(row_id: 1, category: cat::MISS).miss?).to be true
    expect(described_class.new(row_id: 1, category: cat::MAYBE_MEETING).maybe_meeting?).to be true
    expect(described_class.new(row_id: 1, category: cat::MEETING).meeting?).to be true
    expect(described_class.new(row_id: 1, category: cat::MAYBE_EXCEEDING).maybe_exceeding?).to be true
    expect(described_class.new(row_id: 1, category: cat::EXCEEDING).exceeding?).to be true
  end
end
