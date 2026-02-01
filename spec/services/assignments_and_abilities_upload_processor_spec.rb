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
      let!(:title) do
        create(:title, external_title: 'Software Engineer', company: organization, position_major_level: position_major_level)
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
        position = Position.find_by(title: title)
        expect(PositionAssignment.find_by(assignment: assignment, position: position)).to be_present
      end

      it 'sets max_estimated_energy to 5 for new position assignments' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        position = Position.find_by(title: title)
        position_assignment = PositionAssignment.find_by(assignment: assignment, position: position)
        expect(position_assignment.max_estimated_energy).to eq(5)
        expect(position_assignment.min_estimated_energy).to be_nil
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

      it 'processes outcomes from preview_actions' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        outcome_descriptions = assignment.assignment_outcomes.pluck(:description)
        expect(outcome_descriptions).to include('Outcome 1')
        expect(outcome_descriptions).to include('Outcome 2')
      end

      it 'processes department_names from preview_actions' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.department_id).to eq(department.id)
        expect(assignment.department.name).to eq('Engineering')
      end

      it 'creates department when it does not exist' do
        preview_actions['assignments'].first['department_names'] = ['New Department']
        bulk_sync_event.update!(preview_actions: preview_actions)
        
        expect { processor.process }.to change(Organization.departments, :count).by(1)
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        new_department = Organization.departments.find_by(name: 'New Department', parent: organization)
        expect(assignment.department_id).to eq(new_department.id)
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
        create(:ability, name: 'Communication', company: organization, semantic_version: '2.1.0')
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

    context 'with multiple department names in input' do
      let!(:existing_assignment) do
        create(:assignment, title: 'Test Assignment', company: organization, department_id: nil)
      end

      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test Assignment',
              'tagline' => 'Test tagline',
              'outcomes' => [],
              'required_activities' => [],
              'department_names' => ['Engineering', 'Sales'],
              'row' => 2
            }
          ],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => []
        }
      end

      it 'leaves department field untouched when multiple department names provided' do
        original_department_id = existing_assignment.department_id
        processor.process
        existing_assignment.reload
        expect(existing_assignment.department_id).to eq(original_department_id)
      end
    end

    context 'with assignment outcomes' do
      let(:preview_actions) do
        {
          'assignments' => [
            {
              'title' => 'Test Assignment',
              'tagline' => 'Test tagline',
              'outcomes' => ['Outcome 1', 'Outcome 2', 'Squad-mates agree: "We are learning"'],
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

      it 'creates outcomes with exact match find-or-create behavior' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.assignment_outcomes.count).to eq(3)
        
        outcome1 = assignment.assignment_outcomes.find_by(description: 'Outcome 1')
        expect(outcome1).to be_present
        expect(outcome1.outcome_type).to eq('quantitative')
        
        outcome2 = assignment.assignment_outcomes.find_by(description: 'Outcome 2')
        expect(outcome2).to be_present
        expect(outcome2.outcome_type).to eq('quantitative')
        
        sentiment_outcome = assignment.assignment_outcomes.find_by(description: 'Squad-mates agree: "We are learning"')
        expect(sentiment_outcome).to be_present
        expect(sentiment_outcome.outcome_type).to eq('sentiment')
      end

      it 'does not create duplicate outcomes when processing same assignment twice' do
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        original_count = assignment.assignment_outcomes.count
        
        # Process again with same outcomes
        processor.process
        assignment.reload
        expect(assignment.assignment_outcomes.count).to eq(original_count)
      end

      it 'receives outcomes from preview_actions (not nil)' do
        assignment_data = preview_actions['assignments'].first
        expect(assignment_data['outcomes']).to be_present
        expect(assignment_data['outcomes']).to be_an(Array)
        
        processor.process
        assignment = Assignment.find_by(title: 'Test Assignment', company: organization)
        expect(assignment.assignment_outcomes.count).to eq(3)
      end
    end

    context 'end-to-end: CSV with department and outcomes' do
      let(:csv_content) do
        <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          End-to-End Test,Position,Partner Services,Tagline,"-Outcome A
          -Outcome B",Ability,Activity
        CSV
      end
      let(:parser) { AssignmentsAndAbilitiesUploadParser.new(csv_content, organization) }
      let(:preview_actions) do
        parser.parse
        parser.enhanced_preview_actions
      end
      let!(:department) { create(:organization, type: 'Department', name: 'Partner Services', parent: organization) }

      before do
        bulk_sync_event.update!(preview_actions: preview_actions, status: 'preview')
      end

      it 'processes department and outcomes from CSV through to assignment' do
        processor.process
        assignment = Assignment.find_by(title: 'End-to-End Test', company: organization)
        
        expect(assignment).to be_present
        expect(assignment.department_id).to eq(department.id)
        expect(assignment.assignment_outcomes.count).to eq(2)
        
        outcome_a = assignment.assignment_outcomes.find_by(description: '-Outcome A')
        expect(outcome_a).to be_present
        
        outcome_b = assignment.assignment_outcomes.find_by(description: '-Outcome B')
        expect(outcome_b).to be_present
      end

      it 'ensures enhanced_preview_actions includes required fields' do
        assignment_data = preview_actions['assignments'].first
        
        expect(assignment_data).to have_key('department_names')
        expect(assignment_data).to have_key('outcomes')
        expect(assignment_data['department_names']).to eq(['Partner Services'])
        expect(assignment_data['outcomes']).to be_an(Array)
        expect(assignment_data['outcomes'].length).to eq(2)
      end
    end

    context 'when position type not found' do
      let!(:position_major_level) { create(:position_major_level, major_level: 1) }
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

      it 'skips position assignment and logs warning when no position level exists' do
        expect(Rails.logger).to receive(:warn).at_least(:once)
        processor.process
        expect(PositionAssignment.count).to eq(0)
      end
    end

    context 'when PositionMajorLevel has no PositionLevels' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:title) do
        create(:title, external_title: 'Software Engineer', company: organization, position_major_level: position_major_level)
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

    context 'position tracking' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
      let!(:title) do
        create(:title, external_title: 'Software Engineer', company: organization, position_major_level: position_major_level)
      end

      context 'when position is created' do
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

        it 'tracks position creation in results' do
          processor.process
          position_results = bulk_sync_event.reload.results['successes'].select { |s| s['type'] == 'position' }
          expect(position_results.length).to eq(1)
          expect(position_results.first['action']).to eq('created')
          expect(position_results.first['title_id']).to eq(title.id)
          expect(position_results.first['title_name']).to eq('Software Engineer')
        end
      end

      context 'when position already exists' do
        let!(:existing_position) do
          create(:position, title: title, position_level: position_level)
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

        it 'tracks position finding in results' do
          processor.process
          position_results = bulk_sync_event.reload.results['successes'].select { |s| s['type'] == 'position' }
          expect(position_results.length).to eq(1)
          expect(position_results.first['action']).to eq('found')
          expect(position_results.first['id']).to eq(existing_position.id)
        end
      end
    end

    context 'with existing position assignment' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
      let!(:title) do
        create(:title, external_title: 'Software Engineer', company: organization, position_major_level: position_major_level)
      end
      let!(:position) { create(:position, title: title, position_level: position_level) }
      let!(:assignment) { create(:assignment, title: 'Test Assignment', company: organization) }

      context 'when both min and max energy are nil' do
        let!(:existing_position_assignment) do
          create(:position_assignment, position: position, assignment: assignment, 
                 min_estimated_energy: nil, max_estimated_energy: nil)
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'sets max_estimated_energy to 5' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to eq(5)
          expect(existing_position_assignment.min_estimated_energy).to be_nil
        end
      end

      context 'when both min and max energy are 0' do
        let!(:existing_position_assignment) do
          pa = create(:position_assignment, position: position, assignment: assignment, 
                      min_estimated_energy: 0, max_estimated_energy: nil)
          pa.update_column(:max_estimated_energy, 0) # Bypass validation to set to 0
          pa
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'sets max_estimated_energy to 5' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to eq(5)
          expect(existing_position_assignment.min_estimated_energy).to eq(0)
        end
      end

      context 'when min is nil and max is 0' do
        let!(:existing_position_assignment) do
          pa = create(:position_assignment, position: position, assignment: assignment, 
                      min_estimated_energy: nil, max_estimated_energy: nil)
          pa.update_column(:max_estimated_energy, 0) # Bypass validation to set to 0
          pa
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'sets max_estimated_energy to 5' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to eq(5)
          expect(existing_position_assignment.min_estimated_energy).to be_nil
        end
      end

      context 'when min is 0 and max is nil' do
        let!(:existing_position_assignment) do
          create(:position_assignment, position: position, assignment: assignment, 
                 min_estimated_energy: 0, max_estimated_energy: nil)
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'sets max_estimated_energy to 5' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to eq(5)
          expect(existing_position_assignment.min_estimated_energy).to eq(0)
        end
      end

      context 'when max_estimated_energy is already set to a non-zero value' do
        let!(:existing_position_assignment) do
          create(:position_assignment, position: position, assignment: assignment, 
                 min_estimated_energy: nil, max_estimated_energy: 10)
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'does not change max_estimated_energy' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to eq(10)
        end
      end

      context 'when min_estimated_energy is set to a non-zero value' do
        let!(:existing_position_assignment) do
          create(:position_assignment, position: position, assignment: assignment, 
                 min_estimated_energy: 5, max_estimated_energy: nil)
        end

        let(:preview_actions) do
          {
            'assignments' => [],
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

        it 'does not change max_estimated_energy' do
          processor.process
          existing_position_assignment.reload
          expect(existing_position_assignment.max_estimated_energy).to be_nil
          expect(existing_position_assignment.min_estimated_energy).to eq(5)
        end
      end
    end

    context 'seat department updates' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
      let!(:title) do
        create(:title, external_title: 'Software Engineer', company: organization, position_major_level: position_major_level)
      end
      let!(:department) { create(:organization, type: 'Department', name: 'Engineering', parent: organization) }
      let!(:seat1) { create(:seat, title: title, seat_needed_by: Date.current + 3.months) }
      let!(:seat2) { create(:seat, title: title, seat_needed_by: Date.current + 4.months) }

      context 'when department_names are provided' do
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
                'department_names' => ['Engineering'],
                'row' => 2
              }
            ]
          }
        end

        it 'updates all seats for the position type with single department' do
          processor.process
          seat1.reload
          seat2.reload
          expect(seat1.department_id).to eq(department.id)
          expect(seat2.department_id).to eq(department.id)
        end

        it 'only updates department, not other seat attributes' do
          original_seat_needed_by = seat1.seat_needed_by
          original_state = seat1.state
          processor.process
          seat1.reload
          expect(seat1.seat_needed_by).to eq(original_seat_needed_by)
          expect(seat1.state).to eq(original_state)
          expect(seat1.department_id).to eq(department.id)
        end
      end

      context 'when department_names are not provided' do
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

        it 'does not update seat departments' do
          original_dept1 = seat1.department_id
          original_dept2 = seat2.department_id
          processor.process
          seat1.reload
          seat2.reload
          expect(seat1.department_id).to eq(original_dept1)
          expect(seat2.department_id).to eq(original_dept2)
        end
      end

      context 'when multiple department names provided' do
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
                'department_names' => ['Engineering', 'Sales'],
                'row' => 2
              }
            ]
          }
        end

        it 'leaves seat department fields untouched when multiple department names provided' do
          original_dept1 = seat1.department_id
          original_dept2 = seat2.department_id
          processor.process
          seat1.reload
          seat2.reload
          expect(seat1.department_id).to eq(original_dept1)
          expect(seat2.department_id).to eq(original_dept2)
        end
      end

      context 'when department does not exist' do
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
                'department_names' => ['New Department'],
                'row' => 2
              }
            ]
          }
        end

        it 'creates department and updates seats' do
          expect { processor.process }.to change(Organization.departments, :count).by(1)
          new_department = Organization.departments.find_by(name: 'New Department', parent: organization)
          expect(new_department).to be_present
          
          seat1.reload
          seat2.reload
          expect(seat1.department_id).to eq(new_department.id)
          expect(seat2.department_id).to eq(new_department.id)
        end
      end

      context 'when department does not exist (single name)' do
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
                'department_names' => ['Non-existent Department'],
                'row' => 2
              }
            ]
          }
        end

        it 'creates department and updates seats' do
          expect { processor.process }.to change(Organization.departments, :count).by(1)
          new_department = Organization.departments.find_by(name: 'Non-existent Department', parent: organization)
          expect(new_department).to be_present
          
          seat1.reload
          seat2.reload
          expect(seat1.department_id).to eq(new_department.id)
          expect(seat2.department_id).to eq(new_department.id)
        end
      end

      context 'with multiple seats for same position type' do
        let!(:seat3) { create(:seat, title: title, seat_needed_by: Date.current + 5.months) }
        let!(:department) { create(:organization, type: 'Department', name: 'Engineering', parent: organization) }

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
                'department_names' => ['Engineering'],
                'row' => 2
              }
            ]
          }
        end

        it 'updates all seats for the position type' do
          processor.process
          seat1.reload
          seat2.reload
          seat3.reload
          expect(seat1.department_id).to eq(department.id)
          expect(seat2.department_id).to eq(department.id)
          expect(seat3.department_id).to eq(department.id)
        end
      end
    end
  end
end

