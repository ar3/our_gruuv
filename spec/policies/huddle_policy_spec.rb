require 'rails_helper'

RSpec.describe HuddlePolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization) }
  let(:huddle) { create(:huddle, organization: organization) }
  let(:person) { create(:person) }
  let(:facilitator) { create(:person) }
  let(:participant) { create(:person) }

  before do
    create(:huddle_participant, huddle: huddle, person: facilitator, role: 'facilitator')
    create(:huddle_participant, huddle: huddle, person: participant, role: 'active')
  end

  permissions :show? do
    it "allows anyone to view a huddle" do
      expect(subject).to permit(person, huddle)
    end
  end

  permissions :create? do
    it "allows anyone to create a huddle" do
      expect(subject).to permit(person, Huddle.new)
    end
  end

  permissions :update? do
    it "allows facilitators to update huddle" do
      expect(subject).to permit(facilitator, huddle)
    end

    it "denies regular participants from updating huddle" do
      expect(subject).not_to permit(participant, huddle)
    end

    it "denies non-participants from updating huddle" do
      expect(subject).not_to permit(person, huddle)
    end
  end

  permissions :destroy? do
    it "allows facilitators to destroy huddle" do
      expect(subject).to permit(facilitator, huddle)
    end

    it "denies regular participants from destroying huddle" do
      expect(subject).not_to permit(participant, huddle)
    end

    it "denies non-participants from destroying huddle" do
      expect(subject).not_to permit(person, huddle)
    end
  end

  permissions :join? do
    it "allows anyone to join a huddle" do
      expect(subject).to permit(person, huddle)
    end
  end

  permissions :join_huddle? do
    it "allows anyone to join a huddle" do
      expect(subject).to permit(person, huddle)
    end
  end

  permissions :feedback? do
    it "allows participants to access feedback" do
      expect(subject).to permit(participant, huddle)
    end

    it "allows facilitators to access feedback" do
      expect(subject).to permit(facilitator, huddle)
    end

    it "denies non-participants from accessing feedback" do
      expect(subject).not_to permit(person, huddle)
    end
  end

  permissions :submit_feedback? do
    it "allows participants to submit feedback" do
      expect(subject).to permit(participant, huddle)
    end

    it "allows facilitators to submit feedback" do
      expect(subject).to permit(facilitator, huddle)
    end

    it "denies non-participants from submitting feedback" do
      expect(subject).not_to permit(person, huddle)
    end
  end

  permissions :summary? do
    it "allows participants to view summary" do
      expect(subject).to permit(participant, huddle)
    end

    it "allows facilitators to view summary" do
      expect(subject).to permit(facilitator, huddle)
    end

    it "denies non-participants from viewing summary" do
      expect(subject).not_to permit(person, huddle)
    end
  end

  describe "scope" do
    let(:organization2) { create(:organization, name: 'Test Org 2') }
    let!(:huddle1) { create(:huddle, organization: organization) }
    let!(:huddle2) { create(:huddle, organization: organization2) }
    let!(:participant1) { create(:huddle_participant, huddle: huddle1, person: person, role: 'active') }

    context "when user is logged in" do
      it "shows only huddles the user participated in" do
        scope = HuddlePolicy::Scope.new(person, Huddle).resolve
        expect(scope).to include(huddle1)
        expect(scope).not_to include(huddle2)
      end
    end

    context "when user is not logged in" do
      it "shows only active huddles" do
        scope = HuddlePolicy::Scope.new(nil, Huddle).resolve
        expect(scope).to include(huddle1)
        expect(scope).to include(huddle2)
      end
    end
  end
end
