# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe '#check_in_health_clarity_popover_caption' do
    it 'includes clear and blurred day counts from CheckInBehavior' do
      text = helper.check_in_health_clarity_popover_caption
      expect(text).to include(CheckInBehavior::CLARITY_CLEAR_DAYS.to_s)
      expect(text).to include(CheckInBehavior::CLARITY_BLURRED_DAYS.to_s)
      expect(text).to include('overall clarity percentage')
    end
  end

  describe '#single_item_health_popover_table' do
    let(:assignments_payload) { [] }
    let(:aspirations_payload) { [] }
    let(:cache) do
      instance_double(
        CheckInHealthCache,
        payload_position: position_payload,
        payload_assignments: assignments_payload,
        payload_aspirations: aspirations_payload
      )
    end

    it 'returns nil when cache is nil' do
      expect(helper.single_item_health_popover_table(nil)).to be_nil
    end

    context 'when position employee completion is within the clear window' do
      around { |example| travel_to(Time.zone.parse('2026-06-15 12:00:00'), &example) }

      let(:position_payload) do
        {
          'employee_completed_at' => (CheckInBehavior::CLARITY_CLEAR_DAYS - 5).days.ago.iso8601,
          'manager_completed_at' => nil,
          'official_check_in_completed_at' => nil
        }
      end

      it 'counts employee position cell as 100%' do
        table = helper.single_item_health_popover_table(cache)
        expect(table[:position][:employee]).to eq(100)
        expect(table[:position][:manager]).to eq(0)
      end
    end

    context 'when position employee completion is outside the clear window' do
      around { |example| travel_to(Time.zone.parse('2026-06-15 12:00:00'), &example) }

      let(:position_payload) do
        {
          'employee_completed_at' => (CheckInBehavior::CLARITY_CLEAR_DAYS + 5).days.ago.iso8601,
          'manager_completed_at' => nil,
          'official_check_in_completed_at' => nil
        }
      end

      it 'counts employee position cell as 0%' do
        table = helper.single_item_health_popover_table(cache)
        expect(table[:position][:employee]).to eq(0)
      end
    end

    context 'with two assignments, one employee side inside clear window and one outside' do
      around { |example| travel_to(Time.zone.parse('2026-06-15 12:00:00'), &example) }

      let(:position_payload) { {} }
      let(:assignments_payload) do
        inside = (CheckInBehavior::CLARITY_CLEAR_DAYS - 1).days.ago.iso8601
        outside = (CheckInBehavior::CLARITY_CLEAR_DAYS + 1).days.ago.iso8601
        [
          { 'employee_completed_at' => inside, 'manager_completed_at' => nil, 'official_check_in_completed_at' => nil },
          { 'employee_completed_at' => outside, 'manager_completed_at' => nil, 'official_check_in_completed_at' => nil }
        ]
      end

      it 'averages employee column at 50%' do
        table = helper.single_item_health_popover_table(cache)
        expect(table[:assignments][:employee]).to eq(50)
      end
    end
  end
end
