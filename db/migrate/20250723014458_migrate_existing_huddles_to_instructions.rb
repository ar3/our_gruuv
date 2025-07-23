class MigrateExistingHuddlesToInstructions < ActiveRecord::Migration[8.0]
  def up
    # Group huddles by organization and alias
    huddle_groups = Huddle.joins(:organization)
                          .group(:organization_id, :huddle_alias)
                          .pluck(:organization_id, :huddle_alias)
    
    puts "Found #{huddle_groups.length} unique organization/alias combinations"
    
    huddle_groups.each do |organization_id, alias_name|
      # Create huddle instruction
      instruction = HuddleInstruction.create!(
        organization_id: organization_id,
        instruction_alias: alias_name,
        slack_channel: nil # We'll handle this in a separate step
      )
      
      # Update all huddles with this organization/alias combination
      updated_count = Huddle.where(organization_id: organization_id, huddle_alias: alias_name)
                           .update_all(huddle_instruction_id: instruction.id)
      
      puts "Created instruction for #{instruction.instruction_alias || 'Unnamed'} and updated #{updated_count} huddles"
    end
    
    # Now migrate slack_channel data from huddles to instructions
    HuddleInstruction.includes(:huddles).each do |instruction|
      # Find the most recent huddle with a slack_channel
      huddle_with_channel = instruction.huddles.where.not(slack_channel: [nil, '']).order(created_at: :desc).first
      
      if huddle_with_channel&.slack_channel.present?
        instruction.update!(slack_channel: huddle_with_channel.slack_channel)
        puts "Migrated slack_channel '#{huddle_with_channel.slack_channel}' to instruction '#{instruction.display_name}'"
      end
    end
  end
  
  def down
    # Remove all huddle instruction associations
    Huddle.update_all(huddle_instruction_id: nil)
    
    # Delete all huddle instructions
    HuddleInstruction.destroy_all
  end
end
