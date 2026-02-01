require 'rails_helper'

RSpec.describe EmployeeHierarchyQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: company) }
  
  let(:direct_report) { create(:person) }
  let(:direct_report_teammate) { CompanyTeammate.create!(person: direct_report, organization: company) }
  
  let(:grand_report) { create(:person) }
  let(:grand_report_teammate) { CompanyTeammate.create!(person: grand_report, organization: company) }

  describe '#initialize' do
    it 'accepts person and organization' do
      query = described_class.new(person: person, organization: company)
      expect(query).to be_a(EmployeeHierarchyQuery)
    end
  end

  describe '#call' do
    context 'when person or organization is nil' do
      it 'returns empty array when person is nil' do
        query = described_class.new(person: nil, organization: company)
        expect(query.call).to eq([])
      end

      it 'returns empty array when organization is nil' do
        query = described_class.new(person: person, organization: nil)
        expect(query.call).to eq([])
      end
    end

    context 'when person has no direct reports' do
      it 'returns empty array' do
        # Create employment tenure for person without managing anyone
        create(:employment_tenure, teammate: person_teammate, company: company, manager_teammate: nil)
        
        query = described_class.new(person: person, organization: company)
        expect(query.call).to eq([])
      end
    end

    context 'when person has a direct report' do
      let!(:employment_tenure) { create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate) }

      it 'returns the direct report' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(1)
        expect(results.first[:person_id]).to eq(direct_report.id)
        expect(results.first[:name]).to eq(direct_report.display_name)
        expect(results.first[:email]).to eq(direct_report.email)
        expect(results.first[:level]).to eq(0)
      end

      it 'includes position information' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: company, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        # Update the existing tenure's position
        employment_tenure.update!(position: position)
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.first[:position]).to be_present
        expect(results.first[:position]).to eq(position.display_name)
      end
    end

    context 'when person has multiple direct reports' do
      let(:report2) { create(:person) }
      let(:report2_teammate) { create(:teammate, person: report2, organization: company) }

      before do
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        create(:employment_tenure, teammate: report2_teammate, company: company, manager_teammate: person_teammate)
      end

      it 'returns all direct reports' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(2)
        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(direct_report.id, report2.id)
      end

      it 'only includes active employment tenures' do
        inactive_report = create(:person)
        inactive_report_teammate = create(:teammate, person: inactive_report, organization: company)
        create(:employment_tenure, teammate: inactive_report_teammate, company: company, manager_teammate: person_teammate, ended_at: 1.week.ago)
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).not_to include(inactive_report.id)
      end
    end

    context 'when direct report has reports (grand reports)' do
      before do
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        create(:employment_tenure, teammate: grand_report_teammate, company: company, manager_teammate: direct_report_teammate)
      end

      it 'returns both direct report and grand report' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(2)
        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(direct_report.id, grand_report.id)
      end

      it 'sorts by level (direct reports first)' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results[0][:level]).to eq(0)
        expect(results[0][:person_id]).to eq(direct_report.id)
        expect(results[1][:level]).to eq(1)
        expect(results[1][:person_id]).to eq(grand_report.id)
      end
    end

    context 'when employee chain goes deeper' do
      let(:great_grand_report) { create(:person) }
      let(:great_grand_report_teammate) { create(:teammate, person: great_grand_report, organization: company) }

      before do
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        create(:employment_tenure, teammate: grand_report_teammate, company: company, manager_teammate: direct_report_teammate)
        create(:employment_tenure, teammate: great_grand_report_teammate, company: company, manager_teammate: grand_report_teammate)
      end

      it 'returns all reports in the chain' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        expect(results.length).to eq(3)
        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(direct_report.id, grand_report.id, great_grand_report.id)
      end

      it 'assigns correct levels to each report' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        levels = results.map { |r| r[:level] }
        expect(levels).to eq([0, 1, 2])
      end
    end

    context 'when teammate is not associated with the company' do
      let(:other_company) { create(:organization, :company) }
      let(:report_other_company) { create(:person) }
      let(:report_other_company_teammate) { create(:teammate, person: report_other_company, organization: other_company) }

      before do
        # Create employment tenure where person is manager, but teammate is in different company
        create(:employment_tenure, teammate: report_other_company_teammate, company: company, manager_teammate: person_teammate)
      end

      it 'does not include reports whose teammate is not associated with the company' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).not_to include(report_other_company.id)
      end
    end

    context 'when organization is a company with descendants' do
      let(:department) { create(:organization, :department, parent: company) }
      let(:department_report) { create(:person) }
      let(:department_report_teammate) { create(:teammate, person: department_report, organization: department) }

      before do
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        # Department report's employment tenure is in the company, but teammate is in department
        create(:employment_tenure, teammate: department_report_teammate, company: company, manager_teammate: person_teammate)
      end

      it 'includes reports from descendant organizations when teammate matches company' do
        # But wait - the teammate is in department, not company, so it should be filtered out
        # unless we also create a teammate in the company
        company_teammate = create(:teammate, person: department_report, organization: company)
        create(:employment_tenure, teammate: company_teammate, company: company, manager_teammate: person_teammate)
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(department_report.id)
      end
    end

    context 'when person manages people in different organizations' do
      let(:other_company) { create(:organization, :company) }
      let(:other_company_report) { create(:person) }
      let(:other_company_report_teammate) { create(:teammate, person: other_company_report, organization: other_company) }
      let(:person_other_company_teammate) { CompanyTeammate.create!(person: person, organization: other_company) }

      before do
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        create(:employment_tenure, teammate: other_company_report_teammate, company: other_company, manager_teammate: person_other_company_teammate)
      end

      it 'only returns reports from the specified organization' do
        query = described_class.new(person: person, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(direct_report.id)
        expect(report_ids).not_to include(other_company_report.id)
      end
    end

    context 'when report appears multiple times in chain' do
      it 'does not duplicate reports' do
        # Create a scenario where someone could appear multiple times
        create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: person_teammate)
        create(:employment_tenure, teammate: grand_report_teammate, company: company, manager_teammate: direct_report_teammate)
        
        query = described_class.new(person: person, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids.uniq.length).to eq(report_ids.length)
      end
    end

    context 'real-world scenario: Natalie -> Amy -> Tulay' do
      let(:natalie) { create(:person, first_name: 'Natalie', last_name: 'Morgan') }
      let(:natalie_teammate) { CompanyTeammate.create!(person: natalie, organization: company) }
      
      let(:amy) { create(:person, first_name: 'Amy', last_name: 'Manager') }
      let(:amy_teammate) { CompanyTeammate.create!(person: amy, organization: company) }
      
      let(:tulay) { create(:person, first_name: 'Tulay', last_name: 'Employee') }
      let(:tulay_teammate) { CompanyTeammate.create!(person: tulay, organization: company) }

      before do
        # Natalie manages Amy
        create(:employment_tenure, teammate: amy_teammate, company: company, manager_teammate: natalie_teammate)
        # Amy manages Tulay
        create(:employment_tenure, teammate: tulay_teammate, company: company, manager_teammate: amy_teammate)
      end

      it 'shows Tulay in Natalie employee hierarchy' do
        query = described_class.new(person: natalie, organization: company)
        results = query.call

        report_ids = results.map { |r| r[:person_id] }
        expect(report_ids).to include(amy.id, tulay.id)
      end

      it 'assigns correct levels' do
        query = described_class.new(person: natalie, organization: company)
        results = query.call

        amy_result = results.find { |r| r[:person_id] == amy.id }
        tulay_result = results.find { |r| r[:person_id] == tulay.id }

        expect(amy_result[:level]).to eq(0)
        expect(tulay_result[:level]).to eq(1)
      end
    end
  end
end

