# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInsHealthCsvBuilder do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
  let(:teammate) do
    create(:company_teammate, :unassigned_employee, person: person, organization: company)
  end

  before do
    teammate
  end

  describe '#call' do
    it 'returns a CSV string with headers' do
      csv = described_class.new(company, [teammate]).call
      parsed = CSV.parse(csv, headers: true)
      expect(parsed.headers).to include(
        'Teammate Name',
        'Teammate Email',
        'Teammate Manager Name',
        'Teammate Manager Email',
        'Check-in Object',
        'Check-in Started',
        'Check-in Finalized',
        'Check-ins Finalized Before this',
        'Expected Energy Percentage',
        'Actual Energy Percentage',
        'Employee Personal Alignment'
      )
    end

    it 'includes Expected Energy Percentage in headers' do
      csv = described_class.new(company, [teammate]).call
      expect(csv).to include('Expected Energy Percentage')
    end

    context 'with no teammates' do
      it 'returns CSV with headers only' do
        csv = described_class.new(company, []).call
        parsed = CSV.parse(csv, headers: true)
        expect(parsed.headers).to be_present
        expect(parsed.size).to eq(0)
      end
    end

    context 'with a position check-in' do
      let!(:employment_tenure) do
        create(:employment_tenure, company_teammate: teammate, company: company)
      end
      let!(:position_check_in) do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
      end

      it 'includes one row for the position check-in' do
        csv = described_class.new(company, [teammate]).call
        parsed = CSV.parse(csv, headers: true)
        position_rows = parsed.select { |row| row['Check-in Object'].present? && row['Check-in Object'] != '' }
        expect(position_rows.size).to be >= 1
        row = position_rows.find { |r| r['Teammate Name'] == person.display_name }
        expect(row).to be_present
        expect(row['Teammate Email']).to eq(person.email)
        expect(row['Expected Energy Percentage']).to eq('')
        expect(row['Actual Energy Percentage']).to eq('')
      end
    end

    context 'with an assignment check-in and assignment tenure' do
      let(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
      let!(:assignment_tenure) do
        create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 75)
      end
      let!(:assignment_check_in) do
        create(:assignment_check_in, teammate: teammate, assignment: assignment, actual_energy_percentage: 60)
      end

      it 'includes assignment row with Expected Energy Percentage from tenure' do
        csv = described_class.new(company, [teammate]).call
        parsed = CSV.parse(csv, headers: true)
        assignment_rows = parsed.select { |row| row['Check-in Object'].to_s.include?('Test Assignment') }
        expect(assignment_rows.size).to be >= 1
        row = assignment_rows.first
        expect(row['Expected Energy Percentage']).to eq('75')
        expect(row['Actual Energy Percentage']).to eq('60')
      end
    end

    context 'with an aspiration check-in' do
      let(:aspiration) { create(:aspiration, company: company, name: 'Test Aspiration') }
      let!(:aspiration_check_in) do
        create(:aspiration_check_in, teammate: teammate, aspiration: aspiration)
      end

      it 'includes aspiration row with blank expected/actual energy' do
        csv = described_class.new(company, [teammate]).call
        parsed = CSV.parse(csv, headers: true)
        aspiration_rows = parsed.select { |row| row['Check-in Object'] == 'Test Aspiration' }
        expect(aspiration_rows.size).to be >= 1
        row = aspiration_rows.first
        expect(row['Expected Energy Percentage']).to eq('')
        expect(row['Actual Energy Percentage']).to eq('')
      end
    end
  end
end
