require 'ostruct'

module Huddles
  class PlaybookStatsService
    def initialize(huddle_playbook)
      @huddle_playbook = huddle_playbook
    end

    def participant_statistics
      @participant_stats ||= calculate_participant_statistics
    end

    private

    attr_reader :huddle_playbook

    def calculate_participant_statistics
      # Get distinct participants
      participant_ids = huddle_playbook.huddles
        .joins(:huddle_participants)
        .distinct
        .pluck('huddle_participants.teammate_id').uniq
      
      participant_ids.map do |teammate_id|
        teammate = Teammate.find(teammate_id)
        person = teammate.person
        
        # Get huddles for this teammate
        person_huddles = huddle_playbook.huddles
          .joins(:huddle_participants)
          .where(huddle_participants: { teammate_id: teammate_id })
        
        # Get feedback count for this teammate
        feedback_count = HuddleFeedback
          .joins(:huddle)
          .where(huddles: { huddle_playbook: huddle_playbook })
          .where(teammate_id: teammate_id)
          .count
        
        OpenStruct.new(
          person_id: person.id,
          first_name: person.first_name,
          last_name: person.last_name,
          email: person.email,
          huddle_count: person_huddles.count,
          feedback_count: feedback_count,
          first_huddle_date: person_huddles.minimum(:started_at),
          last_huddle_date: person_huddles.maximum(:started_at)
        )
      end.sort_by { |stat| [stat.first_name, stat.last_name] }
    end
  end
end 