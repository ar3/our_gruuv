# app/helpers/dry_to_active_model_errors.rb
module DryToActiveModelErrors
  def self.wrap(dry_errors)
    # Create a dummy object that responds to human_attribute_name
    dummy_object = Object.new
    def dummy_object.human_attribute_name(attr)
      attr.to_s.humanize
    end
    
    errors = ActiveModel::Errors.new(dummy_object)
    
    dry_errors.each do |error|
      if error.path.empty?
        # Base errors
        errors.add(:base, error.text)
      else
        # Field-specific errors
        field = error.path.join('_').to_sym
        errors.add(field, error.text)
      end
    end
    
    errors
  end
end
