# frozen_string_literal: true

FactoryBot.define do
  factory :title_path do
    association :from_title, factory: :title
    transient do
      company { from_title.company }
    end
    to_title { association :title, company: company, position_major_level: from_title.position_major_level }
    path_type { "natural_progression" }
  end
end
