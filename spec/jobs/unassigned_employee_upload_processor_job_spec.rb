require 'rails_helper'

RSpec.describe UnassignedEmployeeUploadProcessorJob, type: :job do
  let(:organization) { create(:organization, type: 'Company') }
  let(:upload_event) { create(:upload_event, organization: organization) }

  describe '#perform' do
    let(:valid_csv_content) do
      <<~CSV
        Name,Email,Start Date,Department
        John Doe,john.doe@company.com,2024-01-15,Engineering
        Jane Smith,jane.smith@company.com,2024-01-10,Engineering
      CSV
    end

    let(:upload_event) { create(:upload_event, organization: organization, file_content: valid_csv_content) }

    context 'with valid data' do
      it 'processes successfully' do
        expect { described_class.perform_now(upload_event.id, organization.id) }.to change(Person, :count).by(2)
      end

      it 'marks upload event as completed' do
        described_class.perform_now(upload_event.id, organization.id)
        
        upload_event.reload
        expect(upload_event.status).to eq('completed')
        expect(upload_event.results).to be_present
      end

      it 'includes success results' do
        described_class.perform_now(upload_event.id, organization.id)
        
        upload_event.reload
        expect(upload_event.results['successes']).not_to be_empty
        expect(upload_event.results['failures']).to be_empty
      end
    end

    context 'with invalid data' do
      let(:invalid_csv_content) do
        <<~CSV
          Invalid Header,Another Header
          Value1,Value2
        CSV
      end

      let(:upload_event) { create(:upload_event, organization: organization, file_content: invalid_csv_content) }

      it 'marks upload event as failed' do
        described_class.perform_now(upload_event.id, organization.id)
        
        upload_event.reload
        expect(upload_event.status).to eq('failed')
        expect(upload_event.results['error']).to be_present
      end
    end

    context 'with processing errors' do
      before do
        allow_any_instance_of(UnassignedEmployeeUploadProcessor).to receive(:process).and_raise(StandardError.new('Processing failed'))
      end

      it 'marks upload event as failed' do
        described_class.perform_now(upload_event.id, organization.id)
        
        upload_event.reload
        expect(upload_event.status).to eq('failed')
        expect(upload_event.results['error']).to include('Unexpected error: Processing failed')
      end
    end

    context 'with missing upload event' do
      it 'handles missing upload event gracefully' do
        expect { described_class.perform_now(999999, organization.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with missing organization' do
      it 'handles missing organization gracefully' do
        expect { described_class.perform_now(upload_event.id, 999999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
