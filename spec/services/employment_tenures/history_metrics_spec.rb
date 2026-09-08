# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmploymentTenures::HistoryMetrics, type: :service do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }
  let(:position_a) do
    pml = create(:position_major_level)
    title = create(:title, company: company, position_major_level: pml)
    level = create(:position_level, position_major_level: pml)
    create(:position, title: title, position_level: level)
  end
  let(:position_b) do
    pml = create(:position_major_level)
    title = create(:title, company: company, position_major_level: pml)
    level = create(:position_level, position_major_level: pml)
    create(:position, title: title, position_level: level)
  end
  let(:manager) { create(:company_teammate, organization: company) }
  let(:other_manager) { create(:company_teammate, organization: company) }

  it 'computes promotion, changes, stretches, and boomerangs' do
    first = build(
      :employment_tenure,
      teammate: teammate,
      company: company,
      position: position_a,
      manager_teammate: manager,
      started_at: Time.zone.parse('2020-01-01'),
      ended_at: Time.zone.parse('2021-01-01')
    )
    first.save!
    # gap (boomerang) between first and second
    second = build(
      :employment_tenure,
      teammate: teammate,
      company: company,
      position: position_a,
      manager_teammate: manager,
      started_at: Time.zone.parse('2022-01-01'),
      ended_at: Time.zone.parse('2023-01-01')
    )
    second.save!
    third = build(
      :employment_tenure,
      teammate: teammate,
      company: company,
      position: position_b,
      manager_teammate: other_manager,
      started_at: Time.zone.parse('2023-01-01'),
      ended_at: nil
    )
    third.save!

    # Factory after(:build) may replace position — pin the intended ones.
    first.update_columns(position_id: position_a.id, manager_teammate_id: manager.id)
    second.update_columns(position_id: position_a.id, manager_teammate_id: manager.id)
    third.update_columns(position_id: position_b.id, manager_teammate_id: other_manager.id)

    metrics = described_class.call(tenures: [first.reload, second.reload, third.reload])

    expect(metrics[:boomerang_count]).to eq(1)
    expect(metrics[:consecutive_stretches].size).to eq(2)
    expect(metrics[:position_change_count]).to eq(1)
    expect(metrics[:managerial_change_count]).to eq(1)
    expect(metrics[:last_promotion_at].to_date).to eq(Date.new(2023, 1, 1))
    expect(metrics[:gaps].size).to eq(1)
    expect(metrics[:total_employed_seconds]).to be > 0
  end
end
