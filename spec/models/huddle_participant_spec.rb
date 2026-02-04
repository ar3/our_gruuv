require 'rails_helper'

RSpec.describe HuddleParticipant, type: :model do
  let(:company) { create(:organization, :company) }
  let(:team) { create(:team, company: company) }
  let(:huddle) { create(:huddle, team: team) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  describe 'constants' do
    it 'defines ROLES constant' do
      expect(HuddleParticipant::ROLES).to be_an(Array)
      expect(HuddleParticipant::ROLES).to include('active', 'observer', 'facilitator')
    end

    it 'defines ROLE_LABELS constant' do
      expect(HuddleParticipant::ROLE_LABELS).to be_a(Hash)
      expect(HuddleParticipant::ROLE_LABELS['active']).to eq('Active Participant')
      expect(HuddleParticipant::ROLE_LABELS['observer']).to eq('Observer')
      expect(HuddleParticipant::ROLE_LABELS['facilitator']).to eq('Facilitator')
    end
  end

  describe 'associations' do
    it 'belongs to a huddle' do
      participant = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: 'active')
      expect(participant.huddle).to eq(huddle)
    end

    it 'belongs to a teammate' do
      participant = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: 'active')
      expect(participant.teammate).to eq(teammate)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      participant = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: 'active')
      expect(participant).to be_valid
    end

    it 'requires a huddle' do
      participant = HuddleParticipant.new(teammate: teammate, role: 'active')
      expect(participant).not_to be_valid
      expect(participant.errors[:huddle]).to include('must exist')
    end

    it 'requires a teammate' do
      participant = HuddleParticipant.new(huddle: huddle, role: 'active')
      expect(participant).not_to be_valid
      expect(participant.errors[:company_teammate]).to include('must exist')
    end

    it 'requires a role' do
      participant = HuddleParticipant.new(huddle: huddle, teammate: teammate)
      expect(participant).not_to be_valid
      expect(participant.errors[:role]).to include("can't be blank")
    end

    it 'validates role is included in ROLES' do
      participant = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: 'invalid_role')
      expect(participant).not_to be_valid
      expect(participant.errors[:role]).to include('is not included in the list')
    end

    it 'allows valid roles' do
      HuddleParticipant::ROLES.each do |role|
        participant = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: role)
        expect(participant).to be_valid, "Role '#{role}' should be valid"
      end
    end

    it 'prevents duplicate participants for the same huddle and teammate' do
      HuddleParticipant.create!(huddle: huddle, teammate: teammate, role: 'active')
      duplicate = HuddleParticipant.new(huddle: huddle, teammate: teammate, role: 'observer')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:teammate_id]).to include('has already been taken')
    end
  end

  describe 'role_label' do
    it 'returns the human-readable label for the role' do
      participant = HuddleParticipant.new(role: 'active')
      expect(participant.role_label).to eq('Active Participant')
    end

    it 'returns the role titleized for invalid roles' do
      participant = HuddleParticipant.new(role: 'invalid')
      expect(participant.role_label).to eq('Invalid')
    end
  end

  describe 'scopes' do
    let!(:active_participant) { HuddleParticipant.create!(huddle: huddle, teammate: teammate, role: 'active') }
    let!(:observer_participant) { 
      person2 = Person.create!(full_name: 'Jane', email: 'jane@example.com')
      teammate2 = CompanyTeammate.create!(person: person2, organization: company)
      HuddleParticipant.create!(huddle: huddle, teammate: teammate2, role: 'observer') 
    }
    let!(:facilitator_participant) { 
      person3 = Person.create!(full_name: 'Bob', email: 'bob@example.com')
      teammate3 = CompanyTeammate.create!(person: person3, organization: company)
      HuddleParticipant.create!(huddle: huddle, teammate: teammate3, role: 'facilitator') 
    }

    describe '.active_participants' do
      it 'returns only active participants' do
        expect(HuddleParticipant.active_participants).to include(active_participant)
        expect(HuddleParticipant.active_participants).not_to include(observer_participant, facilitator_participant)
      end
    end

    describe '.facilitators' do
      it 'returns only facilitator participants' do
        expect(HuddleParticipant.facilitators).to include(facilitator_participant)
        expect(HuddleParticipant.facilitators).not_to include(active_participant, observer_participant)
      end
    end
  end
end 