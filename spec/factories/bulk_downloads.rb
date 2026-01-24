FactoryBot.define do
  factory :bulk_download do
    association :company, factory: :organization, strategy: :create
    association :downloaded_by, factory: :company_teammate, strategy: :create, organization: :company
    download_type { 'assignments' }
    s3_key { "bulk-downloads/#{company.id}/assignments/test_file_#{Time.current.to_i}.csv" }
    s3_url { "https://bulk-downloads.ourgruuv.com.s3.us-east-1.amazonaws.com/#{s3_key}" }
    filename { "assignments_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    file_size { 1024 }

    trait :company_teammates do
      download_type { 'company_teammates' }
      s3_key { "bulk-downloads/#{company.id}/company_teammates/test_file_#{Time.current.to_i}.csv" }
      filename { "company_teammates_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :assignments do
      download_type { 'assignments' }
      s3_key { "bulk-downloads/#{company.id}/assignments/test_file_#{Time.current.to_i}.csv" }
      filename { "assignments_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :abilities do
      download_type { 'abilities' }
      s3_key { "bulk-downloads/#{company.id}/abilities/test_file_#{Time.current.to_i}.csv" }
      filename { "abilities_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :positions do
      download_type { 'positions' }
      s3_key { "bulk-downloads/#{company.id}/positions/test_file_#{Time.current.to_i}.csv" }
      filename { "positions_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :seats do
      download_type { 'seats' }
      s3_key { "bulk-downloads/#{company.id}/seats/test_file_#{Time.current.to_i}.csv" }
      filename { "seats_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :titles do
      download_type { 'titles' }
      s3_key { "bulk-downloads/#{company.id}/titles/test_file_#{Time.current.to_i}.csv" }
      filename { "titles_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end

    trait :departments_and_teams do
      download_type { 'departments_and_teams' }
      s3_key { "bulk-downloads/#{company.id}/departments_and_teams/test_file_#{Time.current.to_i}.csv" }
      filename { "departments_and_teams_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
    end
  end
end
