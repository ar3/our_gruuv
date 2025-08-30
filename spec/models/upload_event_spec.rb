require 'rails_helper'

RSpec.describe UploadEvent, type: :model do
  let(:person) { create(:person) }
  let(:upload_event) do
    build(:upload_event, 
          creator: person, 
          initiator: person,
          file_content: 'test content',
          preview_actions: { people: [] },
          results: { successes: [], failures: [] })
  end

  describe 'associations' do
    it 'belongs to creator person' do
      upload_event.creator = nil
      expect(upload_event).not_to be_valid
      expect(upload_event.errors[:creator]).to include('must exist')
    end

    it 'belongs to initiator person' do
      upload_event.initiator = nil
      expect(upload_event).not_to be_valid
      expect(upload_event.errors[:initiator]).to include('must exist')
    end
  end

  describe 'validations' do
    it 'requires status' do
      upload_event.status = nil
      expect(upload_event).not_to be_valid
      expect(upload_event.errors[:status]).to include("can't be blank")
    end

    it 'requires file_content' do
      upload_event.file_content = nil
      expect(upload_event).not_to be_valid
      expect(upload_event.errors[:file_content]).to include("can't be blank")
    end

    it 'allows valid status values' do
      %w[preview processing completed failed].each do |status|
        upload_event.status = status
        expect(upload_event).to be_valid
      end
    end

    it 'rejects invalid status values' do
      # Rails enums prevent invalid values from being set, so we test the validation differently
      expect { upload_event.status = 'invalid_status' }.to raise_error(ArgumentError)
    end
  end

  describe 'enums' do
    it 'defines status enum correctly' do
      expect(UploadEvent.statuses).to eq({
        'preview' => 'preview',
        'processing' => 'processing',
        'completed' => 'completed',
        'failed' => 'failed'
      })
    end
  end

  describe 'scopes' do
    let!(:recent_event) { create(:upload_event, creator: person, initiator: person, created_at: 1.day.ago) }
    let!(:old_event) { create(:upload_event, creator: person, initiator: person, created_at: 3.days.ago) }

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(UploadEvent.recent).to eq([recent_event, old_event])
      end
    end

    describe '.by_status' do
      it 'filters by status' do
        expect(UploadEvent.by_status('preview')).to include(recent_event)
      end
    end

    describe '.completed_or_failed' do
      let!(:completed_event) { create(:upload_event, creator: person, initiator: person, status: 'completed') }
      
      it 'includes completed and failed events' do
        expect(UploadEvent.completed_or_failed).to include(completed_event)
      end
    end
  end

  describe 'instance methods' do
    describe '#preview?' do
      it 'returns true when status is preview' do
        upload_event.status = 'preview'
        expect(upload_event.preview?).to be true
      end

      it 'returns false when status is not preview' do
        upload_event.status = 'completed'
        expect(upload_event.preview?).to be false
      end
    end

    describe '#processed?' do
      it 'returns true when status is completed' do
        upload_event.status = 'completed'
        expect(upload_event.processed?).to be true
      end

      it 'returns true when status is failed' do
        upload_event.status = 'failed'
        expect(upload_event.processed?).to be true
      end

      it 'returns false when status is preview' do
        upload_event.status = 'preview'
        expect(upload_event.processed?).to be false
      end
    end

    describe '#can_process?' do
      it 'returns true when preview with actions' do
        upload_event.status = 'preview'
        upload_event.preview_actions = { people: [] }
        expect(upload_event.can_process?).to be true
      end

      it 'returns false when not preview' do
        upload_event.status = 'completed'
        expect(upload_event.can_process?).to be false
      end
    end

    describe '#success_count' do
      it 'returns count of successful operations' do
        upload_event.results = { 'successes' => [{ id: 1 }, { id: 2 }] }
        expect(upload_event.success_count).to eq(2)
      end

      it 'returns 0 when no successes' do
        expect(upload_event.success_count).to eq(0)
      end

      it 'returns 0 when results is nil' do
        upload_event.results = nil
        expect(upload_event.success_count).to eq(0)
      end
    end

    describe '#failure_count' do
      it 'returns 0 when no failures' do
        expect(upload_event.failure_count).to eq(0)
      end

      it 'returns correct count when failures exist' do
        upload_event.results = { failures: [{ error: 'test' }, { error: 'test2' }] }
        expect(upload_event.failure_count).to eq(2)
      end
    end

    describe '#success_details_for' do
      it 'returns unknown record for invalid input' do
        expect(upload_event.success_details_for(nil)).to eq('Unknown record')
        expect(upload_event.success_details_for('not a hash')).to eq('Unknown record')
      end

      it 'formats person records correctly' do
        person_record = { 'type' => 'person', 'name' => 'John Doe' }
        expect(upload_event.success_details_for(person_record)).to eq('John Doe')
      end

      it 'formats assignment records correctly' do
        assignment_record = { 'type' => 'assignment', 'title' => 'Test Assignment' }
        expect(upload_event.success_details_for(assignment_record)).to eq('Test Assignment')
      end

      it 'formats assignment tenure records correctly' do
        tenure_record = { 
          'type' => 'assignment_tenure', 
          'person_name' => 'John Doe', 
          'assignment_title' => 'Test Assignment' 
        }
        expect(upload_event.success_details_for(tenure_record)).to eq('John Doe - Test Assignment')
      end

      it 'formats assignment check-in records correctly' do
        check_in_record = { 
          'type' => 'assignment_check_in', 
          'person_name' => 'John Doe', 
          'assignment_title' => 'Test Assignment' 
        }
        expect(upload_event.success_details_for(check_in_record)).to eq('John Doe - Test Assignment')
      end

      it 'formats external reference records correctly' do
        ref_record = { 
          'type' => 'external_reference', 
          'assignment_title' => 'Test Assignment', 
          'url' => 'https://example.com' 
        }
        expect(upload_event.success_details_for(ref_record)).to eq('Test Assignment (https://example.com)')
      end

      it 'handles missing data gracefully' do
        incomplete_record = { 'type' => 'person' }
        expect(upload_event.success_details_for(incomplete_record)).to eq('Unknown person')
        
        incomplete_tenure = { 'type' => 'assignment_tenure' }
        expect(upload_event.success_details_for(incomplete_tenure)).to eq('Unknown person - Unknown assignment')
      end

      it 'returns unknown type for unrecognized types' do
        unknown_record = { 'type' => 'unknown_type', 'data' => 'test' }
        expect(upload_event.success_details_for(unknown_record)).to eq('Unknown type')
      end
    end

    describe '#total_operations' do
      it 'returns sum of successes and failures' do
        upload_event.results = { 
          'successes' => [{ id: 1 }], 
          'failures' => [{ error: 'test' }] 
        }
        expect(upload_event.total_operations).to eq(2)
      end
    end

    describe '#has_failures?' do
      it 'returns true when there are failures' do
        upload_event.results = { 'failures' => [{ error: 'test' }] }
        expect(upload_event.has_failures?).to be true
      end

      it 'returns false when no failures' do
        expect(upload_event.has_failures?).to be false
      end
    end

    describe '#all_successful?' do
      it 'returns true when processed with no failures' do
        upload_event.status = 'completed'
        upload_event.results = { 'successes' => [{ id: 1 }], 'failures' => [] }
        expect(upload_event.all_successful?).to be true
      end

      it 'returns false when not processed' do
        upload_event.status = 'preview'
        expect(upload_event.all_successful?).to be false
      end
    end

    describe '#mark_as_processing!' do
      it 'updates status and attempted_at' do
        current_time = Time.current
        upload_event.mark_as_processing!
        expect(upload_event.status).to eq('processing')
        expect(upload_event.attempted_at).to be_within(1.second).of(current_time)
      end
    end

    describe '#mark_as_completed!' do
      it 'updates status, results, and attempted_at' do
        results_data = { 'successes' => [{ 'id' => 1 }] }
        current_time = Time.current
        upload_event.mark_as_completed!(results_data)
        expect(upload_event.status).to eq('completed')
        expect(upload_event.results).to eq(results_data)
        expect(upload_event.attempted_at).to be_within(1.second).of(current_time)
      end
    end

    describe '#mark_as_failed!' do
      it 'updates status, results with error, and attempted_at' do
        error_message = 'Something went wrong'
        current_time = Time.current
        upload_event.mark_as_failed!(error_message)
        expect(upload_event.status).to eq('failed')
        expect(upload_event.results).to eq({ 'error' => error_message })
        expect(upload_event.attempted_at).to be_within(1.second).of(current_time)
      end
    end
  end
end
