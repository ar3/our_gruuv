require 'rails_helper'

RSpec.describe HuddlePolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization)) }
  let(:person) { create(:person) }
  let(:facilitator) { create(:person) }
  let(:participant) { create(:person) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:facilitator_teammate) { CompanyTeammate.create!(person: facilitator, organization: organization) }
  let(:participant_teammate) { CompanyTeammate.create!(person: participant, organization: organization) }
  
  let(:pundit_user) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_facilitator) { OpenStruct.new(user: facilitator_teammate, impersonating_teammate: nil) }
  let(:pundit_user_participant) { OpenStruct.new(user: participant_teammate, impersonating_teammate: nil) }

  before do
    create(:huddle_participant, huddle: huddle, teammate: facilitator_teammate, role: 'facilitator')
    create(:huddle_participant, huddle: huddle, teammate: participant_teammate, role: 'active')
  end

  permissions :show? do
    it "allows anyone to view a huddle" do
      expect(subject).to permit(pundit_user, huddle)
    end
  end

  permissions :create? do
    it "allows anyone to create a huddle" do
      expect(subject).to permit(pundit_user, Huddle.new)
    end
  end

  permissions :update? do
    it "allows facilitators to update huddle" do
      expect(subject).to permit(pundit_user_facilitator, huddle)
    end

    it "denies regular participants from updating huddle" do
      expect(subject).not_to permit(pundit_user_participant, huddle)
    end

    it "denies non-participants from updating huddle" do
      expect(subject).not_to permit(pundit_user, huddle)
    end
  end

  permissions :destroy? do
    it "allows facilitators to destroy huddle" do
      expect(subject).to permit(pundit_user_facilitator, huddle)
    end

    it "denies regular participants from destroying huddle" do
      expect(subject).not_to permit(pundit_user_participant, huddle)
    end

    it "denies non-participants from destroying huddle" do
      expect(subject).not_to permit(pundit_user, huddle)
    end
  end

  permissions :join? do
    it "allows anyone to join a huddle" do
      expect(subject).to permit(pundit_user, huddle)
    end
  end

  permissions :join_huddle? do
    it "allows anyone to join a huddle" do
      expect(subject).to permit(pundit_user, huddle)
    end
  end

  permissions :feedback? do
    it "allows participants to access feedback" do
      expect(subject).to permit(pundit_user_participant, huddle)
    end

    it "allows facilitators to access feedback" do
      expect(subject).to permit(pundit_user_facilitator, huddle)
    end

    it "denies non-participants from accessing feedback" do
      expect(subject).not_to permit(pundit_user, huddle)
    end
  end

  permissions :submit_feedback? do
    it "allows participants to submit feedback" do
      expect(subject).to permit(pundit_user_participant, huddle)
    end

    it "allows facilitators to submit feedback" do
      expect(subject).to permit(pundit_user_facilitator, huddle)
    end

    it "denies non-participants from submitting feedback" do
      expect(subject).not_to permit(pundit_user, huddle)
    end
  end



  describe "scope" do
    let(:organization2) { create(:organization, name: 'Test Org 2') }
    let!(:huddle1) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization)) }
    let!(:huddle2) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization2)) }
    let!(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
    let!(:participant1) { create(:huddle_participant, huddle: huddle1, teammate: person_teammate, role: 'active') }
    let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }

    context "when user is logged in" do
      it "shows only huddles the user participated in" do
        scope = HuddlePolicy::Scope.new(pundit_user_person, Huddle).resolve
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
