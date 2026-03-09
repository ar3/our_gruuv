# frozen_string_literal: true

class CheckInHealthCache < ApplicationRecord
  belongs_to :teammate, class_name: 'CompanyTeammate'
  belongs_to :organization, class_name: 'Organization'

  validates :payload, presence: true
  validates :teammate_id, uniqueness: { scope: :organization_id }

  # Payload structure:
  # {
  #   "position" => { "category" => "red"|"orange"|... , "employee_completed_at" => ..., "manager_completed_at" => ..., "official_check_in_completed_at" => ..., "acknowledged_at" => ... },
  #   "assignments" => [ { "item_id" => id, "category" => ..., same date keys }, ... ],
  #   "aspirations" => [ { "item_id" => id, "category" => ..., same date keys }, ... ],
  #   "milestones" => { "total_required" => n, "earned_count" => n }
  # }
  def payload_position
    payload['position'] || {}
  end

  def payload_assignments
    payload['assignments'] || []
  end

  def payload_aspirations
    payload['aspirations'] || []
  end

  def payload_milestones
    payload['milestones'] || {}
  end

  # Completion score 0-4 per item; returns hash with :position, :assignments, :aspirations (each sum of points), :milestones (earned/total)
  def completion_points
    points = { position: category_to_points(payload_position['category']),
               assignments: payload_assignments.sum { |item| category_to_points(item['category']) },
               aspirations: payload_aspirations.sum { |item| category_to_points(item['category']) } }
    total_req = payload_milestones['total_required'].to_i
    earned = payload_milestones['earned_count'].to_i
    points[:milestones] = total_req.positive? ? (earned.to_f / total_req * 4).round(2) : 4.0
    points
  end

  def self.category_to_points(category)
    case category.to_s
    when 'red' then 0
    when 'orange' then 1
    when 'light_blue', 'light_purple' then 2
    when 'light_green' then 3
    when 'green', 'neon_green' then 4
    else 0
    end
  end

  private

  def category_to_points(category)
    self.class.category_to_points(category)
  end
end
