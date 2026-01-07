require 'rails_helper'

RSpec.describe CompanyTeammate, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:position) { create(:position) }

  describe '#active_employment_tenure' do
    it 'returns the active employment tenure for the teammate' do
      active_tenure = create(:employment_tenure, teammate: teammate, company: company, ended_at: nil)
      expect(teammate.active_employment_tenure).to eq(active_tenure)
      
      # End the active tenure
      active_tenure.update!(ended_at: 1.day.ago)
      teammate.reload
      expect(teammate.active_employment_tenure).to be_nil
    end

    it 'returns nil when there is no active employment tenure' do
      expect(teammate.active_employment_tenure).to be_nil
    end

    it 'only returns tenures for the teammate\'s organization' do
      other_company = create(:organization, :company)
      other_person = create(:person)
      other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
      
      active_tenure_for_company = create(:employment_tenure, teammate: teammate, company: company, ended_at: nil)
      active_tenure_for_other = create(:employment_tenure, teammate: other_teammate, company: other_company, ended_at: nil)

      expect(teammate.active_employment_tenure).to eq(active_tenure_for_company)
      expect(teammate.active_employment_tenure).not_to eq(active_tenure_for_other)
    end

    it 'returns nil when teammate has active tenure for different company' do
      other_company = create(:organization, :company)
      create(:employment_tenure, teammate: teammate, company: other_company, ended_at: nil)

      expect(teammate.active_employment_tenure).to be_nil
    end
  end
end

