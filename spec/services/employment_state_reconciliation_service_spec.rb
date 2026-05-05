require 'rails_helper'

RSpec.describe EmploymentStateReconciliationService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  it 'reports corrections for mismatched teammate state' do
    teammate = create(:company_teammate, organization: company, first_employed_at: 2.months.ago.to_date, last_terminated_at: Date.current)
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 1.month.ago, ended_at: nil)

    result = described_class.call

    expect(result.ok?).to be(true)
    expect(result.value[:corrected_teammates]).to be >= 1
    expect(result.value[:corrections].map { |c| c[:teammate_id] }).to include(teammate.id)
    expect(teammate.reload.last_terminated_at).to be_nil
  end

  it 'returns zero corrections when data is already consistent' do
    teammate = create(:company_teammate, organization: company, first_employed_at: 1.month.ago.to_date, last_terminated_at: nil)
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 1.month.ago, ended_at: nil)

    result = described_class.call

    expect(result.ok?).to be(true)
    expect(result.value[:corrected_teammates]).to eq(0)
  end
end
