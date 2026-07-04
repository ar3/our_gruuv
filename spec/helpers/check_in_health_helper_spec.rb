# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe '#check_in_health_clarity_popover_caption' do
    it 'describes Gruuv Health workflow columns' do
      text = helper.check_in_health_clarity_popover_caption
      expect(text).to include(EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s)
      expect(text).to include('Healthy Gruuv Health status')
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

  describe 'required-check-in helpers' do
    let(:required_payload) do
      {
        'position' => [ { 'type' => 'position', 'item_id' => 1, 'name' => 'Support Lead', 'clarity_level' => 'clear', 'latest_finalized_rating' => 'meeting' } ],
        'assignments' => [ { 'type' => 'assignment', 'item_id' => 2, 'name' => 'Onboarding', 'clarity_level' => 'obscured', 'latest_finalized_rating' => 'working_to_meet' } ],
        'aspirations' => [ { 'type' => 'aspiration', 'item_id' => 3, 'name' => 'Ownership', 'clarity_level' => 'blurred', 'latest_finalized_rating' => 'meeting' } ]
      }
    end

    let(:cache) do
      instance_double(CheckInHealthCache, payload_required_check_ins: required_payload)
    end

    it 'builds required clarity counts' do
      counts = helper.required_check_in_category_counts(required_payload['assignments'] + required_payload['aspirations'])
      expect(counts['obscured']).to eq(1)
      expect(counts['blurred']).to eq(1)
      expect(counts['clear']).to eq(0)
      expect(counts['crystal_clear']).to eq(0)
    end

    it 'prioritizes obscured items first for urgency' do
      urgent = helper.required_check_ins_most_urgent(cache)
      expect(urgent['type']).to eq('assignment')
      expect(urgent['name']).to eq('Onboarding')
    end

    it 'returns alert data with item link when not all clear' do
      organization = create(:organization, :company)
      teammate = create(:teammate, organization: organization)
      allow(helper).to receive(:organization_teammate_assignment_path).and_return('/assignment_path')

      alert_data = helper.required_check_in_alert_data(cache: cache, organization: organization, teammate: teammate)
      expect(alert_data[:all_clear]).to be(false)
      expect(alert_data[:url]).to eq('/assignment_path')
      expect(alert_data[:message]).to include('Consider checking in on:')
    end
  end
end
