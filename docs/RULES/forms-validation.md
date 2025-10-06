# Forms & Validation Patterns

This document defines the Forms and Validation patterns for the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Services Patterns](./services-patterns.md) | [Integrations](./integrations.md)

## Forms Pattern

**Standard:** All form objects MUST use **Reform** with **ActiveModel Validations** for form handling and validation.

**Rationale:** Reform provides superior form handling, automatic Rails integration, proper data binding, and clean separation of concerns. ActiveModel Validations provide familiar, reliable validation with excellent Rails integration.

## Reform + ActiveModel Validations (Standard)

```ruby
# app/forms/ability_form.rb
class AbilityForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :name
  property :description
  property :organization_id
  property :version_type, virtual: true  # This is a form-only field, not on the model
  property :milestone_1_description
  property :milestone_2_description
  property :milestone_3_description
  property :milestone_4_description
  property :milestone_5_description

  # Use ActiveModel validations for reliable, familiar validation
  validates :name, presence: true
  validates :description, presence: true
  validates :organization_id, presence: true
  validates :version_type, presence: true, unless: :new_form_without_data?
  validate :at_least_one_milestone_description
  validate :version_type_for_context
  validate :form_data_present

  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Let Reform sync the form data to the model first
    super
    
    # Set the semantic version based on version type
    model.semantic_version = calculate_semantic_version
    
    # Set audit fields
    model.created_by = current_person if model.new_record?
    model.updated_by = current_person
    
    # Save the model
    model.save
  end

  # Helper method to get current person (passed from controller)
  def current_person
    @current_person
  end

  # Setter for current_person (Reform needs a setter for properties not on the model)
  def current_person=(person)
    @current_person = person
  end

  private

  def new_form_without_data?
    # Don't validate version_type on initial page load (new action)
    # Only validate when form has been submitted with data
    model.new_record? && !@form_data_empty.nil? && @form_data_empty
  end

  def form_data_present
    # Check if any form fields have been provided
    # This validation only runs when no ability parameters are provided at all
    if @form_data_empty
      errors.add(:base, "Form data is missing. Please fill out the form and try again.")
    end
  end

  def at_least_one_milestone_description
    milestone_descriptions = [
      milestone_1_description,
      milestone_2_description,
      milestone_3_description,
      milestone_4_description,
      milestone_5_description
    ]
    
    if milestone_descriptions.all?(&:blank?)
      errors.add(:milestone_descriptions, "At least one milestone description is required")
    end
  end

  def version_type_for_context
    return unless version_type.present?
    
    if model.persisted?
      # For existing abilities, only allow update types
      unless %w[fundamental clarifying insignificant].include?(version_type)
        errors.add(:version_type, "must be fundamental, clarifying, or insignificant for existing abilities")
      end
    else
      # For existing abilities, only allow creation types
      unless %w[ready nearly_ready early_draft].include?(version_type)
        errors.add(:version_type, "must be ready, nearly ready, or early draft for new abilities")
      end
    end
  end

  def calculate_semantic_version
    if model.new_record?
      case version_type
      when 'ready'
        "1.0.0"
      when 'nearly_ready'
        "0.1.0"
      when 'early_draft'
        "0.0.1"
      else
        "0.0.1"  # Default to early draft
      end
    else
      return model.semantic_version unless model.semantic_version.present?

      major, minor, patch = model.semantic_version.split('.').map(&:to_i)

      case version_type
      when 'fundamental'
        "#{major + 1}.0.0"
      when 'clarifying'
        "#{major}.#{minor + 1}.0"
      when 'insignificant'
        "#{major}.#{minor}.#{patch + 1}"
      else
        model.semantic_version
      end
    end
  end
end
```

## Controller Integration

