class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  # Add error tracking for model validation failures
  after_validation :track_validation_errors, if: -> { errors.any? }
  
  private
  
  def track_validation_errors
    return unless Rails.env.production? || Rails.env.staging?
    
    Sentry.capture_message("Model validation failed", level: :warning) do |event|
      event.set_context('model', {
        class: self.class.name,
        id: id,
        errors: errors.full_messages,
        attributes: attributes.except('created_at', 'updated_at')
      })
    end
  end
end
