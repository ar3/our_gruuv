# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInsHealthEmployeeSummaryCsvBuilder do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
  let(:teammate) do
    create(:company_teammate, :unassigned_employee, person: person, organization: company)
  end

  describe '#call' do
    it 'returns a CSV string with Gruuv Health summary headers' do
      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)

      expect(parsed.headers).to include(
        'Name',
        'Email',
        'Total Percentage Healthy',
        'Aspirations Percentage Healthy',
        'Assignments Percentage Healthy',
        'Position Percentage Healthy'
      )
    end

    it 'includes a row per employee' do
      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)

      expect(parsed.size).to eq(1)
      row = parsed.first
      expect(row['Name']).to eq(person.display_name)
      expect(row['Email']).to eq(person.email)
    end

    it 'computes percentages from engagement health statuses' do
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: 'item',
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: 'Position',
        entity_id: 1,
        status: EngagementHealth::HEALTHY,
        inputs: { 'name' => 'Engineer' },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: 'item',
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: 'Assignment',
        entity_id: 2,
        status: EngagementHealth::AT_RISK,
        inputs: { 'name' => 'Support' },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: 'item',
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: 'Aspiration',
        entity_id: 3,
        status: EngagementHealth::HEALTHY,
        inputs: { 'name' => 'Growth' },
        computed_at: Time.current
      )

      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)
      row = parsed.first

      expect(row['Total Percentage Healthy']).to eq('66.7%')
      expect(row['Aspirations Percentage Healthy']).to eq('100.0%')
      expect(row['Assignments Percentage Healthy']).to eq('0.0%')
      expect(row['Assignments Percentage At Risk']).to eq('100.0%')
      expect(row['Position Percentage Healthy']).to eq('100.0%')
    end
  end
end
