module ObservableMoments
  class AssociateAndProcessService
    def self.call(...) = new(...).call
    
    def initialize(observation:, observable_moment_id:)
      @observation = observation
      @observable_moment_id = observable_moment_id
    end
    
    def call
      return unless @observable_moment_id.present?
      
      observable_moment = ObservableMoment.find_by(id: @observable_moment_id)
      return unless observable_moment
      
      # Associate the observation with the observable moment
      # Only update if the association isn't already set
      unless @observation.observable_moment_id == observable_moment.id
        @observation.observable_moment = observable_moment
        if @observation.persisted?
          @observation.save!
        end
      end
      
      # Mark the moment as processed if not already processed
      return if observable_moment.processed?
      
      # Get observer's teammate for processed_by_teammate
      current_teammate = if @observation.observer
        @observation.observer.teammates.find_by(organization: @observation.company)
      end
      
      observable_moment.update!(
        processed_at: Time.current,
        processed_by_teammate: current_teammate
      )
    end
  end
end
