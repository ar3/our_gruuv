# frozen_string_literal: true

class MaapProposalLink < ApplicationRecord
  ROLES = %w[
    title
    additional_title
    team
    position
    assignment
    ability
  ].freeze

  belongs_to :parent_proposal, class_name: "MaapProposal"
  belongs_to :child_proposal, class_name: "MaapProposal"

  validates :role, presence: true, inclusion: { in: ROLES }
  validate :same_organization
  validate :parent_is_not_child

  private

  def same_organization
    return unless parent_proposal && child_proposal
    return if parent_proposal.organization_id == child_proposal.organization_id

    errors.add(:child_proposal, "must belong to the same organization as the parent")
  end

  def parent_is_not_child
    return unless parent_proposal_id.present? && child_proposal_id.present?
    return if parent_proposal_id != child_proposal_id

    errors.add(:child_proposal, "cannot be the same as the parent")
  end
end
