# app/services/milestone_attainment_service.rb
class MilestoneAttainmentService
  def self.call(...) = new(...).call

  def initialize(teammate:, ability:, milestone_level:, certified_by:, attained_at: Date.current)
    @teammate = teammate
    @ability = ability
    @milestone_level = milestone_level
    @certified_by = certified_by
    @attained_at = attained_at
  end

  def call
    ApplicationRecord.transaction do
      # Check if milestone already exists
      existing_milestone = @teammate.person_milestones.find_by(
        ability: @ability, 
        milestone_level: @milestone_level
      )
      
      if existing_milestone
        return Result.err("Milestone #{@milestone_level} for #{@ability.name} already exists for this teammate")
      end

      # Create the milestone attainment
      milestone = @teammate.person_milestones.create!(
        ability: @ability,
        milestone_level: @milestone_level,
        certified_by: @certified_by,
        attained_at: @attained_at
      )

      Result.ok(milestone)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to create milestone attainment: #{e.message}")
  end
end
