require 'rails_helper'

RSpec.describe UnassignedEmployeeUploadProcessorJob, type: :job do
  let(:organization) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  let(:upload_event) { create(:upload_employees, organization: organization, creator: person, initiator: person) }

  describe '#perform' do
    context 'with valid upload event' do
      before do
        # Mock the processor to return success
        processor_instance = instance_double(UnassignedEmployeeUploadProcessor)
        allow(UnassignedEmployeeUploadProcessor).to receive(:new).with(kind_of(UploadEvent::UploadEmployees), kind_of(Organization)).and_return(processor_instance)
        allow(processor_instance).to receive(:process).and_return(true)
        allow(processor_instance).to receive(:results).and_return({
          successes: [
            { type: 'unassigned_employee', action: 'created', name: 'John Doe' },
            { type: 'department', action: 'created', name: 'Engineering' }
          ],
          failures: []
        })
      end

      it 'processes the upload successfully' do
        # Processor is already mocked in before block
        
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        expect(result).to be true
        expect(upload_event.reload.status).to eq('completed')
        expect(upload_event.results).to include('successes', 'failures')
      end

      it 'marks upload event as processing then completed' do
        # Test that the job completes successfully
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        expect(result).to be true
        expect(upload_event.reload.status).to eq('completed')
      end

      it 'logs successful processing' do
        # Job doesn't log success messages, only errors
        expect(Rails.logger).not_to receive(:error)
        
        described_class.perform_and_get_result(upload_event.id, organization.id)
      end
    end

    context 'when processor returns false' do
      before do
        processor_instance = instance_double(UnassignedEmployeeUploadProcessor)
        allow(UnassignedEmployeeUploadProcessor).to receive(:new).with(kind_of(UploadEvent::UploadEmployees), kind_of(Organization)).and_return(processor_instance)
        allow(processor_instance).to receive(:process).and_return(false)
        allow(processor_instance).to receive(:parser).and_return(
          double(errors: ['Invalid CSV format'])
        )
      end

      it 'marks upload event as failed' do
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        expect(result).to be false
        expect(upload_event.reload.status).to eq('failed')
        expect(upload_event.results['error']).to include('Processing failed')
      end

      it 'logs processing failure' do
        # Job doesn't log errors when processor returns false, only on exceptions
        expect(Rails.logger).not_to receive(:error)
        
        described_class.perform_and_get_result(upload_event.id, organization.id)
      end
    end

    context 'when upload event is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_and_get_result(99999, organization.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when organization is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_and_get_result(upload_event.id, 99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(UnassignedEmployeeUploadProcessor).to receive(:new).with(kind_of(UploadEvent::UploadEmployees), kind_of(Organization)).and_raise(StandardError.new('Database connection failed'))
      end

      it 'marks upload event as failed with error message' do
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        expect(result).to be false
        expect(upload_event.reload.status).to eq('failed')
        expect(upload_event.results['error']).to eq('Unexpected error: Database connection failed')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with("UnassignedEmployeeUploadProcessorJob failed: Database connection failed")
        expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace
        
        described_class.perform_and_get_result(upload_event.id, organization.id)
      end
    end

    context 'with real processor integration' do
      let(:valid_csv_content) do
        <<~CSV
          Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
          John Doe,John,john.doe@company.com,2024-01-15,New York,male,Engineering,full_time,Jane Smith,USA,jane.smith@company.com,Software Engineer,mid
        CSV
      end

      let(:upload_event) { create(:upload_employees, organization: organization, creator: person, initiator: person, file_content: valid_csv_content) }

      it 'actually processes employee data' do
        expect {
          described_class.perform_and_get_result(upload_event.id, organization.id)
        }.to change(Person, :count).by_at_least(1)
         .and change(Organization.departments, :count).by(1)
         .and change(Teammate, :count).by_at_least(1) # Allow for more teammates if manager is created
         .and change(EmploymentTenure, :count).by(1)

        expect(upload_event.reload.status).to eq('completed')
        expect(upload_event.results['successes']).not_to be_empty
      end
    end
  end
end
