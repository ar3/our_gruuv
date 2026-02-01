module ObservableMoments
  class CreateAbilityMilestoneMomentService
    def self.call(...) = new(...).call
    
    def initialize(teammate_milestone:, created_by:)
      @teammate_milestone = teammate_milestone
      @created_by = created_by
    end
    
    def call
      # Primary observer is the teammate who certified the milestone
      primary_observer = @teammate_milestone.certifying_teammate
      return Result.err("Could not find certifier's teammate in organization") unless primary_observer
      
      # Build metadata
      metadata = {
        ability_id: @teammate_milestone.ability_id,
        ability_name: @teammate_milestone.ability.name,
        milestone_level: @teammate_milestone.milestone_level,
        person_name: @teammate_milestone.teammate.person.display_name
      }
      
      ObservableMoments::BaseObservableMomentService.new(
        momentable: @teammate_milestone,
        company: @teammate_milestone.ability.company,
        created_by: @created_by,
        primary_potential_observer: primary_observer,
        moment_type: :ability_milestone,
        occurred_at: @teammate_milestone.attained_at || Time.current,
        metadata: metadata
      ).call
    end
  end
end

