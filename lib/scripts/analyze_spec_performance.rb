#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyzes spec performance to identify slow tests and bottlenecks
require 'json'
require 'colorize'
require 'time'

class SpecPerformanceAnalyzer
  def initialize
    @results_file = 'spec/examples.txt'
    @report = {
      system_specs: [],
      request_specs: [],
      model_specs: [],
      controller_specs: [],
      other_specs: []
    }
  end

  def analyze
    unless File.exist?(@results_file)
      puts "❌ No spec results found. Run 'bundle exec rspec --format json --out spec/examples.json' first.".red
      puts "   Or run specs normally and this will analyze any existing results.".yellow
      return
    end

    analyze_spec_results
    print_report
  end

  private

  def analyze_spec_results
    examples = parse_examples_file
    
    examples.each do |example|
      time = example[:time]
      file = example[:file]
      
      categorized = categorize_spec(file)
      @report[categorized] << {
        file: file,
        duration: time,
        example: example[:example]
      }
    end
  end

  def parse_examples_file
    examples = []
    current_spec = nil
    
    File.readlines(@results_file).each do |line|
      # Parse RSpec examples.txt format
      if line =~ /^example_id/
        next
      elsif line =~ /^(pending_|last_run_status_|last_fully_verified_run_status_)/
        # Metadata lines, skip
        next
      elsif line =~ /^#{current_spec[:example_id]}/ && current_spec
        parts = line.chomp.split('|')
        current_spec[:time] = parts[1]&.to_f || 0
      else
        # New example ID
        current_spec = { example_id: line.chomp }
      end
    end
    
    # Try JSON format if examples.txt parsing didn't work
    json_file = 'spec/examples.json'
    if File.exist?(json_file)
      examples = JSON.parse(File.read(json_file))['examples'] || []
      return examples.map do |ex|
        {
          file: ex['file_path'],
          example: ex['full_description'],
          time: ex['run_time']
        }
      end
    end
    
    examples
  end

  def categorize_spec(file)
    case file
    when /spec\/system/
      :system_specs
    when /spec\/requests/
      :request_specs
    when /spec\/models/
      :model_specs
    when /spec\/controllers/
      :controller_specs
    else
      :other_specs
    end
  end

  def print_report
    puts "\n⏱️  SPEC PERFORMANCE ANALYSIS\n".cyan.bold
    puts "=" * 80
    
    # Summary
    total_specs = @report.values.sum(&:size)
    total_time = @report.values.flatten.sum { |s| s[:duration] }
    
    puts "\n📊 SUMMARY".green.bold
    puts "-" * 80
    printf "  Total Specs Analyzed:  %d\n", total_specs
    printf "  Total Time:            %.2f seconds\n", total_time
    printf "  Average Time/Spec:      %.3f seconds\n", total_time / total_specs.to_f
    
    # Breakdown by type
    puts "\n📂 SPEC BREAKDOWN BY TYPE".cyan.bold
    puts "-" * 80
    
    @report.each do |category, specs|
      next if specs.empty?
      
      category_name = category.to_s.gsub('_', ' ').capitalize
      avg_time = specs.sum { |s| s[:duration] } / specs.size.to_f
      total_cat_time = specs.sum { |s| s[:duration] }
      
      # Find slowest spec in this category
      slowest = specs.max_by { |s| s[:duration] }
      
      printf "  %-20s: %d specs, %.2fs total, %.3fs avg\n", category_name, specs.size, total_cat_time, avg_time
      if slowest && slowest[:duration] > 1.0
        puts "    Slowest: #{slowest[:file]} (#{slowest[:duration].round(2)}s)".yellow
      end
    end
    
    # Slowest specs overall
    puts "\n🐌 SLOWEST SPECS (> 1 second)".yellow.bold
    puts "-" * 80
    
    all_specs = @report.values.flatten
    slow_specs = all_specs.select { |s| s[:duration] > 1.0 }.sort_by { |s| -s[:duration] }
    
    if slow_specs.any?
      slow_specs.first(15).each do |spec|
        puts sprintf("  %.2fs - %s", spec[:duration], spec[:file])
      end
      
      if slow_specs.size > 15
        puts "  ... and #{slow_specs.size - 15} more slow specs"
      end
    else
      puts "  ✅ No specs taking longer than 1 second!"
    end
    
    # Recommendations
    puts "\n💡 RECOMMENDATIONS".blue.bold
    puts "-" * 80
    
    system_count = @report[:system_specs].size
    total = total_specs
    
    if system_count > total * 0.3
      puts "  ⚠️  System specs make up more than 30% of your test suite."
      puts "      Consider if some can be converted to faster request specs."
    end
    
    if slow_specs.size > 20
      puts "  ⚠️  More than 20 slow specs detected."
      puts "      Review these specs for optimization opportunities."
    end
    
    # Performance balance
    system_ratio = @report[:system_specs].size.to_f / total
    model_ratio = @report[:model_specs].size.to_f / total
    
    if system_ratio > 0.5
      puts "  💭 Test suite is heavily system-test focused."
      puts "      Balance with more unit tests (models/policies)."
    elsif model_ratio < 0.2
      puts "  💭 Few model specs relative to total."
      puts "      Consider adding more unit tests for complex business logic."
    end
    
    puts "\n" + "=" * 80
    puts "✅ Performance analysis complete.".green
  end
end

if __FILE__ == $0
  SpecPerformanceAnalyzer.new.analyze
end




