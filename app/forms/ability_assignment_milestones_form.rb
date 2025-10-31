class AbilityAssignmentMilestonesForm < Reform::Form
  model :ability

  property :assignment_milestones, virtual: true

  validate :validate_milestone_levels

  def save
    return false unless valid?

    result = UpdateAbilityAssignmentMilestones.call(
      ability: model,
      assignment_milestones: assignment_milestones || {}
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
    return if assignment_milestones.blank?

    assignment_milestones.each do |assignment_id_str, milestone_level_str|
      next if milestone_level_str.blank? || milestone_level_str == ''

      milestone_level = milestone_level_str.to_i

      # Allow 0 for "No Association" or 1-5 for milestone levels
      unless milestone_level == 0 || (1..5).include?(milestone_level)
        errors.add(:assignment_milestones, "Invalid milestone level for assignment #{assignment_id_str}: must be between 1 and 5, or 0 for no association")
      end
    end
  end
end

