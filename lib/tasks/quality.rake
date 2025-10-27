namespace :quality do
  desc "Generate coverage report for specs"
  task :coverage do
    puts "📊 Running specs with coverage analysis..."
    system("bundle exec rspec --format progress --no-profile")
    
    if File.exist?('coverage/index.html')
      puts "\n✅ Coverage report generated!"
      puts "   Open coverage/index.html in your browser to view the report."
      puts "   Or run: ruby lib/scripts/analyze_spec_coverage.rb for detailed analysis."
    end
  end

  desc "Run RubyCritic to analyze code quality"
  task :critique do
    puts "🔍 Running RubyCritic code quality analysis..."
    puts "   This analyzes code smells, complexity, and duplication."
    
    system("bundle exec rubycritic app --format html --no-browser")
    
    if Dir.glob('tmp/rubycritic/**/*').any?
      puts "\n✅ RubyCritic analysis complete!"
      puts "   Open tmp/rubycritic/index.html in your browser."
    end
  end

  desc "Analyze spec performance and patterns"
  task :specs do
    puts "⏱️  Analyzing spec performance and patterns..."
    
    if File.exist?('spec/examples.json')
      system("ruby lib/scripts/analyze_spec_performance.rb")
    elsif File.exist?('spec/examples.txt')
      system("ruby lib/scripts/analyze_spec_performance.rb")
    else
      puts "⚠️  No spec timing data found."
      puts "   Running specs with timing enabled..."
      puts "   Run: bundle exec rspec --format progress --format json --out spec/examples.json"
      puts "   Then re-run this task."
    end
  end

  desc "Generate comprehensive quality report"
  task :full do
    puts "📊 Generating comprehensive quality report..."
    
    # Ensure we have recent data
    puts "\n1️⃣ Running coverage analysis..."
    Rake::Task['quality:coverage'].invoke
    
    puts "\n2️⃣ Generating quality report..."
    system("ruby lib/scripts/generate_quality_report.rb")
    
    puts "\n✅ Full quality report complete!"
  end

  desc "Analyze spec coverage for redundancy"
  task coverage_analysis: :environment do
    puts "📈 Analyzing spec coverage for redundant tests..."
    
    system("ruby lib/scripts/analyze_spec_coverage.rb")
  end

  desc "Show all available quality tasks"
  task :help do
    puts "\n📋 QUALITY ANALYSIS TASKS"
    puts "=" * 80
    
    tasks = {
      'rake quality:coverage' => 'Generate coverage report from specs',
      'rake quality:critique' => 'Run RubyCritic code quality analysis',
      'rake quality:specs' => 'Analyze spec performance and patterns',
      'rake quality:full' => 'Complete quality check (coverage + report)',
      'rake quality:coverage_analysis' => 'Detailed coverage redundancy analysis',
      'rake quality:help' => 'Show this help message'
    }
    
    tasks.each do |task, desc|
      puts sprintf("  %-35s %s", task, desc)
    end
    
    puts "\n💡 USAGE RECOMMENDATIONS"
    puts "-" * 80
    puts "  Daily:    Run 'rake quality:coverage' after AI generates specs"
    puts "  Weekly:   Run 'rake quality:specs' to check for slow tests"
    puts "  Periodic: Run 'rake quality:critique' before refactoring"
    puts "  Complete: Run 'rake quality:full' for comprehensive check"
    puts "\n"
  end
end

# Make help the default task
task quality: :"quality:help"

