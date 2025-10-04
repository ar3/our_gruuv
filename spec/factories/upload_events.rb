FactoryBot.define do
  factory :upload_event do
    type { 'UploadEvent::UploadAssignmentCheckins' }
    filename { "test_upload.xlsx" }
    file_content { "test file content" }
    preview_actions { { people: [], assignments: [] } }
    results { { successes: [], failures: [] } }
    status { 'preview' }
    
    association :creator, factory: :person
    association :initiator, factory: :person
    association :organization, factory: :organization

    factory :upload_assignment_checkins, class: 'UploadEvent::UploadAssignmentCheckins' do
      filename { "test_upload.xlsx" }
      file_content { "test xlsx content" }
    end

    factory :upload_employees, class: 'UploadEvent::UploadEmployees' do
      type { 'UploadEvent::UploadEmployees' }
      filename { "test_upload.csv" }
      file_content { "test csv content" }
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
