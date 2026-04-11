# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::CoerceBlankCheckInAttrs do
  describe ".call" do
    it "sets nil only for listed keys that are present and blank" do
      out = described_class.call(
        { "employee_rating" => "", "employee_private_notes" => "  ", "actual_energy_percentage" => 40 },
        described_class::ASSIGNMENT_EMPLOYEE
      )
      expect(out[:employee_rating]).to be_nil
      expect(out[:employee_private_notes]).to be_nil
      expect(out[:actual_energy_percentage]).to eq(40)
    end

    it "does not add keys that were not in the hash" do
      out = described_class.call({ employee_rating: "meeting" }, described_class::ASSIGNMENT_EMPLOYEE)
      expect(out.keys).to contain_exactly(:employee_rating)
    end
  end

  describe ".for_assignment" do
    it "only coerces manager fields when view_mode is manager" do
      out = described_class.for_assignment(
        { employee_rating: "", manager_rating: "", manager_private_notes: "" },
        view_mode: :manager
      )
      expect(out[:employee_rating]).to eq("")
      expect(out[:manager_rating]).to be_nil
      expect(out[:manager_private_notes]).to be_nil
    end

    it "returns {} for blank attrs without inspecting view_mode" do
      expect(described_class.for_assignment({}, view_mode: :readonly)).to eq({})
    end

    it "raises when view_mode is unexpected and attrs are non-blank" do
      expect do
        described_class.for_assignment({ manager_rating: "" }, view_mode: :readonly)
      end.to raise_error(ArgumentError, /unexpected view_mode :readonly/)
    end
  end
end
