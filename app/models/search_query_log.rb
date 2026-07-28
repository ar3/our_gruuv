# frozen_string_literal: true

class SearchQueryLog < ApplicationRecord
  belongs_to :organization
  belongs_to :company_teammate, class_name: "CompanyTeammate"

  validates :query, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.record!(organization:, company_teammate:, query:, results_count: 0)
    q = query.to_s.strip
    return nil if q.blank?

    create!(
      organization: organization,
      company_teammate: company_teammate,
      query: q,
      results_count: results_count.to_i
    )
  end

  def self.recent_for_teammate(company_teammate:, limit: 3)
    where(company_teammate_id: company_teammate.id).recent_first.limit(limit)
  end

  def self.recent_for_organization(organization:, limit: 25)
    where(organization_id: organization.id).recent_first.limit(limit)
  end
end
