module ObservableMoments
  class ObservationStoryTemplateService
    def self.template_for(observable_moment)
      new(observable_moment).template
    end
    
    def self.suggested_observees(observable_moment)
      new(observable_moment).suggested_observees
    end
    
    def self.suggested_privacy_level(observable_moment)
      new(observable_moment).suggested_privacy_level
    end
    
    def initialize(observable_moment)
      @moment = observable_moment
    end
    
    def template
      case @moment.moment_type
      when 'new_hire'
        tenure = @moment.momentable
        person = tenure&.teammate&.person
        position = tenure&.position
        "Welcome #{person&.display_name || 'our new team member'} to the team as #{position&.display_name || 'a new position'}! We're excited to have you here."
      when 'seat_change'
        tenure = @moment.momentable
        person = tenure&.teammate&.person
        old_position = @moment.metadata['old_position_name']
        new_position = tenure&.position&.display_name
        if old_position && new_position
          "Congratulations to #{person&.display_name || 'our team member'} on their promotion from #{old_position} to #{new_position}!"
        else
          "Congratulations to #{person&.display_name || 'our team member'} on their new position!"
        end
      when 'ability_milestone'
        milestone = @moment.momentable
        person = milestone&.teammate&.person
        ability = milestone&.ability
        level = milestone&.milestone_level
        "Congratulations to #{person&.display_name || 'our team member'} for achieving #{ability&.name || 'an ability'} milestone level #{level || '?'}!"
      when 'check_in_completed'
        check_in = @moment.momentable
        person = check_in&.teammate&.person
        rating = @moment.metadata['official_rating']
        "Great work by #{person&.display_name || 'our team member'} on their check-in with a rating of #{rating || 'N/A'}!"
      when 'goal_check_in'
        goal_check_in = @moment.momentable
        goal = goal_check_in&.goal
        person = goal&.owner&.person if goal&.owner&.respond_to?(:person)
        confidence = @moment.metadata['confidence_percentage']
        delta = @moment.metadata['confidence_delta']
        direction = delta.to_i > 0 ? 'increased' : 'decreased'
        "Great progress on '#{goal&.title || 'the goal'}'! Confidence #{direction} to #{confidence}%."
      else
        "Celebrating this moment with #{@moment.description}!"
      end
    end
    
    def suggested_observees
      teammate = @moment.associated_teammate
      return [] unless teammate
      
      [teammate]
    end
    
    def suggested_privacy_level
      # Default to public_to_company for celebratory moments
      'public_to_company'
    end
  end
end

