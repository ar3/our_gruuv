# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::GoalProgressStatusConfidenceRangeCalculator, type: :service do
  # Started 100 days ago, most_likely in 100 days (200-day total window). At "today" we're 50% through.
  let(:started_at) { 100.days.ago.to_date }
  let(:most_likely_target_date) { 100.days.from_now.to_date }
  let(:progress_check_date) { Date.current }

  describe '#call' do
    context 'when required args are nil' do
      it 'returns nil when most_likely_target_date is nil' do
        result = described_class.call(
          most_likely_target_date: nil,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        expect(result).to be_nil
      end

      it 'returns nil when started_at is nil' do
        result = described_class.call(
          most_likely_target_date: most_likely_target_date,
          started_at: nil,
          progress_check_date: progress_check_date
        )
        expect(result).to be_nil
      end

      it 'returns nil when progress_check_date is nil' do
        result = described_class.call(
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: nil
        )
        expect(result).to be_nil
      end
    end

    context 'with commit initial_confidence' do
      # commit: step 0.2, start 80. At 50% time elapsed: 80 + 50*0.2 = 90
      it 'returns three thresholds with commit config' do
        result = described_class.call(
          initial_confidence: :commit,
          earliest_target_date: most_likely_target_date - 20.days,
          latest_target_date: most_likely_target_date + 20.days,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(
          :behind_schedule_if_confidence_below,
          :ahead_of_schedule_if_confidence_above,
          :on_schedule_if_confidence_above
        )
        # All thresholds should be between 0 and 100
        result.each_value do |v|
          expect(v).to be >= 0
          expect(v).to be <= 100
        end
        # At 50% through most_likely: 80 + 50*0.2 = 90
        expect(result[:on_schedule_if_confidence_above]).to eq(90)
      end
    end

    context 'with stretch initial_confidence (default)' do
      it 'defaults initial_confidence to stretch when nil' do
        result = described_class.call(
          initial_confidence: nil,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        expect(result).to be_present
        # stretch: step 0.5, start 50. At 50%: 50 + 25 = 75
        expect(result[:on_schedule_if_confidence_above]).to eq(75)
      end

      it 'uses stretch config when initial_confidence is stretch' do
        result = described_class.call(
          initial_confidence: :stretch,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        expect(result[:on_schedule_if_confidence_above]).to eq(75)
      end
    end

    context 'with transform initial_confidence' do
      it 'uses transform config' do
        result = described_class.call(
          initial_confidence: :transform,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        # transform: step 0.8, start 20. At 50%: 20 + 40 = 60
        expect(result[:on_schedule_if_confidence_above]).to eq(60)
      end
    end

    context 'defaults for earliest and latest' do
      it 'defaults earliest_target_date and latest_target_date to most_likely_target_date' do
        result = described_class.call(
          initial_confidence: :stretch,
          earliest_target_date: nil,
          latest_target_date: nil,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: progress_check_date
        )
        expect(result).to be_present
        expect(result[:behind_schedule_if_confidence_below]).to eq(result[:on_schedule_if_confidence_above])
        expect(result[:ahead_of_schedule_if_confidence_above]).to eq(result[:on_schedule_if_confidence_above])
      end
    end

    context 'at start of period' do
      it 'returns start value when progress_check_date equals started_at' do
        result = described_class.call(
          initial_confidence: :stretch,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: started_at
        )
        # time_lapsed = 0, so threshold = 50 (stretch start)
        expect(result[:on_schedule_if_confidence_above]).to eq(50)
      end
    end

    context 'capping at 100' do
      it 'caps thresholds at 100' do
        # Check date far past target -> time_lapsed > 100% -> threshold could exceed 100
        far_future = most_likely_target_date + 1.year
        result = described_class.call(
          initial_confidence: :stretch,
          most_likely_target_date: most_likely_target_date,
          started_at: started_at,
          progress_check_date: far_future
        )
        result.each_value do |v|
          expect(v).to be <= 100
        end
      end
    end
  end
end
