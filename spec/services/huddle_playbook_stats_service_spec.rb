require 'rails_helper'

RSpec.describe Huddles::PlaybookStatsService do
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }
  let(:service) { described_class.new(huddle_playbook) }

  describe '#participant_statistics' do
    it 'returns empty array when no participants' do
      expect(service.participant_statistics).to eq([])
    end

    it 'returns participant statistics for single participant' do
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.days.ago)
      
      participant = create(:person, first_name: 'John', last_name: 'Doe')
      participant_teammate = create(:teammate, person: participant, organization: organization)
      create(:huddle_participant, huddle: huddle1, teammate: participant_teammate)
      create(:huddle_participant, huddle: huddle2, teammate: participant_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: participant_teammate)
      
      stats = service.participant_statistics
      
      expect(stats.length).to eq(1)
      expect(stats.first.person_id).to eq(participant.id)
      expect(stats.first.first_name).to eq('John')
      expect(stats.first.last_name).to eq('Doe')
      expect(stats.first.huddle_count).to eq(2)
      expect(stats.first.feedback_count).to eq(1)
      expect(stats.first.first_huddle_date).to eq(huddle1.started_at)
      expect(stats.first.last_huddle_date).to eq(huddle2.started_at)
    end

    it 'returns statistics for multiple participants' do
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.days.ago)
      
      participant1 = create(:person, first_name: 'John', last_name: 'Doe')
      participant2 = create(:person, first_name: 'Jane', last_name: 'Smith')
      participant1_teammate = create(:teammate, person: participant1, organization: organization)
      participant2_teammate = create(:teammate, person: participant2, organization: organization)
      
      create(:huddle_participant, huddle: huddle1, teammate: participant1_teammate)
      create(:huddle_participant, huddle: huddle2, teammate: participant1_teammate)
      create(:huddle_participant, huddle: huddle1, teammate: participant2_teammate)
      
      create(:huddle_feedback, huddle: huddle1, teammate: participant1_teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: participant1_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: participant2_teammate)
      
      stats = service.participant_statistics
      
      expect(stats.length).to eq(2)
      
      participant1_stat = stats.find { |s| s.person_id == participant1.id }
      participant2_stat = stats.find { |s| s.person_id == participant2.id }
      
      expect(participant1_stat.huddle_count).to eq(2)
      expect(participant1_stat.feedback_count).to eq(2)
      expect(participant2_stat.huddle_count).to eq(1)
      expect(participant2_stat.feedback_count).to eq(1)
      
      # Test that participants are sorted by name
      expect(stats.first.first_name).to eq('Jane') # Jane comes before John alphabetically
      expect(stats.first.last_name).to eq('Smith')
      expect(stats.last.first_name).to eq('John')
      expect(stats.last.last_name).to eq('Doe')
    end

    it 'does not show duplicate participants' do
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.days.ago)
      
      participant = create(:person, first_name: 'John', last_name: 'Doe')
      participant_teammate = create(:teammate, person: participant, organization: organization)
      
      # Same participant in multiple huddles with multiple feedbacks
      create(:huddle_participant, huddle: huddle1, teammate: participant_teammate)
      create(:huddle_participant, huddle: huddle2, teammate: participant_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: participant_teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: participant_teammate)
      
      stats = service.participant_statistics
      
      expect(stats.length).to eq(1)
      expect(stats.first.person_id).to eq(participant.id)
      expect(stats.first.huddle_count).to eq(2)
      expect(stats.first.feedback_count).to eq(2)
    end

    it 'handles complex scenario with multiple huddles and participants without duplicates' do
      # Create multiple huddles
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.weeks.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle3 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 3.days.ago)
      huddle4 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.day.ago)
      
      # Create participants
      alice = create(:person, first_name: 'Alice', last_name: 'Anderson')
      bob = create(:person, first_name: 'Bob', last_name: 'Brown')
      charlie = create(:person, first_name: 'Charlie', last_name: 'Clark')
      diana = create(:person, first_name: 'Diana', last_name: 'Davis')
      alice_teammate = create(:teammate, person: alice, organization: organization)
      bob_teammate = create(:teammate, person: bob, organization: organization)
      charlie_teammate = create(:teammate, person: charlie, organization: organization)
      diana_teammate = create(:teammate, person: diana, organization: organization)
      
      # Alice joins all huddles and gives feedback to all
      create(:huddle_participant, huddle: huddle1, teammate: alice_teammate)
      create(:huddle_participant, huddle: huddle2, teammate: alice_teammate)
      create(:huddle_participant, huddle: huddle3, teammate: alice_teammate)
      create(:huddle_participant, huddle: huddle4, teammate: alice_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: alice_teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: alice_teammate)
      create(:huddle_feedback, huddle: huddle3, teammate: alice_teammate)
      create(:huddle_feedback, huddle: huddle4, teammate: alice_teammate)
      
      # Bob joins huddles 1, 2, and 4, gives feedback to 1 and 2
      create(:huddle_participant, huddle: huddle1, teammate: bob_teammate)
      create(:huddle_participant, huddle: huddle2, teammate: bob_teammate)
      create(:huddle_participant, huddle: huddle4, teammate: bob_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: bob_teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: bob_teammate)
      
      # Charlie joins huddles 1 and 3, gives feedback to 1
      create(:huddle_participant, huddle: huddle1, teammate: charlie_teammate)
      create(:huddle_participant, huddle: huddle3, teammate: charlie_teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: charlie_teammate)
      
      # Diana joins only huddle 2, gives feedback
      create(:huddle_participant, huddle: huddle2, teammate: diana_teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: diana_teammate)
      
      stats = service.participant_statistics
      
      # Should have exactly 4 unique participants
      expect(stats.length).to eq(4)
      
      # Check each participant's stats
      alice_stat = stats.find { |s| s.person_id == alice.id }
      bob_stat = stats.find { |s| s.person_id == bob.id }
      charlie_stat = stats.find { |s| s.person_id == charlie.id }
      diana_stat = stats.find { |s| s.person_id == diana.id }
      
      expect(alice_stat.huddle_count).to eq(4)
      expect(alice_stat.feedback_count).to eq(4)
      
      expect(bob_stat.huddle_count).to eq(3)
      expect(bob_stat.feedback_count).to eq(2)
      
      expect(charlie_stat.huddle_count).to eq(2)
      expect(charlie_stat.feedback_count).to eq(1)
      
      expect(diana_stat.huddle_count).to eq(1)
      expect(diana_stat.feedback_count).to eq(1)
      
      # Verify no duplicates by checking unique person_ids
      person_ids = stats.map(&:person_id)
      expect(person_ids.uniq.length).to eq(person_ids.length)
      
      # Verify sorting (alphabetical by first name)
      expect(stats.map(&:first_name)).to eq(['Alice', 'Bob', 'Charlie', 'Diana'])
    end


  end
end 