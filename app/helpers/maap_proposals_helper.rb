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

    if proposal.seat_create?
      blockers = proposal.seat_apply_blockers
      return blockers.join(" ") if blockers.any?
    end

    return if policy(proposal).apply?

    if proposal.ability_create?
      "You need permission to create Abilities to apply or reject this proposal."
    elsif proposal.seat_create?
      "You need permission to create Seats to apply or reject this proposal."
    elsif proposal.title_create?
      "You need permission to create Titles to apply or reject this proposal."
    elsif proposal.team_create?
      "You need permission to create Teams to apply or reject this proposal."
    elsif proposal.position_create?
      "You need permission to create Positions to apply or reject this proposal."
    elsif proposal.create_kind?
      "You need permission to create Assignments to apply or reject this proposal."
    else
      "You need MAAP management permissions to apply or reject this proposal."
    end
  end

  def maap_proposal_decision_enabled?(proposal)
    maap_proposal_decision_disabled_reason(proposal).nil?
  end

  def maap_proposal_show_path(organization, proposal)
    return nil if proposal.blank?

    if proposal.seat_create?
      organization_maap_seat_create_path(organization, proposal)
    elsif proposal.title_create?
      organization_maap_title_create_path(organization, proposal)
    elsif proposal.team_create?
      organization_maap_team_create_path(organization, proposal)
    elsif proposal.position_create?
      organization_maap_position_create_path(organization, proposal)
    elsif proposal.ability_create?
      organization_maap_ability_create_path(organization, proposal)
    elsif proposal.assignment_create?
      organization_maap_assignment_create_path(organization, proposal)
    elsif proposal.edit_kind? && proposal.proposable_type == "Assignment" && proposal.proposable
      organization_assignment_maap_proposal_path(organization, proposal.proposable, proposal)
    elsif proposal.edit_kind? && proposal.proposable_type == "Ability" && proposal.proposable
      organization_ability_maap_proposal_path(organization, proposal.proposable, proposal)
    elsif proposal.edit_kind? && proposal.proposable_type == "Seat" && proposal.proposable
      organization_seat_maap_proposal_path(organization, proposal.proposable, proposal)
    end
  end

  def seat_submit_disabled_reason(proposal)
    return nil unless proposal.seat_create?

    proposal.seat_submit_blockers.first
  end

  # Dependency-first order for Seat suggestion linked creates.
  # Title/Team unlock the Seat; Abilities feed Assignments; Assignments feed Position.
  SEAT_LINKED_APPROVAL_ORDER = %w[title team ability assignment position].freeze

  def seat_linked_proposal_links_in_approval_order(proposal)
    links = proposal.child_proposal_links.includes(:child_proposal).to_a
    links.sort_by do |link|
      [
        SEAT_LINKED_APPROVAL_ORDER.index(link.role.to_s) || SEAT_LINKED_APPROVAL_ORDER.length,
        link.child_proposal_id
      ]
    end
  end
end

