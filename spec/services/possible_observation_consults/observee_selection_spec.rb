# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::ObserveeSelection do
  describe ".resolve" do
    it "keeps the multi set when select is multi" do
      expect(described_class.resolve(select_value: "multi", multi_ids: [10, 20])).to eq(
        primary: 10, ids: [10, 20]
      )
    end

    it "clears people for team/blank" do
      expect(described_class.resolve(select_value: "", multi_ids: [10, 20])).to eq(
        primary: nil, ids: []
      )
    end

    it "collapses to one person when a teammate is chosen" do
      expect(described_class.resolve(select_value: "20", multi_ids: [10, 20])).to eq(
        primary: 20, ids: [20]
      )
    end
  end

  describe ".select_value" do
    it "returns multi when more than one id" do
      expect(described_class.select_value([1, 2])).to eq("multi")
    end
  end

  describe ".ready_for_promote?" do
    it "only requires an observer" do
      expect(described_class.ready_for_promote?(observer_id: 1)).to be(true)
      expect(described_class.ready_for_promote?(observer_id: nil)).to be(false)
      expect(described_class.ready_for_promote?(observer_id: "")).to be(false)
    end
  end
end
