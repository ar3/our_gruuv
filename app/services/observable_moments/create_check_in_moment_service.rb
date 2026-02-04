module ObservableMoments
  class CreateCheckInMomentService
    def self.call(...) = new(...).call
    
    def initialize(check_in:, finalized_by:)
      @check_in = check_in
      @finalized_by = finalized_by
    end
    
    def call
      # Only create moment if rating improved
      return Result.err("Rating did not improve") unless rating_improved?
      
      # Primary observer is the manager who finalized
      # @finalized_by is already a CompanyTeammate, so we can use it directly
      # But we need to ensure it's in the same organization as the check-in
      if @finalized_by.organization_id == @check_in.teammate.organization_id
        primary_observer = @finalized_by
      else
        # If they're in different organizations, find the teammate in the check-in's organization
        primary_observer = @finalized_by.person.company_teammates.find_by(organization: @check_in.teammate.organization)
      end
      return Result.err("Could not find finalizer's teammate in organization") unless primary_observer
      
      # Determine check-in type
      check_in_type = @check_in.class.name.underscore.humanize
      
      # Build metadata
      metadata = {
        check_in_type: check_in_type,
        official_rating: @check_in.official_rating.to_s,
        previous_rating: previous_rating ? previous_rating.to_s : nil,
        teammate_name: @check_in.teammate.person.display_name
      }
      
      # Add assignment/aspiration specific metadata
      if @check_in.respond_to?(:assignment)
        metadata[:assignment_id] = @check_in.assignment_id
        metadata[:assignment_name] = @check_in.assignment&.name
      elsif @check_in.respond_to?(:aspiration)
        metadata[:aspiration_id] = @check_in.aspiration_id
        metadata[:aspiration_name] = @check_in.aspiration&.name
      end
      
      ObservableMoments::BaseObservableMomentService.new(
        momentable: @check_in,
        company: @check_in.teammate.organization,
        created_by: @finalized_by.person,
        primary_potential_observer: primary_observer,
        moment_type: :check_in_completed,
        occurred_at: @check_in.official_check_in_completed_at || Time.current,
        metadata: metadata
      ).call
    end
    
    private
    
    def rating_improved?
      return false unless @check_in.official_rating.present?
      
      previous = previous_rating
      return true if previous.nil? # First check-in is always an improvement
      
      current = @check_in.official_rating
      
      # Handle different rating types
      if @check_in.is_a?(PositionCheckIn)
        # Integer ratings: -3 to 3, higher is better
        current.to_i > previous.to_i
      else
        # Enum ratings: working_to_meet < meeting < exceeding
        rating_value(current) > rating_value(previous)
      end
    end
    
    def previous_rating
      @previous_rating ||= begin
        if @check_in.is_a?(PositionCheckIn)
          previous_check_in = PositionCheckIn
            .where(company_teammate: @check_in.teammate)
            .closed
            .where.not(id: @check_in.id)
            .order(official_check_in_completed_at: :desc)
            .first
          previous_check_in&.official_rating
        elsif @check_in.is_a?(AssignmentCheckIn)
          previous_check_in = AssignmentCheckIn
            .where(company_teammate: @check_in.teammate, assignment: @check_in.assignment)
            .closed
            .where.not(id: @check_in.id)
            .order(official_check_in_completed_at: :desc)
            .first
          previous_check_in&.official_rating
        elsif @check_in.is_a?(AspirationCheckIn)
          previous_check_in = AspirationCheckIn
            .where(company_teammate: @check_in.teammate, aspiration: @check_in.aspiration)
            .closed
            .where.not(id: @check_in.id)
            .order(official_check_in_completed_at: :desc)
            .first
          previous_check_in&.official_rating
        end
      end
    end
    
    def rating_value(rating)
      case rating.to_s
      when 'working_to_meet'
        1
      when 'meeting'
        2
      when 'exceeding'
        3
      else
        0
      end
    end
  end
end

