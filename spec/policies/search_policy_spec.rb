require 'rails_helper'

RSpec.describe SearchPolicy, type: :policy do
  let(:user) { create(:person) }
  let(:policy) { SearchPolicy.new(user, :search) }

  describe '#index?' do
    it 'allows authenticated users' do
      expect(policy.index?).to be true
    end

    context 'with nil user' do
      let(:user) { nil }
      let(:policy) { SearchPolicy.new(user, :search) }

      it 'denies access' do
        expect(policy.index?).to be false
      end
    end
  end
end
