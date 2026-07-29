# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::PositionChangeEligibilityPayloadBuilder do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  it 'builds a payload with context and relevance sections' do
    built = described_class.call(
      teammate: teammate,
      position: position,
      organization: organization
    )

    expect(built.change_type).to eq('title_change')
    expect(built.units_total).to eq(1)
    titles = built.payload['sections'].map { |s| s['title'] }
    expect(titles).to include('Context')
    expect(titles).to include('Shared-visible observations (past year)')
    expect(built.payload['sections'].find { |s| s['title'] == 'Context' }['body']['Check-in carry-forward rule']).to be_present
  end

  it 'carries a finalized check-in rating forward until the next one' do
    assignment = create(:assignment, company: organization)
    create(
      :assignment_check_in,
      :officially_completed,
      teammate: teammate,
      assignment: assignment,
      check_in_started_on: 6.months.ago.to_date,
      official_rating: 'meeting',
      official_check_in_completed_at: 6.months.ago
    )

    built = described_class.call(
      teammate: teammate,
      position: position,
      organization: organization
    )
    section = built.payload['sections'].find { |s| s['title'].include?('Assignment check-ins') }
    periods = section['body']['Subjects'].first['Rating periods in evidence window']
    expect(periods.first['Official rating']).to eq('meeting')
    expect(periods.first['Months at this official rating (carry-forward)']).to be >= 6
  end
end
