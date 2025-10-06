# Reform configuration following best practices
# This ensures Reform is properly integrated with Rails and dry-validation

require 'reform/form/dry'

# Configure Reform to use dry-validation as the validation backend
Reform::Form.class_eval do
  feature Reform::Form::Dry
end
