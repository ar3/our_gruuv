# frozen_string_literal: true

FactoryBot.define do
  factory :document_link do
    association :document
    association :linkable, factory: :assignment

    after(:build) do |link|
      if link.document && link.linkable.is_a?(Assignment) && link.linkable.company_id != link.document.organization_id
        link.linkable = create(:assignment, company: link.document.organization)
      end
    end
  end
end
