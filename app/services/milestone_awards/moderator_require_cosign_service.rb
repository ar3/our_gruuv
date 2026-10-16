# frozen_string_literal: true

module MilestoneAwards
  # Undo a skipped award until a real co-sign happens: remove TeammateMilestone
  # children (and their celebration ObservableMoments). Awarder cannot skip again
  # on this attempt.
  class ModeratorRequireCosignService
    def self.call(...) = new(...).call

    def initialize(milestone_award:, moderator_teammate:)
      @award = milestone_award
      @moderator_teammate = moderator_teammate
    end

    def call
      unless MilestoneAwards::ModeratorAuthorization.can_moderate?(
        teammate: @moderator_teammate,
        milestone_award: @award
      )
        return Result.err("Not authorized to moderate this award.")
      end

      return Result.err("Only skipped awards awaiting moderation can be reversed.") unless @award.skipped_awaiting_moderation?

      ApplicationRecord.transaction do
        @award.update!(
          moderator_requires_cosign_at: Time.current,
          moderator_teammate: @moderator_teammate
        )

        # Existence = official. Tear down skip-created milestones (and OMs via
        # TeammateMilestone has_one :observable_moment, dependent: :destroy).
        # Cosign recreates the bundle via ApplyMilestonesService.
        @award.teammate_milestones.find_each(&:destroy!)

        Result.ok(@award.reload)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    rescue ActiveRecord::RecordNotDestroyed => e
      Result.err(e.message)
    end
  end
end
