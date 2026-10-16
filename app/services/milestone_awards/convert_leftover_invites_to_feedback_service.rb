# frozen_string_literal: true

module MilestoneAwards
  # After the first co-sign, remaining open invites become a normal feedback request.
  class ConvertLeftoverInvitesToFeedbackService
    def self.call(...) = new(...).call

    def initialize(milestone_award:)
      @award = milestone_award
    end

    def call
      leftovers = @award.cosign_invites.open.where.not(invitee_teammate_id: @award.cosigning_teammate_id)
      return Result.ok(@award) if leftovers.empty?

      company = @award.organization.root_company || @award.organization
      recipient = @award.teammate
      level = @award.official_milestone_level
      ability = @award.ability

      fr = FeedbackRequest.new(
        company: company,
        subject_of_feedback_teammate: recipient,
        subject_line: "Feedback on #{recipient.person.display_name}'s #{ability.display_name} (Milestone #{level})",
        open_to_anyone: false
      )

      result = FeedbackRequests::CreateService.call(
        feedback_request: fr,
        questions_attributes: [
          {
            question_text: "Share observations of #{recipient.person.casual_name}'s #{ability.display_name} at Milestone #{level}.",
            position: 1,
            rateable_type: "Ability",
            rateable_id: ability.id
          }
        ],
        responder_teammate_ids: leftovers.map(&:invitee_teammate_id),
        current_teammate: @award.certifying_teammate
      )
      return result unless result.ok?

      leftovers.find_each do |invite|
        invite.update!(
          converted_to_feedback_at: Time.current,
          feedback_request: result.value
        )
      end

      FeedbackRequests::NotifyRespondentsService.call(feedback_request: result.value)
      Result.ok(@award.reload)
    rescue StandardError => e
      Result.err(e.message)
    end
  end
end
