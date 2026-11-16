# frozen_string_literal: true

module MaapProposals
  class SubmitTitleEdit
    def self.call(proposal:)
      new(proposal: proposal).call
    end

    def initialize(proposal:)
      @proposal = proposal
    end

    def call
      return Result.err("Only draft proposals can be submitted") unless @proposal.submittable?

      if @proposal.title_create?
        submit_create
      elsif @proposal.edit_kind? && @proposal.proposable_type == "Title"
        submit_edit
      else
        Result.err("Only Title proposals are supported")
      end
    end

    private

    def submit_create
      payload = TitlePayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end

    def submit_edit
      title = @proposal.proposable
      payload = TitlePayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: title.company)
      return Result.err(errors) if errors.any?

      live = TitlePayload.from_title(title)
      return Result.err("Proposal has no changes from the current title") if payload.same_as?(live)

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
