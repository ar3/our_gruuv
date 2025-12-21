require 'rails_helper'

RSpec.describe AssignmentsAndAbilitiesUploadProcessor, type: :service do
  let(:organization) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  let(:bulk_sync_event) { create(:upload_assignments_and_abilities, organization: organization, creator: person, initiator: person) }
  let(:processor) { described_class.new(bulk_sync_event, organization) }

  describe '#initialize' do
    it 'sets bulk_sync_event, organization, and results' do
      expect(processor.bulk_sync_event).to eq(bulk_sync_event)
      expect(processor.organization).to eq(organization)
      expect(processor.results).to eq({ successes: [], failures: [] })
    end
  end

  describe '#process' do
    let(:preview_actions) do
      {
        'assignments' => [
          {
            'title' => 'Test Assignment',
            'tagline' => 'Test tagline',
            'outcomes' => ['Outcome 1', 'Outcome 2'],
            'required_activities' => ['Activity 1', 'Activity 2'],
            'department_names' => ['Engineering'],
            'row' => 2
          }
        ],
        'abilities' => [
          { 'name' => 'Communication', 'row' => 2 },
          { 'name' => 'Project Management', 'row' => 2 }
        ],
        'assignment_abilities' => [
          {
            'assignment_title' => 'Test Assignment',
            'ability_name' => 'Communication',
            'milestone_level' => 1,
            'row' => 2
          }
        ],
        'position_assignments' => [
          {
            'assignment_title' => 'Test Assignment',
            'position_title' => 'Software Engineer',
            'department_names' => ['Engineering'],
            'row' => 2
          }
        ]
      }
    end

    before do
      bulk_sync_event.update!(preview_actions: preview_actions, status: 'preview')
    end

    context 'with valid data' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
      let!(:position_type) do
        create(:position_type, external_title: 'Software Engineer', organization: organization, position_major_level: position_major_level)
      end
      let!(:department) { create(:organization, type: 'Department', name: 'Engineering', parent: organization) }

      it 'processes successfully and returns true' do
        expect(processor.process).to be true
        expect(bulk_sync_event.reload.status).to eq('completed')
      end

      it 'creates new assignment with version 0.0.1' do
        expect { processor.process }.to change(Assignment, :count).by(1)
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment).to be_present
        expect(assignment.semantic_version).to eq('0.0.1')
        expect(assignment.tagline).to eq('Test tagline')
      end

      it 'creates new abilities with version 0.0.1' do
        expect { processor.process }.to change(Ability, :count).by(2)
        ability = Ability.find_by(name: 'Communication', organization: organization)
        expect(ability).to be_present
        expect(ability.semantic_version).to eq('0.0.1')
      end

      it 'creates assignment-ability links' do
        expect { processor.process }.to change(AssignmentAbility, :count).by(1)
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        ability = Ability.find_by(name: 'Communication', organization: organization)
        expect(AssignmentAbility.find_by(assignment: assignment, ability: ability)).to be_present
      end

      it 'creates position-assignment links' do
        expect { processor.process }.to change(PositionAssignment, :count).by(1)
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        position = Position.find_by(position_type: position_type)
        expect(PositionAssignment.find_by(assignment: assignment, position: position)).to be_present
      end

      it 'adds outcomes without deleting existing' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.assignment_outcomes.count).to eq(2)
      end

      it 'sets department association when single department found' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.department_id).to eq(department.id)
      end
    end

    context 'with existing assignment' do
      let!(:existing_assignment) do
        create(:assignment, title: 'Test Assignment', company: organization, semantic_version: '1.2.3')
      end
      let!(:existing_outcome) do
        create(:assignment_outcome, assignment: existing_assignment, description: 'Existing Outcome')
      end

      it 'updates assignment and increments version' do
        processor.process
        existing_assignment.reload
        expect(existing_assignment.semantic_version).to eq('1.3.0') # Clarifying change
        expect(existing_assignment.tagline).to eq('Test tagline')
      end

      it 'adds new outcomes without deleting existing' do
        processor.process
        existing_assignment.reload
        expect(existing_assignment.assignment_outcomes.count).to eq(3) # 1 existing + 2 new
        expect(existing_assignment.assignment_outcomes.pluck(:description)).to include('Existing Outcome')
      end
    end

    context 'with existing ability' do
      let!(:existing_ability) do
        create(:ability, name: 'Communication', organization: organization, semantic_version: '2.1.0')
      end

      it 'updates ability and increments version' do
        processor.process
        existing_ability.reload
        expect(existing_ability.semantic_version).to eq('2.2.0') # Clarifying change
      end
    end

    context 'with flexible name matching' do
      let!(:assignment_with_ampersand) do
        create(:assignment, title: 'Test & Development', company: organization)
      end

      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test and Development',
              'tagline' => 'Updated tagline',
              'outcomes' => [],
              'required_activities' => [],
              'department_names' => [],
              'row' => 2
            }
          ],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => []
        }
      end

      it 'finds assignment with &/and variation' do
        processor.process
        assignment_with_ampersand.reload
        expect(assignment_with_ampersand.tagline).to eq('Updated tagline')
      end
    end

    context 'with multiple departments' do
      let!(:dept1) { create(:organization, type: 'Department', name: 'Engineering', parent: organization) }
      let!(:dept2) { create(:organization, type: 'Department', name: 'Engineering', parent: organization) }

      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test Assignment',
              'tagline' => 'Test tagline',
              'outcomes' => [],
              'required_activities' => [],
              'department_names' => ['Engineering'],
              'row' => 2
            }
          ],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => []
        }
      end

      it 'attaches to company when multiple departments found' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.department_id).to be_nil
      end
    end

    context 'when position type not found' do
      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test Assignment',
              'tagline' => 'Test tagline',
              'outcomes' => [],
              'required_activities' => [],
              'department_names' => [],
              'row' => 2
            }
          ],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => [
            {
              'assignment_title' => 'Test Assignment',
              'position_title' => 'Non-existent Position',
              'department_names' => [],
              'row' => 2
            }
          ]
        }
      end

      it 'skips position assignment and logs warning' do
        expect(Rails.logger).to receive(:warn).at_least(:once)
        processor.process
        expect(PositionAssignment.count).to eq(0)
      end
    end

    context 'when PositionMajorLevel has no PositionLevels' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_type) do
        create(:position_type, external_title: 'Software Engineer', organization: organization, position_major_level: position_major_level)
      end

      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test Assignment',
              'tagline' => 'Test tagline',
              'outcomes' => [],
              'required_activities' => [],
              'department_names' => [],
              'row' => 2
            }
          ],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => [
            {
              'assignment_title' => 'Test Assignment',
              'position_title' => 'Software Engineer',
              'department_names' => [],
              'row' => 2
            }
          ]
        }
      end

      it 'logs warning and skips position creation' do
        expect(Rails.logger).to receive(:warn).at_least(:once)
        processor.process
        expect(Position.count).to eq(0)
      end
    end
  end
end

