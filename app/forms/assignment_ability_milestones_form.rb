class AssignmentAbilityMilestonesForm < Reform::Form
  model :assignment

  property :ability_milestones, virtual: true

  validate :validate_milestone_levels

  def save
    return false unless valid?

    result = UpdateAssignmentAbilityMilestones.call(
      assignment: model,
      ability_milestones: ability_milestones || {}
    )

    if result.ok?
      true
    else
      errors.add(:base, result.error.is_a?(Array) ? result.error.join(', ') : result.error)
      false
    end
  end

  private

  def validate_milestone_levels
    return if ability_milestones.blank?

    ability_milestones.each do |ability_id_str, milestone_level_str|
      next if milestone_level_str.blank? || milestone_level_str == ''

      milestone_level = milestone_level_str.to_i

      # Allow 0 for "No Association" or 1-5 for milestone levels
      unless milestone_level == 0 || (1..5).include?(milestone_level)
        errors.add(:ability_milestones, "Invalid milestone level for ability #{ability_id_str}: must be between 1 and 5, or 0 for no association")
      end
    end
  end
end

