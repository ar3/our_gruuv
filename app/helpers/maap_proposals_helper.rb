# frozen_string_literal: true

module MaapProposalsHelper
  def render_maap_proposal_field_diff(field_diff)
    return if field_diff.blank?

    tag.div(class: "maap-proposal-diff mb-4") do
      safe_join(
        [
          tag.h6(field_diff.label, class: "text-muted"),
          tag.div(field_diff.html.html_safe, class: "maap-proposal-diff__body border rounded p-2 bg-light")
        ]
      )
    end
  end

  # Nil when the viewer can apply/reject now; otherwise a hover explanation.
  def maap_proposal_decision_disabled_reason(proposal)
    unless proposal.decidable?
      return case proposal.status
      when "draft"
        "Only submitted proposals can be applied or rejected. Submit this draft first."
      when "applied"
        "This proposal has already been applied."
      when "rejected"
        "This proposal has already been rejected."
      else
        "Only submitted proposals can be applied or rejected."
      end
    end

    return if policy(proposal).apply?

    if proposal.ability_create?
      "You need permission to create Abilities to apply or reject this proposal."
    elsif proposal.create_kind?
      "You need permission to create Assignments to apply or reject this proposal."
    else
      "You need MAAP management permissions to apply or reject this proposal."
    end
  end

  def maap_proposal_decision_enabled?(proposal)
    maap_proposal_decision_disabled_reason(proposal).nil?
  end
end
