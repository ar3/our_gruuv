# frozen_string_literal: true

class DocumentLink < ApplicationRecord
  belongs_to :document, inverse_of: :document_links
  belongs_to :linkable, polymorphic: true

  validates :linkable_type, presence: true
  validates :linkable_id, presence: true, uniqueness: { scope: [:document_id, :linkable_type] }
  validate :linkable_belongs_to_document_organization

  private

  def linkable_belongs_to_document_organization
    return if document.blank? || linkable.blank?

    linkable_org_id = case linkable
                      when Assignment
                        linkable.company_id
                      when Organization
                        linkable.id
                      when Department, Team
                        linkable.company_id
                      when CompanyTeammate
                        linkable.organization_id
                      else
                        nil
                      end

    return if linkable_org_id == document.organization_id

    errors.add(:linkable, "must belong to the same organization as the document")
  end
end
