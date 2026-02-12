require 'rails_helper'

RSpec.describe CompanyTeammate, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:position) { create(:position) }

  describe '#active_employment_tenure' do
    it 'returns the active employment tenure for the teammate' do
      active_tenure = create(:employment_tenure, company_teammate: teammate, company: company, ended_at: nil)
      expect(teammate.active_employment_tenure).to eq(active_tenure)
      
      # End the active tenure
      active_tenure.update!(ended_at: 1.day.ago)
      teammate.reload
      expect(teammate.active_employment_tenure).to be_nil
    end

    it 'returns nil when there is no active employment tenure' do
      expect(teammate.active_employment_tenure).to be_nil
    end

    it 'only returns tenures for the teammate\'s organization' do
      other_company = create(:organization, :company)
      other_person = create(:person)
      other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
      
      active_tenure_for_company = create(:employment_tenure, company_teammate: teammate, company: company, ended_at: nil)
      active_tenure_for_other = create(:employment_tenure, company_teammate: other_teammate, company: other_company, ended_at: nil)

      expect(teammate.active_employment_tenure).to eq(active_tenure_for_company)
      expect(teammate.active_employment_tenure).not_to eq(active_tenure_for_other)
    end

    it 'returns nil when teammate has active tenure for different company' do
      other_company = create(:organization, :company)
      create(:employment_tenure, company_teammate: teammate, company: other_company, ended_at: nil)

      expect(teammate.active_employment_tenure).to be_nil
    end
  end

  describe '.self_and_reporting_hierarchy' do
    let(:company) { create(:organization, :company) }
    let(:manager_person) { create(:person) }
    let(:report_person) { create(:person) }
    let(:report2_person) { create(:person) }
    let(:manager_teammate) do
      create(:teammate, person: manager_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
    end
    let(:report_teammate) do
      create(:teammate, person: report_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
    end
    let(:report2_teammate) do
      create(:teammate, person: report2_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
    end

    before do
      manager_teammate
      report_teammate
      report2_teammate
      create(:employment_tenure, company: company, company_teammate: report_teammate, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
      create(:employment_tenure, company: company, company_teammate: report2_teammate, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
    end

    it 'returns the teammate and all direct and indirect reports within the organization' do
      result = described_class.self_and_reporting_hierarchy(manager_teammate, company)
      ids = result.pluck(:id)
      expect(ids).to contain_exactly(manager_teammate.id, report_teammate.id, report2_teammate.id)
    end

    it 'returns only the given teammate when they have no reports' do
      result = described_class.self_and_reporting_hierarchy(report_teammate, company)
      expect(result.pluck(:id)).to eq([report_teammate.id])
    end

    it 'returns none when teammate is nil' do
      expect(described_class.self_and_reporting_hierarchy(nil, company)).to eq(described_class.none)
    end

    it 'returns none when organization is nil' do
      expect(described_class.self_and_reporting_hierarchy(manager_teammate, nil)).to eq(described_class.none)
    end

    it 'excludes teammates outside the organization hierarchy' do
      other_company = create(:organization, :company)
      other_teammate = create(:teammate, person: create(:person), organization: other_company, first_employed_at: 1.month.ago, last_terminated_at: nil)
      create(:employment_tenure, company: other_company, company_teammate: other_teammate, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
      result = described_class.self_and_reporting_hierarchy(manager_teammate, company)
      expect(result.pluck(:id)).not_to include(other_teammate.id)
      expect(result.pluck(:id)).to contain_exactly(manager_teammate.id, report_teammate.id, report2_teammate.id)
    end
  end
end

