require 'rails_helper'

RSpec.describe BulkSyncEvent::UploadAssignmentsAndAbilities, type: :model do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:bulk_sync_event) { build(:upload_assignments_and_abilities, organization: organization, creator: person, initiator: person) }
  
  describe '#validate_file_type' do
    it 'accepts CSV files' do
      csv_file = double('file', content_type: 'text/csv', original_filename: 'test.csv')
      expect(bulk_sync_event.validate_file_type(csv_file)).to be true
    end
    
    it 'accepts application/csv content type' do
      csv_file = double('file', content_type: 'application/csv', original_filename: 'test.csv')
      expect(bulk_sync_event.validate_file_type(csv_file)).to be true
    end
    
    it 'accepts files with .csv extension' do
      csv_file = double('file', content_type: 'application/octet-stream', original_filename: 'test.csv')
      expect(bulk_sync_event.validate_file_type(csv_file)).to be true
    end
    
    it 'rejects non-CSV files' do
      xlsx_file = double('file', content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', original_filename: 'test.xlsx')
      expect(bulk_sync_event.validate_file_type(xlsx_file)).to be false
    end
  end
  
  describe '#display_name' do
    it 'returns the correct display name' do
      expect(bulk_sync_event.display_name).to eq('Upload Assignments and Abilities')
    end
  end
  
  describe '#file_extension' do
    it 'returns csv' do
      expect(bulk_sync_event.file_extension).to eq('csv')
    end
  end
  
  describe '#process_file_for_preview' do
    let(:csv_content) do
      <<~CSV
        Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
        Test Assignment,Growth & Development Manager,People,Test tagline,Outcome 1,Communication,Activity 1
      CSV
    end
    
    before do
      bulk_sync_event.source_contents = csv_content
      bulk_sync_event.save!
    end
    
    it 'parses CSV and generates preview actions' do
      result = bulk_sync_event.process_file_for_preview
      
      expect(result).to be_truthy
      expect(bulk_sync_event.preview_actions).to be_a(Hash)
      expect(bulk_sync_event.preview_actions).to have_key('assignments')
    end
    
    it 'updates attempted_at' do
      bulk_sync_event.process_file_for_preview
      expect(bulk_sync_event.attempted_at).to be_present
    end
  end
  
  describe '#parse_error_message' do
    it 'returns generic message when parser is not set' do
      expect(bulk_sync_event.parse_error_message).to eq("Upload failed: Please check your file format.")
    end
    
    it 'returns parser errors when parser is set' do
      parser = instance_double(AssignmentsAndAbilitiesUploadParser, errors: ['Error 1', 'Error 2'])
      bulk_sync_event.instance_variable_set(:@parser, parser)
      
      expect(bulk_sync_event.parse_error_message).to eq("Upload failed: Error 1, Error 2")
    end
  end
  
  describe '#process_file_content_for_storage' do
    it 'reads file content' do
      file = double('file', read: 'test content')
      expect(bulk_sync_event.process_file_content_for_storage(file)).to eq('test content')
    end
  end
end

