# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListPagination do
  describe ".normalize" do
    it "clamps limit and floors offset" do
      expect(described_class.normalize(limit: 100, offset: -3)).to eq(limit: 50, offset: 0)
      expect(described_class.normalize(limit: nil, offset: 10)).to eq(limit: 25, offset: 10)
    end
  end

  describe ".slice" do
    let(:records) { (1..7).to_a }

    it "returns page meta with next_offset when more remain" do
      page = described_class.slice(records, limit: 3, offset: 0)
      expect(page[:items]).to eq([1, 2, 3])
      expect(page[:meta]).to include(
        count: 3,
        limit: 3,
        offset: 0,
        total_count: 7,
        has_more: true,
        next_offset: 3
      )
    end

    it "returns nil next_offset on the last page" do
      page = described_class.slice(records, limit: 3, offset: 6)
      expect(page[:items]).to eq([7])
      expect(page[:meta]).to include(has_more: false, next_offset: nil, total_count: 7)
    end
  end
end