```ruby
# app/controllers/organizations/abilities_controller.rb
class Organizations::AbilitiesController < ApplicationController
  def new
    @form = AbilityForm.new(Ability.new(organization: @organization))
    @form.current_person = current_person
    authorize Ability.new(organization: @organization)
  end

  def create
    # Always authorize first
    authorize Ability.new(organization: @organization)
    
    @form = AbilityForm.new(Ability.new(organization: @organization))
    @form.current_person = current_person
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@form.model.organization, @form.model), 
                  notice: 'Ability was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    authorize @ability
  end

  def update
    # Always authorize first
    authorize @ability
    
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@form.model.organization, @form.model), 
                  notice: 'Ability was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

## Advanced Form Features

```ruby
# app/forms/complex_form.rb
class ComplexForm < Reform::Form
  # Regular model properties
  property :name
  property :description
  property :category_id
  
  # Virtual properties (form-only fields)
  property :confirmation_code, virtual: true
  property :terms_accepted, virtual: true
  
  # Nested forms
  property :address, form: AddressForm
  
  # Collections
  collection :tags, form: TagForm
  
  # Validations
  validates :name, presence: true, length: { minimum: 3 }
  validates :description, presence: true
  validates :category_id, presence: true
  validates :confirmation_code, presence: true, length: { is: 6 }
  validates :terms_accepted, inclusion: { in: [true] }
  
  # Custom validations
  validate :category_exists
  validate :confirmation_code_format
  
  def save
    return false unless valid?
    
    # Let Reform sync the form data to the model first
    super
    
    # Custom business logic
    model.confirmed_at = Time.current
    model.confirmed_by = current_person
    
    # Save the model
    model.save
  end
  
  private
  
  def category_exists
    unless Category.exists?(id: category_id)
      errors.add(:category_id, "must be a valid category")
    end
  end
  
  def confirmation_code_format
    unless confirmation_code.match?(/\A[A-Z0-9]{6}\z/)
      errors.add(:confirmation_code, "must be 6 uppercase letters or numbers")
    end
  end
end
```

## Key Principles

- **Always use Reform**: No exceptions for form handling
- **ActiveModel Validations**: Use familiar, reliable validation
- **Virtual Properties**: Use for form-only fields not stored on the model
- **Automatic Rails Integration**: Reform handles Rails form helpers automatically
- **Clean Separation**: Forms handle validation and data binding, Services handle business logic
- **Consistent Error Handling**: All forms use the same error structure
- **Call Services**: Forms can call Services for complex business logic
- **Keep invariants on models**: Don't move true business rules to forms

## Implementation Checklist

When creating or updating forms, ensure:
- [ ] Inherit from `Reform::Form`
- [ ] Define all properties (model and virtual)
- [ ] Use ActiveModel validations for all validation logic
- [ ] Override `save` method to customize persistence logic
- [ ] Call `super` in `save` to let Reform sync data to model
- [ ] Handle virtual properties with getters/setters
- [ ] Provide consistent error handling
- [ ] Keep invariants on models/DB
- [ ] Don't contain complex business logic (use Services)
- [ ] Don't access database directly
- [ ] Don't handle authorization (use Policies instead)

## Migration from Custom Form Objects

When migrating existing custom form objects to Reform:

1. **Change inheritance** from `ActiveModel::Model` to `Reform::Form`
2. **Define properties** explicitly using `property :field_name`
3. **Mark virtual fields** with `virtual: true`
4. **Convert validations** to ActiveModel validations
5. **Update save method** to call `super` and customize logic
6. **Update controller** to use `@form` instead of `@form_object`
7. **Update views** to use `@form` instead of `@form_object`
8. **Test thoroughly** to ensure behavior is preserved

## Decorators for Complex View Logic

**Standard:** Use decorators to encapsulate complex view logic, especially for dynamic options and conditional content.

**Rationale:** Decorators keep complex logic out of views and controllers, making them more maintainable and testable. They provide a clean interface for view-specific data and behavior.

### Decorator Pattern for Form Options

```ruby
# app/decorators/ability_decorator.rb
class AbilityDecorator < SimpleDelegator
  def initialize(ability)
    super(ability)
  end

  def new_version_options
    [
      {
        value: "ready",
        label: "Ready for Use",
        version_text: "Version 1.0.0",
        text_class: "text-success",
        description: "Complete and ready for team use",
        checked: true
      },
      {
        value: "nearly_ready",
        label: "Nearly Ready",
        version_text: "Version 0.1.0",
        text_class: "text-warning",
        description: "Almost complete, minor tweaks needed",
        checked: false
      },
      {
        value: "early_draft",
        label: "Early Draft",
        version_text: "Version 0.0.1",
        text_class: "text-secondary",
        description: "Initial concept, needs development",
        checked: false
      }
    ]
  end

  def edit_version_options
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    
    [
      {
        value: "fundamental",
        label: "Fundamental Change",
        version_text: "Version #{major + 1}.0.0",
        text_class: "text-danger",
        description: "Major changes, new capabilities",
        checked: false
      },
      {
        value: "clarifying",
        label: "Clarifying Change",
        version_text: "Version #{major}.#{minor + 1}.0",
        text_class: "text-warning",
        description: "Improvements, clarifications",
        checked: false
      },
      {
        value: "insignificant",
        label: "Insignificant Change",
        version_text: "Version #{major}.#{minor}.#{patch + 1}",
        text_class: "text-info",
        description: "Small fixes, minor updates",
        checked: false
      }
    ]
  end

  def version_section_title_for_context
    if persisted?
      "Change Type & Version"
    else
      "Ability Status & Version"
    end
  end

  def version_section_description_for_context
    if persisted?
      "Current version: #{semantic_version}. Choose the type of change you're making:"
    else
      "Choose the readiness level for this ability. The version number will be set automatically:"
    end
  end
