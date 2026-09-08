# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmploymentTenures::CorrectHistoryService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company, first_employed_at: 1.year.ago.to_date) }
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

  describe '.update_tenure' do
    it 'updates dates/manager/position silently and trims overlapping neighbors' do
      earlier = create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_a,
        started_at: Date.new(2022, 1, 1),
        ended_at: Date.new(2023, 1, 1)
      )
      later = create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_b,
        started_at: Date.new(2023, 1, 1),
        ended_at: nil
      )

      result = described_class.update_tenure(
        teammate: teammate,
        tenure: later,
        attrs: {
          position_id: position_b.id,
          manager_teammate_id: nil,
          started_at: Date.new(2022, 6, 1),
          ended_at: nil
        }
      )

      expect(result.ok?).to be(true)
      expect(later.reload.started_at.to_date).to eq(Date.new(2022, 6, 1))
      expect(earlier.reload.ended_at.to_date).to eq(Date.new(2022, 6, 1))
      expect(result.value[:adjustments].join).to include('end date')
      expect(ObservableMoment.count).to eq(0)
    end

    it 'forces first_employed_at to the earliest tenure start' do
      tenure = create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_a,
        started_at: Date.new(2020, 1, 1),
        ended_at: nil
      )
      teammate.update!(first_employed_at: Date.new(2024, 1, 1))

      result = described_class.update_tenure(
        teammate: teammate,
        tenure: tenure,
        attrs: {
          position_id: position_a.id,
          started_at: Date.new(2019, 6, 1),
          ended_at: nil
        }
      )

      expect(result.ok?).to be(true)
      expect(teammate.reload.first_employed_at).to eq(Date.new(2019, 6, 1))
    end
  end

  describe '.prepend' do
    it 'adds an earliest tenure before the current first' do
      create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_b,
        started_at: Date.new(2023, 1, 1),
        ended_at: nil
      )

      result = described_class.prepend(
        teammate: teammate,
        attrs: {
          position_id: position_a.id,
          started_at: Date.new(2021, 1, 1),
          ended_at: Date.new(2023, 1, 1)
        }
      )

      expect(result.ok?).to be(true)
      expect(teammate.employment_tenures.count).to eq(2)
      expect(teammate.reload.first_employed_at).to eq(Date.new(2021, 1, 1))
    end
  end

  describe '.connect_gap' do
    it 'sets earlier ended_at to later started_at' do
      earlier = create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_a,
        started_at: Date.new(2020, 1, 1),
        ended_at: Date.new(2021, 1, 1)
      )
      later = create(
        :employment_tenure,
        teammate: teammate,
        company: company,
        position: position_b,
        started_at: Date.new(2022, 1, 1),
        ended_at: nil
      )

      result = described_class.connect_gap(
        teammate: teammate,
        earlier_tenure: earlier,
        later_tenure: later
      )

      expect(result.ok?).to be(true)
      expect(earlier.reload.ended_at.to_date).to eq(Date.new(2022, 1, 1))
    end
  end
end
