# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgTipsHelper, type: :helper do
  describe '#og_tip_position_assignment_energy_rating_body' do
    let(:organization) { create(:organization, :company) }
    let(:manager_person) { create(:person, first_name: 'Morgan', last_name: 'Lee') }
    let(:manager) { create(:company_teammate, :assigned_employee, person: manager_person, organization: organization) }
    let(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
    let(:summary) do
      instance_double(
        MyGrowth::ExperiencesSummary,
        show_inflight_rating_chart: show_inflight,
        guidance_position_rating: guidance_rating,
        guidance_rating_energy_buckets: buckets
      )
    end
    let(:guidance_rating) { 2 }
    let(:buckets) do
      {
        'working_to_meet' => 10,
        'meeting' => 40,
        'exceeding' => 50,
        'no_check_in' => 0
      }
    end

    before do
      create(:employment_tenure, company_teammate: teammate, company: organization, manager_teammate: manager)
    end

    context 'when the in-flight chart is shown' do
      let(:show_inflight) { true }

      it 'references the in-flight chart and position form rating labels with color dots' do
        html = helper.og_tip_position_assignment_energy_rating_body(summary: summary, teammate: teammate)

        expect(html).to include('the latest in-flight ratings chart')
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
        expect(html).to include('OG will never make a recommendation on how to rate a teammate')
        expect(html).to include(manager_person.casual_name)
        expect(html).to include('50% Exceeding')
        expect(html).to include('40% Meeting')
        expect(html).to include('10% Working to Meet')
        expect(html).to include('non-OG aware and values-based concerns')
      end
    end

    context 'when only the finalized chart is available' do
      let(:show_inflight) { false }

      it 'references the finalized chart' do
        html = helper.og_tip_position_assignment_energy_rating_body(summary: summary, teammate: teammate)

        expect(html).to include('the finalized (official) ratings chart')
        expect(html).not_to include('in-flight ratings chart')
      end
    end

    context 'when guidance is not computable' do
      let(:show_inflight) { true }
      let(:guidance_rating) { nil }

      it 'omits the personalized algorithm sentence' do
        html = helper.og_tip_position_assignment_energy_rating_body(summary: summary, teammate: teammate)

        expect(html).to match(/isn(?:'|&#39;)t an exact science/)
        expect(html).not_to include('OG will never make a recommendation')
      end
    end
  end
end
