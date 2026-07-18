# PaperTrail configuration
# Ensure controller info is stored in meta JSONB column, not as direct attributes
Rails.application.config.after_initialize do
  # Only modify PaperTrail::Version if it exists (skip during asset precompilation)
  if defined?(PaperTrail::Version)
    # Override PaperTrail's controller_info handling to use meta column
    PaperTrail::Version.class_eval do
    # Override the controller_info setter to store in meta instead of as direct attributes
    def controller_info=(info)
      self.meta = (meta || {}).merge(info.stringify_keys)
    end
    
    # Override the controller_info getter to read from meta
    def controller_info
      meta || {}
    end
    
    # Override the whodunnit setter to also store in meta
    def whodunnit=(value)
      super(value)
      self.meta = (meta || {}).merge('whodunnit' => value)
    end
    
    # Prevent PaperTrail from trying to set current_teammate_id as a direct attribute
    def current_teammate_id=(value)
      self.meta = (meta || {}).merge('current_teammate_id' => value)
    end
    
    # Prevent PaperTrail from trying to set impersonating_teammate_id as a direct attribute
    def impersonating_teammate_id=(value)
      self.meta = (meta || {}).merge('impersonating_teammate_id' => value)
    end

    # Assignment outcome snapshots (see Assignment#record_version_for_outcome_changes!)
    def outcomes_snapshot=(value)
      self.meta = (meta || {}).merge('outcomes_snapshot' => value)
    end

    def outcomes_change_context=(value)
      self.meta = (meta || {}).merge('outcomes_change_context' => value)
    end

    # Position assignment updates (see Position#record_version_for_assignment_changes!)
    def position_assignment_change_context=(value)
      self.meta = (meta || {}).merge('position_assignment_change_context' => value)
    end

    # Legacy MaapAgentRun meta keys (kept so old versions remain readable)
    def completed_event=(value)
      self.meta = (meta || {}).merge('completed_event' => value)
    end

    def completed_triggered_by_teammate_id=(value)
      self.meta = (meta || {}).merge('completed_triggered_by_teammate_id' => value)
    end

    def agent_kind=(value)
      self.meta = (meta || {}).merge('agent_kind' => value)
    end

    # Add getters for these attributes to read from meta
    def current_teammate_id
      meta&.dig('current_teammate_id')
    end
    
    def impersonating_teammate_id
      meta&.dig('impersonating_teammate_id')
    end

    def position_assignment_change_context
      meta&.dig('position_assignment_change_context')
    end

    def completed_event
      meta&.dig('completed_event')
    end

    def completed_triggered_by_teammate_id
      meta&.dig('completed_triggered_by_teammate_id')
    end

    def agent_kind
      meta&.dig('agent_kind')
    end
    end
  end
end
