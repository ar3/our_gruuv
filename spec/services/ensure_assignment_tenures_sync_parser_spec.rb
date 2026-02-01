require 'rails_helper'

RSpec.describe EnsureAssignmentTenuresSyncParser, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:parser) { described_class.new(organization) }

  describe '#initialize' do
    it 'sets organization and initializes errors and parsed_data' do
      expect(parser.organization).to eq(organization)
      expect(parser.errors).to eq([])
      expect(parser.parsed_data).to eq({})
    end
  end

  describe '#parse' do
    let!(:position_major_level) { create(:position_major_level) }
    let!(:title) { create(:title, company: organization, position_major_level: position_major_level) }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
    let!(:position) { create(:position, title: title, position_level: position_level) }
    let!(:assignment1) { create(:assignment, company: organization, title: 'Assignment 1') }
    let!(:assignment2) { create(:assignment, company: organization, title: 'Assignment 2') }
    let!(:position_assignment1) do
      create(:position_assignment, :required,
        position: position,
        assignment: assignment1,
        min_estimated_energy: 10,
        max_estimated_energy: 20
      )
    end
    let!(:position_assignment2) do
      create(:position_assignment, :required,
        position: position,
        assignment: assignment2,
        min_estimated_energy: 25,
        max_estimated_energy: 35
      )
    end
    let!(:teammate) { create(:teammate, organization: organization) }
    let!(:employment_tenure) do
      tenure = create(:employment_tenure,
        teammate: teammate,
        company: organization,
        started_at: 1.month.ago,
        ended_at: nil
      )
      tenure.update!(position: position)
      tenure
    end

    context 'with active teammates and required assignments' do
      it 'returns true and populates parsed_data' do
        expect(parser.parse).to be true
        expect(parser.errors).to be_empty
        expect(parser.parsed_data).to have_key(:assignment_tenures)
      end

      it 'finds assignment tenures to create for all required assignments' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        expect(tenures.length).to eq(2)
        expect(tenures.map { |t| t['assignment_id'] }).to contain_exactly(assignment1.id, assignment2.id)
      end

      it 'calculates energy percentage correctly (average rounded to nearest 5)' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        # Assignment 1: (10 + 20) / 2 = 15, rounded to nearest 5 = 15
        tenure1 = tenures.find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure1['anticipated_energy_percentage']).to eq(15)

        # Assignment 2: (25 + 35) / 2 = 30, rounded to nearest 5 = 30
        tenure2 = tenures.find { |t| t['assignment_id'] == assignment2.id }
        expect(tenure2['anticipated_energy_percentage']).to eq(30)
      end

      it 'includes all required data in tenure hash' do
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].first

        expect(tenure).to include(
          'teammate_id',
          'teammate_name',
          'assignment_id',
          'assignment_title',
          'position_id',
          'position_display_name',
          'anticipated_energy_percentage',
          'min_estimated_energy',
          'max_estimated_energy',
          'row'
        )
      end
    end

    context 'when assignment tenure already exists' do
      let!(:existing_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment1,
          started_at: 1.week.ago,
          ended_at: nil,
          anticipated_energy_percentage: 12
        )
      end

      it 'includes existing tenure with will_skip flag' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        expect(tenures.length).to eq(2) # Both assignments should be included
        
        existing_tenure_data = tenures.find { |t| t['assignment_id'] == assignment1.id }
        expect(existing_tenure_data).to be_present
        expect(existing_tenure_data['will_skip']).to be true
        expect(existing_tenure_data['will_create']).to be false
        expect(existing_tenure_data['existing_tenure_id']).to eq(existing_tenure.id)
        expect(existing_tenure_data['anticipated_energy_percentage']).to eq(12) # Uses existing value
        
        new_tenure_data = tenures.find { |t| t['assignment_id'] == assignment2.id }
        expect(new_tenure_data).to be_present
        expect(new_tenure_data['will_create']).to be true
        expect(new_tenure_data['will_skip']).to be false
        expect(new_tenure_data['existing_tenure_id']).to be_nil
      end
    end

    context 'with inactive employment tenure' do
      before do
        employment_tenure.update!(ended_at: 1.week.ago)
      end

      it 'skips teammates with no active employment tenure' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        expect(tenures).to be_empty
      end
    end

    context 'with position that has no required assignments' do
      before do
        PositionAssignment.where(position: position).destroy_all
      end

      it 'returns empty assignment_tenures array' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        expect(tenures).to be_empty
      end
    end

    context 'energy percentage calculation edge cases' do
      it 'rounds to nearest 5 correctly' do
        # Test case: (12 + 18) / 2 = 15, should round to 15
        position_assignment1.update!(min_estimated_energy: 12, max_estimated_energy: 18)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(15)

        # Test case: (13 + 17) / 2 = 15, should round to 15
        position_assignment1.update!(min_estimated_energy: 13, max_estimated_energy: 17)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(15)

        # Test case: (11 + 19) / 2 = 15, should round to 15
        position_assignment1.update!(min_estimated_energy: 11, max_estimated_energy: 19)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(15)

        # Test case: (14 + 16) / 2 = 15, should round to 15
        position_assignment1.update!(min_estimated_energy: 14, max_estimated_energy: 16)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(15)
      end

      it 'ensures minimum of 5' do
        # Test case: (nil + nil) / 2 = nil, should be 5
        position_assignment1.update!(min_estimated_energy: nil, max_estimated_energy: nil)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(5)

        # Test case: (1 + 2) / 2 = 1.5, rounded to 0, should be 5
        position_assignment1.update!(min_estimated_energy: 1, max_estimated_energy: 2)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(5)
      end

      it 'handles nil min/max energy values' do
        position_assignment1.update!(min_estimated_energy: nil, max_estimated_energy: nil)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        expect(tenure['anticipated_energy_percentage']).to eq(5)
      end

      it 'handles only min energy' do
        position_assignment1.update!(min_estimated_energy: 20, max_estimated_energy: nil)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        # Should use min as average, rounded to nearest 5 = 20
        expect(tenure['anticipated_energy_percentage']).to eq(20)
      end

      it 'handles only max energy' do
        position_assignment1.update!(min_estimated_energy: nil, max_estimated_energy: 30)
        parser.parse
        tenure = parser.parsed_data[:assignment_tenures].find { |t| t['assignment_id'] == assignment1.id }
        # Should use max as average, rounded to nearest 5 = 30
        expect(tenure['anticipated_energy_percentage']).to eq(30)
      end
    end

    context 'with multiple teammates' do
      let!(:teammate2) { create(:teammate, organization: organization) }
      let!(:employment_tenure2) do
        tenure = create(:employment_tenure,
          teammate: teammate2,
          company: organization,
          started_at: 2.months.ago,
          ended_at: nil
        )
        tenure.update!(position: position)
        tenure
      end

      it 'processes all active teammates' do
        parser.parse
        tenures = parser.parsed_data[:assignment_tenures]

        expect(tenures.length).to eq(4) # 2 teammates × 2 assignments
        teammate_ids = tenures.map { |t| t['teammate_id'] }.uniq
        expect(teammate_ids).to contain_exactly(teammate.id, teammate2.id)
      end
    end

    context 'when error occurs' do
      before do
        allow(EmploymentTenure).to receive(:active).and_raise(StandardError, 'Database error')
      end

      it 'returns false and adds error' do
        expect(parser.parse).to be false
        expect(parser.errors).not_to be_empty
        expect(parser.errors.first).to include('Error parsing data')
      end
    end
  end

  describe '#enhanced_preview_actions' do
    it 'returns hash with assignment_tenures key' do
      parser.parse
      preview = parser.enhanced_preview_actions

      expect(preview).to have_key('assignment_tenures')
      expect(preview['assignment_tenures']).to be_an(Array)
    end
  end
end
