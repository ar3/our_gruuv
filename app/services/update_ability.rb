# app/services/update_ability.rb
class UpdateAbility
  def self.call(...) = new(...).call

  def initialize(ability:, name:, description:, organization_id:, version_type:, milestone_descriptions:, organization:, current_person:)
    @ability = ability
    @name = name
    @description = description
    @organization_id = organization_id
    @version_type = version_type
    @milestone_descriptions = milestone_descriptions
    @organization = organization
    @current_person = current_person
  end

  def call
    ApplicationRecord.transaction do
      @ability.assign_attributes(
        name: @name,
        description: @description,
        organization_id: @organization_id,
        semantic_version: calculate_version_for_existing_ability,
        milestone_1_description: @milestone_descriptions[:milestone_1_description],
        milestone_2_description: @milestone_descriptions[:milestone_2_description],
        milestone_3_description: @milestone_descriptions[:milestone_3_description],
        milestone_4_description: @milestone_descriptions[:milestone_4_description],
        milestone_5_description: @milestone_descriptions[:milestone_5_description],
        updated_by: @current_person
      )
      
      @ability.save!
      Result.ok(@ability)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  private

  def calculate_version_for_existing_ability
    return @ability.semantic_version unless @ability.semantic_version.present?
    
    major, minor, patch = @ability.semantic_version.split('.').map(&:to_i)
    
    case @version_type
    when 'fundamental'
      "#{major + 1}.0.0"
    when 'clarifying'
      "#{major}.#{minor + 1}.0"
    when 'insignificant'
      "#{major}.#{minor}.#{patch + 1}"
    else
      @ability.semantic_version
    end
  end
end
