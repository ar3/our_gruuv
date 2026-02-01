require 'rails_helper'

RSpec.describe BulkSyncEvent::EnsureAssignmentTenuresSync, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:bulk_sync_event) do
    BulkSyncEvent::EnsureAssignmentTenuresSync.create!(
      organization: organization,
      creator: person,
      initiator: person,
      status: 'preview',
      source_data: { type: 'database_sync' }
    )
  end

  describe '#validate_file_type' do
    it 'returns true (no file validation needed for sync operations)' do
      file = double('file')
      expect(bulk_sync_event.validate_file_type(file)).to be true
    end
  end

  describe '#display_name' do
    it 'returns the correct display name' do
      expect(bulk_sync_event.display_name).to eq('Ensure Assignment Tenures')
    end
  end

  describe '#file_extension' do
    it 'returns nil' do
      expect(bulk_sync_event.file_extension).to be_nil
    end
  end

  describe '#source_type' do
    it 'returns database_sync' do
      expect(bulk_sync_event.source_type).to eq('database_sync')
    end
  end

  describe '#process_file_for_preview' do
    it 'calls generate_preview' do
      expect(bulk_sync_event).to receive(:generate_preview)
      bulk_sync_event.process_file_for_preview
    end
  end

  describe '#generate_preview' do
    let!(:position_major_level) { create(:position_major_level) }
    let!(:title) { create(:title, company: organization, position_major_level: position_major_level) }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
    let!(:position) { create(:position, title: title, position_level: position_level) }
    let!(:assignment) { create(:assignment, company: organization) }
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

    it 'generates preview actions' do
      result = bulk_sync_event.generate_preview

      expect(result).to be_truthy
      expect(bulk_sync_event.preview_actions).to be_a(Hash)
      expect(bulk_sync_event.preview_actions).to have_key('assignment_tenures')
    end

    it 'updates attempted_at' do
      bulk_sync_event.generate_preview
      expect(bulk_sync_event.attempted_at).to be_present
    end

    context 'when parser fails' do
      before do
        allow_any_instance_of(EnsureAssignmentTenuresSyncParser).to receive(:parse).and_return(false)
        allow_any_instance_of(EnsureAssignmentTenuresSyncParser).to receive(:errors).and_return(['Error message'])
      end

      it 'returns false and sets parser' do
        result = bulk_sync_event.generate_preview
        expect(result).to be false
        expect(bulk_sync_event.instance_variable_get(:@parser)).to be_present
      end
    end
  end

  describe '#process_upload_in_background' do
    it 'calls perform_and_get_result on the processor job' do
      expect(EnsureAssignmentTenuresSyncProcessorJob).to receive(:perform_and_get_result)
        .with(bulk_sync_event.id, organization.id)
      bulk_sync_event.process_upload_in_background
    end
  end

  describe '#parse_error_message' do
    it 'returns generic message when parser is not set' do
      expect(bulk_sync_event.parse_error_message).to eq("Sync failed: Unable to generate preview.")
    end

    it 'returns parser errors when parser is set' do
      parser = instance_double(EnsureAssignmentTenuresSyncParser, errors: ['Error 1', 'Error 2'])
      bulk_sync_event.instance_variable_set(:@parser, parser)

      expect(bulk_sync_event.parse_error_message).to eq("Sync failed: Error 1, Error 2")
    end
  end
end
