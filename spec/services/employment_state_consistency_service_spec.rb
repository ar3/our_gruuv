require 'rails_helper'

RSpec.describe EmploymentStateConsistencyService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company, first_employed_at: nil, last_terminated_at: nil) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  it 'sets last_terminated_at to nil when active tenure exists' do
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 1.month.ago, ended_at: nil)
    teammate.update!(first_employed_at: 2.months.ago.to_date, last_terminated_at: Date.current)

    result = described_class.call(teammate: teammate)

    expect(result.ok?).to be(true)
    expect(result.value[:changed_fields]).to include(:last_terminated_at)
    expect(teammate.reload.last_terminated_at).to be_nil
  end

  it 'sets last_terminated_at from latest ended tenure when no active tenure exists' do
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 3.months.ago, ended_at: 2.months.ago)
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 2.months.ago, ended_at: 1.month.ago)

    result = described_class.call(teammate: teammate)

    expect(result.ok?).to be(true)
    expect(teammate.reload.last_terminated_at).to eq(1.month.ago.to_date)
  end

  it 'backfills first_employed_at from earliest tenure when missing' do
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 4.months.ago, ended_at: 3.months.ago)
    create(:employment_tenure, teammate: teammate, company: company, position: position, started_at: 2.months.ago, ended_at: nil)

    result = described_class.call(teammate: teammate)

    expect(result.ok?).to be(true)
    expect(teammate.reload.first_employed_at).to eq(4.months.ago.to_date)
  end

  it 'is a no-op when teammate has no tenures' do
    teammate.update!(first_employed_at: 1.month.ago.to_date, last_terminated_at: Date.current)

    result = described_class.call(teammate: teammate)

    expect(result.ok?).to be(true)
    expect(result.value[:changed_fields]).to eq([])
    expect(teammate.reload.last_terminated_at).to eq(Date.current)
  end
end
