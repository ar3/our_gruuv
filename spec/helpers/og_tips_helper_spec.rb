# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgTipsHelper, type: :helper do
  describe '#og_tip_position_assignment_energy_rating_body' do
    let(:summary) do
      instance_double(
        MyGrowth::ExperiencesSummary,
        show_inflight_viewer_rating_chart: show_inflight
      )
    end

    context 'when the in-flight chart is shown' do
      let(:show_inflight) { true }

      it 'references the in-flight chart and position form rating labels with color dots' do
        html = helper.og_tip_position_assignment_energy_rating_body(summary: summary)

        expect(html).to include('your in-flight check-in ratings chart')
        expect(html).to include('og-tip-rating-dot')
        expect(html).to include('background-color: #ffc107') # Working to Meet / Developing
        expect(html).to include('background-color: #198754') # Exceeding / Exceptional
        expect(html).to include('background-color: #0d6efd') # Accomplished
        expect(html).to include('background-color: #fd7e14') # Verbal Warning
        expect(html).to include('Developing')
        expect(html).to include('Verbal Warning')
        expect(html).to include('Written Warning')
        expect(html).to include('Performance Improvement Plan')
        expect(html).to include('Exceptional')
        expect(html).to include('Accomplished')
        expect(html).to match(/isn(?:'|&#39;)t an exact science/)
      end
    end

    context 'when only the finalized chart is available' do
      let(:show_inflight) { false }

      it 'references the latest finalized chart' do
        html = helper.og_tip_position_assignment_energy_rating_body(summary: summary)

        expect(html).to include('the latest finalized check-in ratings chart')
        expect(html).not_to include('in-flight check-in ratings chart')
      end
    end
  end
end
