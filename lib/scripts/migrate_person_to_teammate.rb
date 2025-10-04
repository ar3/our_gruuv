#!/usr/bin/env ruby
# Migration script to populate teammate_id from person_id in tables that have both
# Run this in production console: load 'lib/scripts/migrate_person_to_teammate.rb'

puts "Starting migration from person_id to teammate_id..."

# Tables that need migration
tables_to_migrate = [
  'assignment_check_ins',
  'assignment_tenures', 
  'employment_tenures',
  'huddle_feedbacks',
  'huddle_participants',
  'person_milestones'
]

# Track statistics
stats = {
  total_records: 0,
  migrated_records: 0,
  skipped_records: 0,
  error_records: 0,
  errors: []
}

tables_to_migrate.each do |table_name|
  puts "\n=== Processing #{table_name} ==="
  
  # Get all records that have person_id but no teammate_id
  records_with_person_only = ActiveRecord::Base.connection.execute(
    "SELECT id, person_id FROM #{table_name} WHERE person_id IS NOT NULL AND teammate_id IS NULL"
  )
  
  table_stats = {
    total: records_with_person_only.count,
    migrated: 0,
    skipped: 0,
    errors: 0
  }
  
  puts "Found #{table_stats[:total]} records with person_id but no teammate_id"
  
  records_with_person_only.each do |record|
    person_id = record['person_id']
    record_id = record['id']
    
    begin
      # Find the teammate for this person
      # We need to determine which organization context to use
      # For most tables, we'll need to find the appropriate teammate based on context
      
      teammate_id = case table_name
      when 'assignment_check_ins'
        # For assignment check-ins, find teammate based on assignment's company
        assignment = AssignmentCheckIn.find(record_id).assignment
        teammate = Teammate.find_by(person_id: person_id, organization_id: assignment.company_id)
        teammate&.id
      when 'assignment_tenures'
        # For assignment tenures, find teammate based on assignment's company
        assignment = AssignmentTenure.find(record_id).assignment
        teammate = Teammate.find_by(person_id: person_id, organization_id: assignment.company_id)
        teammate&.id
      when 'employment_tenures'
        # For employment tenures, find teammate based on company
        employment_tenure = EmploymentTenure.find(record_id)
        teammate = Teammate.find_by(person_id: person_id, organization_id: employment_tenure.company_id)
        teammate&.id
      when 'huddle_feedbacks'
        # For huddle feedbacks, find teammate based on huddle's organization
        huddle_feedback = HuddleFeedback.find(record_id)
        # Huddles don't directly have organization, need to find through playbook
        if huddle_feedback.huddle.huddle_playbook
          teammate = Teammate.find_by(person_id: person_id, organization_id: huddle_feedback.huddle.huddle_playbook.organization_id)
        end
        teammate&.id
      when 'huddle_participants'
        # For huddle participants, find teammate based on huddle's organization
        huddle_participant = HuddleParticipant.find(record_id)
        # Huddles don't directly have organization, need to find through playbook
        if huddle_participant.huddle.huddle_playbook
          teammate = Teammate.find_by(person_id: person_id, organization_id: huddle_participant.huddle.huddle_playbook.organization_id)
        end
        teammate&.id
      when 'person_milestones'
        # For person milestones, find teammate based on ability's organization
        person_milestone = PersonMilestone.find(record_id)
        teammate = Teammate.find_by(person_id: person_id, organization_id: person_milestone.ability.organization_id)
        teammate&.id
      end
      
      if teammate_id
        # Update the record with teammate_id
        ActiveRecord::Base.connection.execute(
          "UPDATE #{table_name} SET teammate_id = #{teammate_id} WHERE id = #{record_id}"
        )
        table_stats[:migrated] += 1
        stats[:migrated_records] += 1
      else
        puts "  Warning: No teammate found for person_id #{person_id} in #{table_name} record #{record_id}"
        table_stats[:skipped] += 1
        stats[:skipped_records] += 1
      end
      
    rescue => e
      puts "  Error processing #{table_name} record #{record_id}: #{e.message}"
      table_stats[:errors] += 1
      stats[:error_records] += 1
      stats[:errors] << "#{table_name}:#{record_id} - #{e.message}"
    end
  end
  
  stats[:total_records] += table_stats[:total]
  
  puts "  Migrated: #{table_stats[:migrated]}"
  puts "  Skipped: #{table_stats[:skipped]}"
  puts "  Errors: #{table_stats[:errors]}"
end

puts "\n=== Migration Complete ==="
puts "Total records processed: #{stats[:total_records]}"
puts "Successfully migrated: #{stats[:migrated_records]}"
puts "Skipped (no teammate found): #{stats[:skipped_records]}"
puts "Errors: #{stats[:error_records]}"

if stats[:errors].any?
  puts "\nErrors encountered:"
  stats[:errors].each { |error| puts "  - #{error}" }
end

puts "\nNext steps:"
puts "1. Verify the migration results"
puts "2. Create a migration to remove person_id columns from these tables:"
tables_to_migrate.each { |table| puts "   - #{table}" }
puts "3. Update model associations to remove belongs_to :person"
puts "4. Update any code that references person_id on these models"
