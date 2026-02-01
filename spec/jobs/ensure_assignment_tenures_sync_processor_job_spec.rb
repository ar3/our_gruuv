require 'rails_helper'

RSpec.describe EnsureAssignmentTenuresSyncProcessorJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:bulk_sync_event) do
    create(:bulk_sync_event,
      type: 'BulkSyncEvent::EnsureAssignmentTenuresSync',
      organization: organization,
      creator: person,
      initiator: person,
      status: 'preview'
    )
  end

  describe '#perform' do
    context 'with valid bulk sync event' do
      before do
        # Mock the processor to return success
        processor_instance = instance_double(EnsureAssignmentTenuresSyncProcessor)
        allow(EnsureAssignmentTenuresSyncProcessor).to receive(:new)
          .with(kind_of(BulkSyncEvent::EnsureAssignmentTenuresSync), kind_of(Organization))
          .and_return(processor_instance)
        allow(processor_instance).to receive(:process).and_return(true)
        allow(processor_instance).to receive(:results).and_return({
          successes: [
            { type: 'assignment_tenure_creation', action: 'created', assignment_title: 'Test Assignment' }
          ],
          failures: [],
          summary: {
            total_processed: 1,
            successful_creations: 1,
            skipped_existing: 0,
            failed_operations: 0
          }
        })
      end

      it 'processes the sync successfully' do
        result = described_class.perform_and_get_result(bulk_sync_event.id, organization.id)

        expect(result).to be true
        expect(bulk_sync_event.reload.status).to eq('completed')
        expect(bulk_sync_event.results).to include('successes', 'failures')
      end

      it 'marks bulk sync event as processing then completed' do
        result = described_class.perform_and_get_result(bulk_sync_event.id, organization.id)

        expect(result).to be true
        expect(bulk_sync_event.reload.status).to eq('completed')
      end
    end

    context 'when processor returns false' do
      before do
        processor_instance = instance_double(EnsureAssignmentTenuresSyncProcessor)
        allow(EnsureAssignmentTenuresSyncProcessor).to receive(:new)
          .with(kind_of(BulkSyncEvent::EnsureAssignmentTenuresSync), kind_of(Organization))
          .and_return(processor_instance)
        allow(processor_instance).to receive(:process).and_return(false)
        allow(processor_instance).to receive(:results).and_return({
          successes: [],
          failures: [
            { type: 'system_error', error: 'No assignment tenures to create' }
          ]
        })
      end

      it 'marks bulk sync event as failed' do
        result = described_class.perform_and_get_result(bulk_sync_event.id, organization.id)

        expect(result).to be false
        expect(bulk_sync_event.reload.status).to eq('failed')
        expect(bulk_sync_event.results['error']).to include('Processing failed')
      end
    end

    context 'when bulk sync event is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_and_get_result(99999, organization.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when organization is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_and_get_result(bulk_sync_event.id, 99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(EnsureAssignmentTenuresSyncProcessor).to receive(:new)
          .with(kind_of(BulkSyncEvent::EnsureAssignmentTenuresSync), kind_of(Organization))
          .and_raise(StandardError.new('Database connection failed'))
      end

      it 'marks bulk sync event as failed with error message' do
        result = described_class.perform_and_get_result(bulk_sync_event.id, organization.id)

        expect(result).to be false
        expect(bulk_sync_event.reload.status).to eq('failed')
        expect(bulk_sync_event.results['error']).to eq('Unexpected error: Database connection failed')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with("EnsureAssignmentTenuresSyncProcessorJob failed: Database connection failed")
        expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace

        described_class.perform_and_get_result(bulk_sync_event.id, organization.id)
      end
    end

    context 'with real processor integration' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:title) { create(:title, company: organization, position_major_level: position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
      let!(:position) { create(:position, title: title, position_level: position_level) }
      let!(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
      let!(:position_assignment) do
        create(:position_assignment, :required,
          position: position,
          assignment: assignment,
          min_estimated_energy: 10,
          max_estimated_energy: 20
        )
      end
      let!(:teammate) { create(:teammate, organization: organization) }
      let!(:employment_tenure) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          started_at: 1.month.ago,
          ended_at: nil
        )
      end

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

      it 'actually processes assignment tenures' do
        expect {
          described_class.perform_and_get_result(bulk_sync_event.id, organization.id)
        }.to change(AssignmentTenure, :count).by(1)

        expect(bulk_sync_event.reload.status).to eq('completed')
        expect(bulk_sync_event.results['successes']).not_to be_empty

        tenure = AssignmentTenure.last
        expect(tenure.teammate.id).to eq(teammate.id)
        expect(tenure.assignment).to eq(assignment)
        expect(tenure.anticipated_energy_percentage).to eq(15)
      end
    end
  end

  describe '.perform_and_get_result' do
    it 'creates a new job instance and calls perform' do
      job_instance = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(job_instance)
      allow(job_instance).to receive(:perform).with(bulk_sync_event.id, organization.id).and_return(true)

      result = described_class.perform_and_get_result(bulk_sync_event.id, organization.id)

      expect(result).to be true
      expect(described_class).to have_received(:new)
      expect(job_instance).to have_received(:perform).with(bulk_sync_event.id, organization.id)
    end
  end
end
