require 'rails_helper'

RSpec.describe HuddleParticipant, type: :model do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  let(:huddle) do
    playbook = create(:huddle_playbook, organization: team)
    Huddle.create!(huddle_playbook: playbook, started_at: Time.current)
  end
  let(:person) { Person.create!(full_name: 'John Doe', email: 'john@example.com') }

  before do
    # Clear any existing test data
    Huddle.destroy_all
    Person.destroy_all
    Company.destroy_all
  end

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
      participant = HuddleParticipant.new(huddle: huddle, person: person, role: 'active')
      expect(participant.huddle).to eq(huddle)
    end

    it 'belongs to a person' do
      participant = HuddleParticipant.new(huddle: huddle, person: person, role: 'active')
      expect(participant.person).to eq(person)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      participant = HuddleParticipant.new(huddle: huddle, person: person, role: 'active')
      expect(participant).to be_valid
    end

    it 'requires a huddle' do
      participant = HuddleParticipant.new(person: person, role: 'active')
      expect(participant).not_to be_valid
      expect(participant.errors[:huddle]).to include('must exist')
    end

    it 'requires a person' do
      participant = HuddleParticipant.new(huddle: huddle, role: 'active')
      expect(participant).not_to be_valid
      expect(participant.errors[:person]).to include('must exist')
    end

    it 'requires a role' do
      participant = HuddleParticipant.new(huddle: huddle, person: person)
      expect(participant).not_to be_valid
      expect(participant.errors[:role]).to include("can't be blank")
    end

    it 'validates role is included in ROLES' do
      participant = HuddleParticipant.new(huddle: huddle, person: person, role: 'invalid_role')
      expect(participant).not_to be_valid
      expect(participant.errors[:role]).to include('is not included in the list')
    end

    it 'allows valid roles' do
      HuddleParticipant::ROLES.each do |role|
        participant = HuddleParticipant.new(huddle: huddle, person: person, role: role)
        expect(participant).to be_valid, "Role '#{role}' should be valid"
      end
    end

    it 'prevents duplicate participants for the same huddle and person' do
      HuddleParticipant.create!(huddle: huddle, person: person, role: 'active')
      duplicate = HuddleParticipant.new(huddle: huddle, person: person, role: 'observer')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:person_id]).to include('has already been taken')
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
    let!(:active_participant) { HuddleParticipant.create!(huddle: huddle, person: person, role: 'active') }
    let!(:observer_participant) { HuddleParticipant.create!(huddle: huddle, person: Person.create!(full_name: 'Jane', email: 'jane@example.com'), role: 'observer') }
    let!(:facilitator_participant) { HuddleParticipant.create!(huddle: huddle, person: Person.create!(full_name: 'Bob', email: 'bob@example.com'), role: 'facilitator') }

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