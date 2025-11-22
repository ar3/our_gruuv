FactoryBot.define do
  factory :prompt_answer do
    association :prompt
    association :prompt_question
    text { "This is my answer to the question." }
    updated_by_company_teammate { CompanyTeammate.create!(person: create(:person), organization: create(:organization, :company)) }
  end
end

