FactoryBot.define do
  factory :upload_event, class: 'BulkSyncEvent' do
    type { 'BulkSyncEvent::UploadAssignmentCheckins' }
    filename { "test_upload.xlsx" }
    source_contents { "test file content" }
    source_data { { type: 'file_upload', filename: "test_upload.xlsx", file_size: 100, uploaded_at: Time.current } }
    results { { successes: [], failures: [] } }
    status { 'preview' }
    
    association :creator, factory: :person
    association :initiator, factory: :person
    association :organization, factory: :organization

    factory :upload_assignment_checkins, class: 'BulkSyncEvent::UploadAssignmentCheckins' do
      filename { "test_upload.xlsx" }
      source_contents { "test xlsx content" }
      source_data { { type: 'file_upload', filename: "test_upload.xlsx", file_size: 100, uploaded_at: Time.current } }
    end

    factory :upload_employees, class: 'BulkSyncEvent::UploadEmployees' do
      type { 'BulkSyncEvent::UploadEmployees' }
      filename { "test_upload.csv" }
      source_contents { "test csv content" }
      source_data { { type: 'file_upload', filename: "test_upload.csv", file_size: 100, uploaded_at: Time.current } }
    end

    factory :upload_assignments_and_abilities, class: 'BulkSyncEvent::UploadAssignmentsAndAbilities' do
      type { 'BulkSyncEvent::UploadAssignmentsAndAbilities' }
      filename { "test_upload.csv" }
      source_contents { "test csv content" }
      source_data { { type: 'file_upload', filename: "test_upload.csv", file_size: 100, uploaded_at: Time.current } }
    end
    
    trait :processing do
      status { 'processing' }
      attempted_at { Time.current }
    end
    
    trait :completed do
      status { 'completed' }
      attempted_at { Time.current }
      results { { 
        successes: [
          { type: 'person', id: 1, action: 'created', name: 'John Doe' },
          { type: 'assignment', id: 1, action: 'created', title: 'Software Engineer' }
        ], 
        failures: [] 
      } }
    end
    
    trait :failed do
      status { 'failed' }
      attempted_at { Time.current }
      results { { error: 'Something went wrong during processing' } }
    end
  end
end
