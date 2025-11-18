require 'rails_helper'

RSpec.describe SearchPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:pundit_user) { OpenStruct.new(user: teammate, impersonating_teammate: nil) }
  let(:policy) { SearchPolicy.new(pundit_user, :search) }

  describe '#index?' do
    it 'allows authenticated users' do
      expect(policy.index?).to be true
    end

    context 'with nil user' do
      let(:pundit_user) { nil }
      let(:policy) { SearchPolicy.new(pundit_user, :search) }

      it 'denies access' do
        expect(policy.index?).to be false
      end
    end
  end
end
