FactoryBot.define do
  factory :assignment_supply_relationship do
    transient do
      company { create(:organization, :company) }
    end

    supplier_assignment { association :assignment, company: company }
    consumer_assignment { association :assignment, company: company }
  end
end
