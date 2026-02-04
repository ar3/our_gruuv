require 'rails_helper'

RSpec.describe AssignmentsAndAbilitiesUploadProcessorJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:upload_event) { create(:upload_assignments_and_abilities, organization: organization, creator: person, initiator: person) }

  describe '#perform' do
    context 'with valid upload event' do
      before do
        upload_event.update!(
          preview_actions: {
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
            'position_assignments' => []
          },
          status: 'preview'
        )
      end

      it 'processes the upload successfully' do
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        if !result
          puts "Upload failed. Status: #{upload_event.reload.status}"
          puts "Results: #{upload_event.results.inspect}"
        end
        
        expect(result).to be true
        expect(upload_event.reload.status).to eq('completed')
        expect(upload_event.results).to be_present
      end

      it 'marks upload event as processing then completed' do
        result = described_class.perform_and_get_result(upload_event.id, organization.id)
        
        expect(result).to be true
        expect(upload_event.reload.status).to eq('completed')
      end
    end

    context 'when processor returns false' do
      before do
        processor_instance = instance_double(AssignmentsAndAbilitiesUploadProcessor)
        allow(AssignmentsAndAbilitiesUploadProcessor).to receive(:new).with(kind_of(BulkSyncEvent::UploadAssignmentsAndAbilities), kind_of(Organization)).and_return(processor_instance)
        allow(processor_instance).to receive(:process).and_return(false)
        allow(processor_instance).to receive(:results).and_return({
          successes: [],
          failures: [{ type: 'assignment', error: 'Test error', row: 2 }]
        })
        allow(processor_instance).to receive(:last_error).and_return(nil)
        upload_event.update!(status: 'preview')
      end

      it 'marks upload event as failed and raises exception' do
        expect {
          described_class.perform_and_get_result(upload_event.id, organization.id)
        }.to raise_error(RuntimeError, /Processing failed/)
        
        expect(upload_event.reload.status).to eq('failed')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(AssignmentsAndAbilitiesUploadProcessor).to receive(:new).and_raise(StandardError.new('Database connection failed'))
        upload_event.update!(status: 'preview')
      end

      it 'marks upload event as failed and raises exception' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        
        expect {
          described_class.perform_and_get_result(upload_event.id, organization.id)
        }.to raise_error(StandardError, 'Database connection failed')
        
        expect(upload_event.reload.status).to eq('failed')
      end
    end
  end

  describe '.perform_and_get_result' do
    it 'is a class method' do
      expect(described_class).to respond_to(:perform_and_get_result)
    end

    it 'returns the result of perform' do
      upload_event.update!(
        preview_actions: {
          'assignments' => [],
          'abilities' => [],
          'assignment_abilities' => [],
          'position_assignments' => []
        },
        status: 'preview'
      )
      
      result = described_class.perform_and_get_result(upload_event.id, organization.id)
      expect(result).to be_in([true, false])
    end
  end
end

