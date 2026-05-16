# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::CellStatus do
  describe '.for' do
    context 'when thresholds are not configured' do
      it 'returns neutral' do
        expect(described_class.for(
                 value: 5, yellow: nil, green: 10, direction: :more,
                 mode: 'absolute', active_teammate_count: 100
               )).to eq(:neutral)
      end
    end

    context 'more is better (absolute)' do
      let(:opts) { { yellow: 3, green: 8, direction: :more, mode: 'absolute', active_teammate_count: 100 } }

      it 'returns success at or above green' do
        expect(described_class.for(value: 8, **opts)).to eq(:success)
        expect(described_class.for(value: 10, **opts)).to eq(:success)
      end

      it 'returns warning between yellow and green' do
        expect(described_class.for(value: 5, **opts)).to eq(:warning)
      end

      it 'returns danger below yellow' do
        expect(described_class.for(value: 2, **opts)).to eq(:danger)
      end
    end

    context 'less is better (absolute)' do
      let(:opts) { { yellow: 10, green: 3, direction: :less, mode: 'absolute', active_teammate_count: 100 } }

      it 'returns success at or below green' do
        expect(described_class.for(value: 3, **opts)).to eq(:success)
      end

      it 'returns danger above yellow' do
        expect(described_class.for(value: 11, **opts)).to eq(:danger)
      end
    end

    context 'percent mode' do
      it 'compares percentage of active teammates' do
        status = described_class.for(
          value: 25,
          yellow: 20,
          green: 30,
          direction: :more,
          mode: 'percent',
          active_teammate_count: 100
        )
        expect(status).to eq(:warning)
      end

      it 'returns neutral when active teammate count is zero' do
        status = described_class.for(
          value: 0,
          yellow: 20,
          green: 30,
          direction: :more,
          mode: 'percent',
          active_teammate_count: 0
        )
        expect(status).to eq(:neutral)
      end
    end
  end
end
