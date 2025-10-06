# app/services/create_ability.rb
class CreateAbility
  def self.call(...) = new(...).call

  def initialize(name:, description:, organization_id:, version_type:, milestone_descriptions:, organization:, current_person:)
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
      ability = @organization.abilities.build(
        name: @name,
        description: @description,
        organization_id: @organization_id,
        semantic_version: calculate_version_for_new_ability,
        milestone_1_description: @milestone_descriptions[:milestone_1_description],
        milestone_2_description: @milestone_descriptions[:milestone_2_description],
        milestone_3_description: @milestone_descriptions[:milestone_3_description],
        milestone_4_description: @milestone_descriptions[:milestone_4_description],
        milestone_5_description: @milestone_descriptions[:milestone_5_description],
        created_by: @current_person,
        updated_by: @current_person
      )
      
      ability.save!
      Result.ok(ability)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  private

  def calculate_version_for_new_ability
    case @version_type
    when 'ready' then "1.0.0"
    when 'nearly_ready' then "0.1.0"
    when 'early_draft' then "0.0.1"
    else "0.0.1" # Default to early draft
    end
  end
end