end
```

### Controller Integration

```ruby
# app/controllers/organizations/abilities_controller.rb
def new
  @ability = Ability.new(organization: @organization)
  @ability_decorator = AbilityDecorator.new(@ability)
  @form = AbilityForm.new(@ability)
  @form.current_person = current_person
  authorize @ability
end

def edit
  @ability_decorator = AbilityDecorator.new(@ability)
  @form = AbilityForm.new(@ability)
  @form.current_person = current_person
  authorize @ability
end
```

### View Usage

```haml
/ app/views/organizations/abilities/new.html.haml
.card-body
  = render 'form', 
    form_url: organization_abilities_path(@organization), 
    submit_button_text: "Create Ability", 
    cancel_path: organization_abilities_path(@organization), 
    version_section_title: @ability_decorator.version_section_title_for_context, 
    version_section_description: @ability_decorator.version_section_description_for_context, 
    version_options: @ability_decorator.new_version_options
```

### When to Use Decorators

**✅ Use decorators when:**
- Complex conditional logic for form options
- Dynamic content based on model state
- Multiple related methods for view data
- Complex calculations for display values
- Context-specific behavior (new vs edit)

**❌ Don't use decorators when:**
- Simple, static data
- Single method with simple logic
- Logic belongs in the model itself
- Performance-critical code (decorators add overhead)

### Decorator Best Practices

- **Single Responsibility**: Each decorator should handle one model's view concerns
- **SimpleDelegator**: Use `SimpleDelegator` for automatic method delegation
- **Descriptive Methods**: Use clear, descriptive method names
- **Context Awareness**: Include context-specific methods when needed
- **Test Coverage**: Write tests for decorator methods
- **Performance**: Cache expensive calculations when appropriate

## Shared Form Partials

**Standard:** When new and edit forms share significant content (>70% similarity), they MUST use a shared partial.

**Rationale:** Shared partials reduce code duplication, ensure consistency, make maintenance easier, and prevent bugs from diverging implementations.

### Shared Partial Pattern

```ruby
# app/views/resources/_form.html.haml
/ Shared form partial for resources (new and edit)
= form_with model: @form, url: form_url, local: true, id: "resource-form" do |form|
  - if @form.errors.any?
    .alert.alert-danger
      %h6 Please fix the following errors:
      %ul.mb-0
        - @form.errors.full_messages.each do |message|
          %li= message
  
  .row
    .col-md-8
      / Form fields go here
      .mb-3
        = form.label :name, class: "form-label"
        = form.text_field :name, class: "form-control"
      
      / Conditional content based on context
      - if @resource&.persisted?
        / Edit-specific content
      - else
        / New-specific content
    
    .col-md-4.border-start.border-secondary
      .d-grid.gap-2
        %button.btn.btn-primary{type: "submit"}
          %i.bi.bi-check.me-2
          = submit_button_text
        = link_to "Cancel", cancel_path, class: "btn btn-outline-secondary"
        - if @resource&.persisted?
          = link_to resource_path(@resource), class: "btn btn-outline-info" do
            %i.bi.bi-eye.me-2
            View Resource
