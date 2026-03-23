# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInsHealthEmployeeSummaryCsvBuilder do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
  let(:teammate) do
    create(:company_teammate, :unassigned_employee, person: person, organization: company)
  end

  describe '#call' do
    it 'returns a CSV string with employee summary headers' do
      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)

      expect(parsed.headers).to include(
        'Name',
        'Email',
        'Position',
        'Title',
        'Department',
        'Manager Name',
        'Manager Email',
        'Total Percentage Clear',
        'Aspirational Values Total Percentage Clear',
        'Required Assignments Total Percentage Clear',
        'Position Total Percentage Clear'
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

    it 'computes percentages from cache payload timestamps' do
      create(:check_in_health_cache, teammate: teammate, organization: company, payload: {
               'position' => {
                 'category' => 'green',
                 'employee_completed_at' => 30.days.ago.iso8601,
                 'manager_completed_at' => 20.days.ago.iso8601,
                 'official_check_in_completed_at' => 10.days.ago.iso8601,
                 'acknowledged_at' => 5.days.ago.iso8601
               },
               'assignments' => [
                 {
                   'item_id' => 1,
                   'category' => 'green',
                   'employee_completed_at' => 10.days.ago.iso8601,
                   'manager_completed_at' => 10.days.ago.iso8601,
                   'official_check_in_completed_at' => 10.days.ago.iso8601,
                   'acknowledged_at' => 10.days.ago.iso8601
                 },
                 {
                   'item_id' => 2,
                   'category' => 'red',
                   'employee_completed_at' => nil,
                   'manager_completed_at' => nil,
                   'official_check_in_completed_at' => nil,
                   'acknowledged_at' => nil
                 }
               ],
               'aspirations' => [
                 {
                   'item_id' => 11,
                   'category' => 'green',
                   'employee_completed_at' => 20.days.ago.iso8601,
                   'manager_completed_at' => 20.days.ago.iso8601,
                   'official_check_in_completed_at' => 20.days.ago.iso8601,
                   'acknowledged_at' => 20.days.ago.iso8601
                 }
               ],
               'milestones' => { 'total_required' => 0, 'earned_count' => 0 }
             })

      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)
      row = parsed.first

      expect(row['Aspirational Values Employee Checked-in Within 90 Days Percentage']).to eq('100.0%')
      expect(row['Required Assignments Employee Checked-in Within 90 Days Percentage']).to eq('50.0%')
      expect(row['Position Employee Checked-in Within 90 Days Percentage']).to eq('100.0%')
      expect(row['Position Acknowledged Checked-in Within 60 Days Percentage']).to eq('100.0%')
    end
  end
end
