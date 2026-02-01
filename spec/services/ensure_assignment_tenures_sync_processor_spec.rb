require 'rails_helper'

RSpec.describe EnsureAssignmentTenuresSyncProcessor, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:bulk_sync_event) { create(:bulk_sync_event, organization: organization, status: 'preview') }
  let(:processor) { described_class.new(bulk_sync_event, organization) }

  describe '#initialize' do
    it 'sets bulk_sync_event, organization, and results' do
      expect(processor.bulk_sync_event).to eq(bulk_sync_event)
      expect(processor.organization).to eq(organization)
      expect(processor.results).to have_key(:successes)
      expect(processor.results).to have_key(:failures)
      expect(processor.results).to have_key(:summary)
    end
  end

  describe '#process' do
    let!(:position_major_level) { create(:position_major_level) }
    let!(:title) { create(:title, company: organization, position_major_level: position_major_level) }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
    let!(:position) { create(:position, title: title, position_level: position_level) }
    let!(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
    let!(:teammate) { create(:teammate, organization: organization) }

    let(:preview_actions) do
      {
        'assignment_tenures' => [
          {
            'teammate_id' => teammate.id,
            'teammate_name' => teammate.person.display_name,
            'assignment_id' => assignment.id,
            'assignment_title' => assignment.title,
            'position_id' => position.id,
            'position_display_name' => position.display_name,
            'anticipated_energy_percentage' => 15,
            'min_estimated_energy' => 10,
            'max_estimated_energy' => 20,
            'row' => 1
          }
        ]
      }
    end

    before do
      bulk_sync_event.update!(preview_actions: preview_actions)
    end

    context 'with valid preview actions' do
      it 'returns true and creates assignment tenures' do
        expect(processor.process).to be true
        expect(processor.results[:successes]).not_to be_empty
        expect(processor.results[:failures]).to be_empty
      end

      it 'creates new assignment tenure' do
        expect {
          processor.process
        }.to change(AssignmentTenure, :count).by(1)
      end

      it 'creates assignment tenure with correct attributes' do
        processor.process

        tenure = AssignmentTenure.last
        expect(tenure.teammate.id).to eq(teammate.id)
        expect(tenure.assignment).to eq(assignment)
        expect(tenure.started_at).to eq(Date.current)
        expect(tenure.ended_at).to be_nil
        expect(tenure.anticipated_energy_percentage).to eq(15)
      end

      it 'tracks success in results' do
        processor.process

        success = processor.results[:successes].first
        expect(success['type']).to eq('assignment_tenure_creation')
        expect(success['teammate_id']).to eq(teammate.id)
        expect(success['assignment_id']).to eq(assignment.id)
        expect(success['action']).to eq('created')
        expect(success['assignment_tenure_id']).to be_present
      end

      it 'updates summary correctly' do
        processor.process

        summary = processor.results[:summary]
        expect(summary[:total_processed]).to eq(1)
        expect(summary[:successful_creations]).to eq(1)
        expect(summary[:skipped_existing]).to eq(0)
        expect(summary[:failed_operations]).to eq(0)
      end
    end

    context 'when assignment tenure already exists' do
      let!(:existing_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          started_at: 1.week.ago,
          ended_at: nil
        )
      end

      it 'skips creation and marks as skipped' do
        expect {
          processor.process
        }.not_to change(AssignmentTenure, :count)
      end

      it 'tracks skip in results' do
        processor.process

        success = processor.results[:successes].first
        expect(success['action']).to eq('skipped')
        expect(success['reason']).to eq('Assignment tenure already exists')
      end

      it 'updates summary with skipped count' do
        processor.process

        summary = processor.results[:summary]
        expect(summary[:skipped_existing]).to eq(1)
        expect(summary[:successful_creations]).to eq(0)
      end
    end

    context 'with multiple assignment tenures' do
      let!(:assignment2) { create(:assignment, company: organization, title: 'Test Assignment 2') }
      let!(:assignment3) { create(:assignment, company: organization, title: 'Test Assignment 3') }

      let(:preview_actions) do
        {
          'assignment_tenures' => [
            {
              'teammate_id' => teammate.id,
              'teammate_name' => teammate.person.display_name,
              'assignment_id' => assignment.id,
              'assignment_title' => assignment.title,
              'position_id' => position.id,
              'position_display_name' => position.display_name,
              'anticipated_energy_percentage' => 15,
              'row' => 1
            },
            {
              'teammate_id' => teammate.id,
              'teammate_name' => teammate.person.display_name,
              'assignment_id' => assignment2.id,
              'assignment_title' => assignment2.title,
              'position_id' => position.id,
              'position_display_name' => position.display_name,
              'anticipated_energy_percentage' => 25,
              'row' => 2
            },
            {
              'teammate_id' => teammate.id,
              'teammate_name' => teammate.person.display_name,
              'assignment_id' => assignment3.id,
              'assignment_title' => assignment3.title,
              'position_id' => position.id,
              'position_display_name' => position.display_name,
              'anticipated_energy_percentage' => 30,
              'row' => 3
            }
          ]
        }
      end

      it 'creates all assignment tenures' do
        expect {
          processor.process
        }.to change(AssignmentTenure, :count).by(3)
      end

      it 'tracks all successes' do
        processor.process

        expect(processor.results[:successes].length).to eq(3)
        expect(processor.results[:summary][:successful_creations]).to eq(3)
      end
    end

    context 'when teammate is not found' do
      let(:preview_actions) do
        {
          'assignment_tenures' => [
            {
              'teammate_id' => 99999,
              'assignment_id' => assignment.id,
              'anticipated_energy_percentage' => 15,
              'row' => 1
            }
          ]
        }
      end

      it 'returns true but tracks failure' do
        expect(processor.process).to be true
        expect(processor.results[:failures]).not_to be_empty
        expect(processor.results[:failures].first['error']).to include('Teammate not found')
      end
    end

    context 'when assignment is not found' do
      let(:preview_actions) do
        {
          'assignment_tenures' => [
            {
              'teammate_id' => teammate.id,
              'assignment_id' => 99999,
              'anticipated_energy_percentage' => 15,
              'row' => 1
            }
          ]
        }
      end

      it 'returns true but tracks failure' do
        expect(processor.process).to be true
        expect(processor.results[:failures]).not_to be_empty
        expect(processor.results[:failures].first['error']).to include('Assignment not found')
      end
    end

    context 'when assignment tenure creation fails validation' do
      let(:preview_actions) do
        {
          'assignment_tenures' => [
            {
              'teammate_id' => teammate.id,
              'teammate_name' => teammate.person.display_name,
              'assignment_id' => assignment.id,
              'assignment_title' => assignment.title,
              'position_id' => position.id,
              'position_display_name' => position.display_name,
              'anticipated_energy_percentage' => 15,
              'row' => 1
            }
          ]
        }
      end

      before do
        # Create an overlapping active tenure to cause validation error
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          started_at: Date.current,
          ended_at: nil
        )
      end

      it 'tracks skip instead of failure (tenure already exists)' do
        processor.process

        # Should skip, not fail, because tenure already exists
        expect(processor.results[:successes]).not_to be_empty
        success = processor.results[:successes].first
        expect(success['action']).to eq('skipped')
        expect(processor.results[:failures]).to be_empty
      end
    end

    context 'with empty preview actions' do
      let(:preview_actions) { {} }

      it 'returns false and adds error' do
        expect(processor.process).to be false
        expect(processor.results[:failures].first['error']).to eq('No assignment tenures to create')
      end
    end

    context 'when error occurs during processing' do
      before do
        allow(AssignmentTenure).to receive(:new).and_raise(StandardError, 'Database error')
      end

      it 'returns false and tracks error' do
        expect(processor.process).to be false
        expect(processor.results[:failures]).not_to be_empty
        expect(processor.results[:failures].first['error']).to include('Database error')
      end
    end
  end
end