```

### New Form Implementation

```haml
/ app/views/resources/new.html.haml
.d-flex.justify-content-between.align-items-center.mb-2
  %h1.mb-0{id: "page-title"}
    %i.bi.bi-plus.me-2
    New Resource
  .d-flex.align-items-center
    = link_to resources_path, class: "btn btn-secondary" do
      %i.bi.bi-arrow-left.me-2
      Cancel

.mb-4
  = link_to resources_path, class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to Resources

.card
  .card-header
    %h5.mb-0
      %i.bi.bi-plus.me-2
      Create New Resource
  .card-body
    = render 'form', 
      form_url: resources_path, 
      submit_button_text: "Create Resource", 
      cancel_path: resources_path, 
      section_title: "New Resource Section", 
      section_description: "Description for new resource", 
      options: [
        { value: "option1", label: "Option 1", description: "First option", checked: true },
        { value: "option2", label: "Option 2", description: "Second option", checked: false }
      ]
```

### Edit Form Implementation

```haml
/ app/views/resources/edit.html.haml
.d-flex.justify-content-between.align-items-center.mb-2
  %h1.mb-0{id: "page-title"}
    %i.bi.bi-pencil.me-2
    Edit #{@resource.name}
  .d-flex.align-items-center
    .btn-group
      = link_to resource_path(@resource), class: "btn btn-info" do
        %i.bi.bi-eye.me-2
        View
      = link_to resources_path, class: "btn btn-secondary" do
        %i.bi.bi-arrow-left.me-2
        Back to Resources

.mb-4
  = link_to resource_path(@resource), class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to #{@resource.name}

.card
  .card-header
    %h5.mb-0
      %i.bi.bi-pencil.me-2
      Edit #{@resource.name}
  .card-body
    = render 'form', 
      form_url: resource_path(@resource), 
      submit_button_text: "Update Resource", 
      cancel_path: resource_path(@resource), 
      section_title: "Edit Resource Section", 
      section_description: "Description for editing resource", 
      options: [
        { value: "option1", label: "Option 1", description: "First option", checked: false },
        { value: "option2", label: "Option 2", description: "Second option", checked: false }
      ]
```

### Key Principles for Shared Partials

- **Use local variables**: Pass all dynamic content as local variables to the partial
- **Conditional logic**: Use `@resource&.persisted?` to differentiate between new and edit
- **Clear variable names**: Use descriptive names like `form_url`, `submit_button_text`, `cancel_path`
- **Consistent structure**: Keep the same variable pattern across all shared partials
- **Single responsibility**: The partial should only handle the form, not page layout

### When to Use Shared Partials

**✅ Use shared partials when:**
- Forms share >70% of their content
- Only differences are URLs, button text, and minor conditional content
- Both forms use the same form object
- Validation logic is identical

**❌ Don't use shared partials when:**
- Forms are fundamentally different (>50% different content)
- Different form objects are used
- Validation logic differs significantly
- Forms have different layouts or structures

### Implementation Checklist

When creating shared form partials, ensure:
- [ ] Partial is named `_form.html.haml`
- [ ] All dynamic content is passed as local variables
- [ ] Conditional logic uses `@resource&.persisted?` pattern
- [ ] Variable names are descriptive and consistent
- [ ] Both new and edit forms use the same variable pattern
- [ ] Partial handles only form content, not page layout
- [ ] Error handling is consistent between new and edit