#!/usr/bin/env ruby
# Verification script to check data integrity before migrating person_id to teammate_id
# Run this in production console: load 'lib/scripts/verify_person_to_teammate_migration.rb'

puts "Verifying data integrity before migration..."

# Tables that will be migrated
tables_to_check = [
  'assignment_check_ins',
  'assignment_tenures', 
  'employment_tenures',
  'huddle_feedbacks',
  'huddle_participants',
  'person_milestones'
]

verification_results = {}

tables_to_check.each do |table_name|
  puts "\n=== Checking #{table_name} ==="
  
  # Check for records with person_id but no teammate_id
  records_with_person_only = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} WHERE person_id IS NOT NULL AND teammate_id IS NULL"
  ).first['count']
  
  # Check for records with teammate_id but no person_id
  records_with_teammate_only = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} WHERE teammate_id IS NOT NULL AND person_id IS NULL"
  ).first['count']
  
  # Check for records with both person_id and teammate_id
  records_with_both = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} WHERE person_id IS NOT NULL AND teammate_id IS NOT NULL"
  ).first['count']
  
  # Check for records with neither
  records_with_neither = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} WHERE person_id IS NULL AND teammate_id IS NULL"
  ).first['count']
  
  # Check for potential data integrity issues
  integrity_issues = []
  
  # Check if person_id references exist in people table
  orphaned_person_refs = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} t 
     LEFT JOIN people p ON t.person_id = p.id 
     WHERE t.person_id IS NOT NULL AND p.id IS NULL"
  ).first['count']
  
  # Check if teammate_id references exist in teammates table
  orphaned_teammate_refs = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM #{table_name} t 
     LEFT JOIN teammates tm ON t.teammate_id = tm.id 
     WHERE t.teammate_id IS NOT NULL AND tm.id IS NULL"
  ).first['count']
  
  if orphaned_person_refs > 0
    integrity_issues << "#{orphaned_person_refs} orphaned person_id references"
  end
  
  if orphaned_teammate_refs > 0
    integrity_issues << "#{orphaned_teammate_refs} orphaned teammate_id references"
  end
  
  verification_results[table_name] = {
    records_with_person_only: records_with_person_only,
    records_with_teammate_only: records_with_teammate_only,
    records_with_both: records_with_both,
    records_with_neither: records_with_neither,
    integrity_issues: integrity_issues
  }
  
  puts "  Records with person_id only: #{records_with_person_only}"
  puts "  Records with teammate_id only: #{records_with_teammate_only}"
  puts "  Records with both: #{records_with_both}"
  puts "  Records with neither: #{records_with_neither}"
  
  if integrity_issues.any?
    puts "  ⚠️  Integrity issues found:"
    integrity_issues.each { |issue| puts "    - #{issue}" }
  else
    puts "  ✅ No integrity issues found"
  end
end

# Summary
puts "\n=== Verification Summary ==="
total_records_to_migrate = verification_results.values.sum { |v| v[:records_with_person_only] }
total_integrity_issues = verification_results.values.sum { |v| v[:integrity_issues].count }

puts "Total records that will be migrated: #{total_records_to_migrate}"
puts "Total integrity issues found: #{total_integrity_issues}"

if total_integrity_issues > 0
  puts "\n⚠️  WARNING: Integrity issues found. Please resolve these before running the migration."
  verification_results.each do |table, results|
    if results[:integrity_issues].any?
      puts "\n#{table}:"
      results[:integrity_issues].each { |issue| puts "  - #{issue}" }
    end
  end
else
  puts "\n✅ All checks passed. Safe to proceed with migration."
end

puts "\nTables that will be affected:"
tables_to_check.each do |table|
  count = verification_results[table][:records_with_person_only]
  puts "  - #{table}: #{count} records to migrate"
end
