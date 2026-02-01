class UpdateAssignmentAbilityMilestones
  def self.call(...) = new(...).call

  def initialize(assignment:, ability_milestones:)
    @assignment = assignment
    @ability_milestones = ability_milestones
  end

  def call
    ApplicationRecord.transaction do
      # Process each ability milestone selection
      @ability_milestones.each do |ability_id_str, milestone_level_str|
        ability_id = ability_id_str.to_i
        milestone_level = milestone_level_str.presence&.to_i

        # Find existing association
        existing_association = @assignment.assignment_abilities.find_by(ability_id: ability_id)

        if milestone_level.nil? || milestone_level_str == '' || milestone_level == 0
          # Delete association if "no association" selected (0), empty, or nil
          existing_association&.destroy
        else
          # Validate milestone level
          unless (1..5).include?(milestone_level)
            return Result.err("Invalid milestone level: #{milestone_level}. Must be between 1 and 5.")
          end

          # Find the ability to validate organization scoping
          ability = Ability.find_by(id: ability_id)
          unless ability
            return Result.err("Ability with ID #{ability_id} not found.")
          end

          # Validate organization scoping - ability and assignment must belong to the same company
          unless ability.company_id == @assignment.company_id
            return Result.err("Ability must belong to the same company as the assignment.")
          end

          if existing_association
            # Update existing association
            existing_association.update!(milestone_level: milestone_level)
          else
            # Create new association
            @assignment.assignment_abilities.create!(
              ability: ability,
              milestone_level: milestone_level
            )
          end
        end
      end

      Result.ok(@assignment)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to update assignment ability milestones: #{e.message}")
  end
end

