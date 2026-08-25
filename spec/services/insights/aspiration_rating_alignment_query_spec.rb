# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::AspirationRatingAlignmentQuery do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:aspiration) { create(:aspiration, company: company, name: 'Integrity') }

  before do
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
  end

  it 'places a teammate\'s last finalized aspiration check-in into the agreement grid' do
    create(
      :aspiration_check_in,
      :finalized,
      teammate: ic,
      aspiration: aspiration,
      employee_rating: 'meeting',
      manager_rating: 'meeting',
      official_rating: 'exceeding'
    )

    query = described_class.new(teammates: [ic], aspirations: [aspiration])
    expect(query.aspirations.map(&:id)).to eq([aspiration.id])
    points = query.cell(aspiration, :emp_mgr_same_final_differed)
    expect(points.map { |point| point.teammate.id }).to eq([ic.id])
    expect(points.first.arrow).to eq(:better)
  end
end
