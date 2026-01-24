module ObservableMoments
  class BaseObservableMomentService
    def self.call(...) = new(...).call
    
    def initialize(momentable:, company:, created_by:, primary_potential_observer:, moment_type:, occurred_at: Time.current, metadata: {})
      @momentable = momentable
      @company = company
      @created_by = created_by
      @primary_potential_observer = primary_potential_observer
      @moment_type = moment_type
      @occurred_at = occurred_at
      @metadata = metadata
    end
    
    def call
      # Use separate transaction to avoid blocking primary actions
      begin
        ApplicationRecord.transaction do
          # Convert created_by to Person if it's a CompanyTeammate
          created_by_person = if @created_by.is_a?(CompanyTeammate)
            @created_by.person
          else
            @created_by
          end
          
          observable_moment = ObservableMoment.create!(
            momentable: @momentable,
            company: @company,
            created_by: created_by_person,
            primary_potential_observer: @primary_potential_observer,
            moment_type: @moment_type,
            occurred_at: @occurred_at,
            metadata: @metadata
          )
          
          Result.ok(observable_moment)
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create observable moment: #{e.message}"
        Result.err("Failed to create observable moment: #{e.message}")
      rescue => e
        Rails.logger.error "Unexpected error creating observable moment: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        Result.err("Failed to create observable moment: #{e.message}")
      end
    end
  end
end

