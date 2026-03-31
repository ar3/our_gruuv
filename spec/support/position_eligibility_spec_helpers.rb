# frozen_string_literal: true

module PositionEligibilitySpecHelpers
  def assign_position_eligibility_from_hash!(position, hash)
    req = EligibilityRequirements::FindOrCreate.call!(hash.stringify_keys)
    position.update!(position_eligibility_requirement_id: req.id)
  end

  def position_eligibility_service_hash_for(position)
    position.reload
    position.position_eligibility_requirement&.to_eligibility_service_hash || {}
  end
end

RSpec.configure do |config|
  config.include PositionEligibilitySpecHelpers
end
