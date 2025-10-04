#!/usr/bin/env ruby
# Rollback script to undo the person_id to teammate_id migration
# Run this in production console: load 'lib/scripts/rollback_person_to_teammate_migration.rb'

puts "Rolling back migration from teammate_id to person_id..."

# Tables that were migrated
tables_to_rollback = [
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
  rolled_back_records: 0,
  skipped_records: 0,
  error_records: 0,
  errors: []
}

tables_to_rollback.each do |table_name|
  puts "\n=== Processing #{table_name} ==="
  
  # Get all records that have teammate_id but no person_id
  records_with_teammate_only = ActiveRecord::Base.connection.execute(
    "SELECT id, teammate_id FROM #{table_name} WHERE teammate_id IS NOT NULL AND person_id IS NULL"
  )
  
  table_stats = {
    total: records_with_teammate_only.count,
    rolled_back: 0,
    skipped: 0,
    errors: 0
  }
  
  puts "Found #{table_stats[:total]} records with teammate_id but no person_id"
  
  records_with_teammate_only.each do |record|
    teammate_id = record['teammate_id']
    record_id = record['id']
    
    begin
      # Find the person_id from the teammate
      teammate = Teammate.find_by(id: teammate_id)
      
      if teammate
        # Update the record with person_id
        ActiveRecord::Base.connection.execute(
          "UPDATE #{table_name} SET person_id = #{teammate.person_id} WHERE id = #{record_id}"
        )
        table_stats[:rolled_back] += 1
        stats[:rolled_back_records] += 1
      else
        puts "  Warning: Teammate with id #{teammate_id} not found for #{table_name} record #{record_id}"
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
  
  puts "  Rolled back: #{table_stats[:rolled_back]}"
  puts "  Skipped: #{table_stats[:skipped]}"
  puts "  Errors: #{table_stats[:errors]}"
end

puts "\n=== Rollback Complete ==="
puts "Total records processed: #{stats[:total_records]}"
puts "Successfully rolled back: #{stats[:rolled_back_records]}"
puts "Skipped (teammate not found): #{stats[:skipped_records]}"
puts "Errors: #{stats[:error_records]}"

if stats[:errors].any?
  puts "\nErrors encountered:"
  stats[:errors].each { |error| puts "  - #{error}" }
end

puts "\nRollback complete. The person_id columns are now populated again."
