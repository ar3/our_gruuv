# frozen_string_literal: true

class CheckInCompletionNotificationBatch < ApplicationRecord
  belongs_to :organization, class_name: 'Organization'
  belongs_to :employee_teammate, class_name: 'CompanyTeammate', foreign_key: :employee_teammate_id
  belongs_to :manager_teammate, class_name: 'CompanyTeammate', foreign_key: :manager_teammate_id
  belongs_to :action_taker_teammate, class_name: 'CompanyTeammate', foreign_key: :action_taker_teammate_id
  belongs_to :notification, class_name: 'Notification', optional: true

  validates :hour_marker, presence: true
  validates :organization_id, uniqueness: {
    scope: %i[hour_marker employee_teammate_id manager_teammate_id action_taker_teammate_id]
  }
end
