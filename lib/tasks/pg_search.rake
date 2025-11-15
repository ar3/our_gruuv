namespace :pg_search do
  desc "Check if PgSearch indexes are in sync"
  task check: :environment do
    puts "🔍 Checking PgSearch index health..."
    puts "=" * 80

    result = PgSearchHealthService.check

    if result[:healthy]
      puts "✅ All search indexes are healthy!"
    else
      puts "⚠️  Some search indexes are out of sync:"
    end

    puts "\n"

    result[:models].each do |model_name, model_result|
      status = model_result[:healthy] ? "✅" : "❌"
      puts "#{status} #{model_name}:"
      puts "   Actual records: #{model_result[:actual_count]}"
      puts "   Search documents: #{model_result[:search_doc_count]}"
      puts "   Difference: #{model_result[:difference]}"
      puts "   Orphaned documents: #{model_result[:orphaned_count]}"

      if model_result[:missing_sample][:count] > 0
        puts "   ⚠️  Missing documents (sample): #{model_result[:missing_sample][:count]}"
        puts "   Estimated total missing: ~#{model_result[:missing_sample][:estimated_total_missing]}"
      end

      puts ""
    end

    puts "Timestamp: #{result[:timestamp]}"
    puts "=" * 80

    exit(result[:healthy] ? 0 : 1)
  end

  desc "Rebuild all PgSearch indexes"
  task rebuild: :environment do
    puts "🔨 Rebuilding all PgSearch indexes..."
    puts "=" * 80

    result = PgSearchHealthService.rebuild_all

    result[:models].each do |model_name, model_result|
      puts "✅ #{model_name}:"
      puts "   Rebuilt #{model_result[:record_count]} records"
      puts "   Duration: #{model_result[:duration_seconds]}s"
      puts ""
    end

    puts "Timestamp: #{result[:timestamp]}"
    puts "=" * 80
    puts "✅ All indexes rebuilt successfully!"
  end

  desc "Check and rebuild if needed"
  task check_and_rebuild: :environment do
    puts "🔍 Checking PgSearch index health..."
    result = PgSearchHealthService.check

    if result[:healthy]
      puts "✅ All search indexes are healthy - no rebuild needed!"
      exit(0)
    else
      puts "⚠️  Indexes are out of sync. Rebuilding..."
      puts ""
      Rake::Task["pg_search:rebuild"].invoke
    end
  end
end


