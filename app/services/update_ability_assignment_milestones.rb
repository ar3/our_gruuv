class UpdateAbilityAssignmentMilestones
  def self.call(...) = new(...).call

  def initialize(ability:, assignment_milestones:)
    @ability = ability
    @assignment_milestones = assignment_milestones
  end

  def call
    ApplicationRecord.transaction do
      # Process each assignment milestone selection
      @assignment_milestones.each do |assignment_id_str, milestone_level_str|
        assignment_id = assignment_id_str.to_i
        milestone_level = milestone_level_str.presence&.to_i

        # Find existing association
        existing_association = @ability.assignment_abilities.find_by(assignment_id: assignment_id)

        if milestone_level.nil? || milestone_level_str == '' || milestone_level == 0
          # Delete association if "no association" selected (0), empty, or nil
          existing_association&.destroy
        else
          # Validate milestone level
          unless (1..5).include?(milestone_level)
            return Result.err("Invalid milestone level: #{milestone_level}. Must be between 1 and 5.")
          end

          # Find the assignment to validate organization scoping
          assignment = Assignment.find_by(id: assignment_id)
          unless assignment
            return Result.err("Assignment with ID #{assignment_id} not found.")
          end

          # Validate organization scoping - ability and assignment must belong to the same company
          unless @ability.company_id == assignment.company_id
            return Result.err("Assignment must belong to the same company as the ability.")
          end

          if existing_association
            # Update existing association
            existing_association.update!(milestone_level: milestone_level)
          else
            # Create new association
            @ability.assignment_abilities.create!(
              assignment: assignment,
              milestone_level: milestone_level
            )
          end
        end
      end

      Result.ok(@ability)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to update ability assignment milestones: #{e.message}")
  end
end

