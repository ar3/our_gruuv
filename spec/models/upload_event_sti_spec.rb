require 'rails_helper'

RSpec.describe UploadEvent, type: :model do
  describe "Single Table Inheritance" do
    let(:organization) { create(:organization) }
    let(:creator) { create(:person) }

    it "creates UploadAssignmentCheckins subclass correctly" do
      upload_event = UploadEvent::UploadAssignmentCheckins.create!(
        organization: organization,
        creator: creator,
        initiator: creator,
        file_content: "test content",
        filename: "test.xlsx",
        status: 'preview'
      )
      
      expect(upload_event).to be_a(UploadEvent::UploadAssignmentCheckins)
      expect(upload_event.type).to eq('UploadEvent::UploadAssignmentCheckins')
      expect(upload_event.display_name).to eq('Upload Assignment Check-Ins')
    end

    it "creates UploadEmployees subclass correctly" do
      upload_event = UploadEvent::UploadEmployees.create!(
        organization: organization,
        creator: creator,
        initiator: creator,
        file_content: "test content",
        filename: "test.csv",
        status: 'preview'
      )
      
      expect(upload_event).to be_a(UploadEvent::UploadEmployees)
      expect(upload_event.type).to eq('UploadEvent::UploadEmployees')
      expect(upload_event.display_name).to eq('Upload Employee Positions')
    end

    it "loads existing records with correct STI type" do
      # Create a record with the old type format
      upload_event = UploadEvent.create!(
        organization: organization,
        creator: creator,
        initiator: creator,
        file_content: "test content",
        filename: "test.xlsx",
        status: 'preview',
        type: 'UploadAssignmentCheckins'  # Old format without namespace
      )
      
      # Reload and verify it's properly recognized
      reloaded = UploadEvent.find(upload_event.id)
      expect(reloaded).to be_a(UploadEvent::UploadAssignmentCheckins)
    end

    it "handles type column migration correctly" do
      # Test that we can find records with both old and new type formats
      old_format = UploadEvent.create!(
        organization: organization,
        creator: creator,
        initiator: creator,
        file_content: "test content",
        filename: "test.xlsx",
        status: 'preview',
        type: 'UploadAssignmentCheckins'
      )
      
      new_format = UploadEvent.create!(
        organization: organization,
        creator: creator,
        initiator: creator,
        file_content: "test content",
        filename: "test.csv",
        status: 'preview',
        type: 'UploadEvent::UploadEmployees'
      )
      
      # Both should be loadable
      expect(UploadEvent.find(old_format.id)).to be_a(UploadEvent::UploadAssignmentCheckins)
      expect(UploadEvent.find(new_format.id)).to be_a(UploadEvent::UploadEmployees)
    end
  end
end
