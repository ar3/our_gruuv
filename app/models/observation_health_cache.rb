# frozen_string_literal: true

class ObservationHealthCache < ApplicationRecord
  belongs_to :teammate, class_name: "CompanyTeammate"
  belongs_to :organization, class_name: "Organization"

  validates :payload, presence: true
  validates :teammate_id, uniqueness: { scope: :organization_id }

  # Payload structure:
  # {
  #   "given" => { "status" => "red"|"yellow"|"green", "last_published_at" => iso8601|null },
  #   "received" => { same },
  #   "kudos_mix" => { "band" => ..., "kudos_count" => n, "constructive_count" => n, "display_ratio" => "N:1" },
  #   "rating_intensity" => { "band" => ..., "less_extreme_count" => n, "most_extreme_count" => n, "display_ratio" => "N:1" },
  #   "overall_status" => "red"|"yellow"|"green"
  # }
  def payload_given
    payload["given"] || {}
  end

  def payload_received
    payload["received"] || {}
  end

  def payload_kudos_mix
    payload["kudos_mix"] || {}
  end

  def payload_rating_intensity
    payload["rating_intensity"] || {}
  end

  def overall_status
    payload["overall_status"]
  end
end
