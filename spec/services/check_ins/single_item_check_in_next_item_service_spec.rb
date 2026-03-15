# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SingleItemCheckInNextItemService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:current_person) { teammate.person }

  describe ".call" do
    it "returns a hash with next_url, next_requires_check_in, next_item, ordered_items" do
      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )
      expect(result).to include(:next_url, :next_requires_check_in, :next_item, :ordered_items)
      expect(result[:ordered_items]).to be_an(Array)
    end

    context "with no employment" do
      it "still returns structure with empty or position-only items" do
        result = described_class.call(
          teammate: teammate,
          organization: organization,
          current_person: current_person,
          current_type: :aspiration,
          current_id: 0
        )
        expect(result[:next_requires_check_in]).to be_in([true, false])
      end
    end
  end
end
