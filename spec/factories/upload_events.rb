FactoryBot.define do
  factory :upload_event do
    filename { "test_upload.xlsx" }
    file_content { "test file content" }
    preview_actions { { people: [], assignments: [] } }
    results { { successes: [], failures: [] } }
    status { 'preview' }
    
    association :creator, factory: :person
    association :initiator, factory: :person
    association :organization, factory: :organization
    
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
