# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::TeammateFilter do
  let(:company) { create(:company) }
  let(:department) { create(:department, company: company, name: 'Engineering') }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: company, department: department, position_major_level: position_major_level, external_title: 'Engineering Title') }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager_person) { create(:person) }
  let(:manager) do
    create(:teammate, organization: company, person: manager_person, first_employed_at: 2.years.ago, last_terminated_at: nil)
  end
  let(:report_person) { create(:person) }
  let(:report) do
    create(:teammate, organization: company, person: report_person, first_employed_at: 1.year.ago, last_terminated_at: nil)
  end
  let(:other_person) { create(:person) }
  let(:other_teammate) do
    create(:teammate, organization: company, person: other_person, first_employed_at: 1.year.ago, last_terminated_at: nil)
  end

  before do
    EmploymentTenure.create!(
      teammate: report,
      company: company,
      position: position,
      manager_teammate: manager,
      started_at: 1.year.ago,
      ended_at: nil
    )
    EmploymentTenure.create!(
      teammate: other_teammate,
      company: company,
      position: position,
      manager_teammate: nil,
      started_at: 1.year.ago,
      ended_at: nil
    )
  end

  describe '.call' do
    it 'returns nil when no filters are selected' do
      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [],
        manager_ids: []
      )
      expect(result).to be_nil
    end

    it 'returns nil when only everyone is selected for manager' do
      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [],
        manager_ids: ['everyone']
      )
      expect(result).to be_nil
    end

    it 'filters by department from position title' do
      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [department.id],
        manager_ids: []
      )
      expect(result).to contain_exactly(report.id, other_teammate.id)
    end

    it 'filters by direct reports of a named manager' do
      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [],
        manager_ids: ["CompanyTeammate_#{manager.id}"]
      )
      expect(result).to contain_exactly(report.id)
    end

    it 'intersects department and manager filters' do
      other_department = create(:department, company: company, name: 'Sales')
      other_title = create(:title, company: company, department: other_department, position_major_level: position_major_level, external_title: 'Sales Title')
      other_position = create(:position, title: other_title, position_level: position_level)
      sales_report = create(:teammate, organization: company, first_employed_at: 1.year.ago, last_terminated_at: nil)
      EmploymentTenure.create!(
        teammate: sales_report,
        company: company,
        position: other_position,
        manager_teammate: manager,
        started_at: 1.year.ago,
        ended_at: nil
      )

      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [department.id],
        manager_ids: ["CompanyTeammate_#{manager.id}"]
      )
      expect(result).to contain_exactly(report.id)
    end

    it 'unions multiple manager selections' do
      second_manager = create(:teammate, organization: company, first_employed_at: 2.years.ago, last_terminated_at: nil)
      second_report = create(:teammate, organization: company, first_employed_at: 1.year.ago, last_terminated_at: nil)
      EmploymentTenure.create!(
        teammate: second_report,
        company: company,
        position: position,
        manager_teammate: second_manager,
        started_at: 1.year.ago,
        ended_at: nil
      )

      result = described_class.call(
        company: company,
        current_company_teammate: manager,
        department_ids: [],
        manager_ids: ["CompanyTeammate_#{manager.id}", "CompanyTeammate_#{second_manager.id}"]
      )
      expect(result).to contain_exactly(report.id, second_report.id)
    end
  end
end
