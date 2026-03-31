# frozen_string_literal: true

class PositionEligibilityResolver
  class MissingOrganizationDefault < StandardError; end

  Result = Struct.new(:record, :source, keyword_init: true)

  VALID_MINORS = [1, 2, 3].freeze

  def self.resolve(position)
    minor = position.position_level.eligibility_minor_slot
    fk_getter = :"minor_#{minor}_position_eligibility_requirement_id"

    if position.position_eligibility_requirement_id.present?
      return Result.new(record: position.position_eligibility_requirement, source: :position)
    end

    department = position.title.department
    if department&.public_send(fk_getter).present?
      record = PositionEligibilityRequirement.find(department.public_send(fk_getter))
      return Result.new(record: record, source: :department)
    end

    org = position.company
    rid = org.public_send(fk_getter)
    raise MissingOrganizationDefault, "Organization #{org.id} missing default for minor #{minor}" if rid.blank?

    Result.new(record: PositionEligibilityRequirement.find(rid), source: :organization)
  end
end
