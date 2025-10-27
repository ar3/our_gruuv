#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyzes spec coverage and identifies redundant or missing tests
require 'json'
require 'simplecov'
require 'colorize'

class SpecCoverageAnalyzer
  def initialize
    @coverage_file = 'coverage/.resultset.json'
    @report = {}
  end

  def analyze
    unless File.exist?(@coverage_file)
      puts "❌ No coverage data found. Run 'bundle exec rspec' first to generate coverage.".red
      exit 1
    end

    load_coverage_data
    generate_report
    print_report
  end

  private

  def load_coverage_data
    raw_data = File.read(@coverage_file)
    @coverage_data = JSON.parse(raw_data)
  end

  def generate_report
    @coverage_data.each do |_command, data|
      data['coverage']&.each do |file, coverage_array|
        next unless file.start_with?('app/')
        next if file.include?('helpers/application_helper.rb')

        analyze_file(file, coverage_array)
      end
    end
  end

  def analyze_file(file, coverage_array)
    line_count = coverage_array.compact.size
    covered_lines = coverage_array.count { |line| line && line > 0 }
    total_lines = coverage_array.size
    
    coverage_percent = line_count.positive? ? (covered_lines.to_f / line_count * 100).round(2) : 0
    
    @report[file] = {
      total_lines: total_lines,
      line_count: line_count,
      covered_lines: covered_lines,
      coverage_percent: coverage_percent,
      uncovered_lines: find_uncovered_lines(coverage_array)
    }
  end

  def find_uncovered_lines(coverage_array)
    uncovered = []
    coverage_array.each_with_index do |line, index|
      if line == 0
        uncovered << index + 1
      end
    end
    uncovered
  end

  def print_report
    puts "\n📊 SPEC COVERAGE ANALYSIS\n".cyan.bold
    puts "=" * 80
    
    files = @report.sort_by { |_file, data| -data[:coverage_percent] }
    
    # Summary statistics
    total_files = files.size
    avg_coverage = files.sum { |_f, d| d[:coverage_percent] } / total_files.to_f
    
    high_coverage = files.count { |_f, d| d[:coverage_percent] >= 90 }
    medium_coverage = files.count { |_f, d| d[:coverage_percent] >= 50 && d[:coverage_percent] < 90 }
    low_coverage = files.count { |_f, d| d[:coverage_percent] < 50 }
    
    puts "\n📈 SUMMARY".green.bold
    puts "-" * 80
    printf "  Total Files Analyzed:    %d\n", total_files
    printf "  Average Coverage:        %.1f%%\n", avg_coverage
    printf "  High Coverage (≥90%%):    %d files\n", high_coverage
    printf "  Medium Coverage (50-89%%): %d files\n", medium_coverage
    printf "  Low Coverage (<50%%):     %d files\n", low_coverage
    
    # Low coverage files
    puts "\n⚠️  LOW COVERAGE FILES (<50%)".yellow.bold
    puts "-" * 80
    low_files = files.select { |_f, d| d[:coverage_percent] < 50 }
    if low_files.any?
      low_files.first(10).each do |file, data|
        puts sprintf("  %s: %.1f%% (%d/%d lines)", file, data[:coverage_percent], 
                     data[:covered_lines], data[:line_count])
      end
      puts "  ... and #{low_files.size - 10} more" if low_files.size > 10
    else
      puts "  ✅ All files have adequate coverage!"
    end
    
    # High coverage (potentially over-tested)
    puts "\n📝 HIGH COVERAGE FILES (May Be Over-Tested)".magenta.bold
    puts "-" * 80
    high_files = files.select { |_f, d| d[:coverage_percent] >= 95 }
    if high_files.any?
      puts "  Files with very high coverage (may have redundant specs):"
      high_files.first(10).each do |file, data|
        puts sprintf("  %s: %.1f%%", file, data[:coverage_percent])
      end
    end
    
    # Recommendations
    puts "\n💡 RECOMMENDATIONS".blue.bold
    puts "-" * 80
    if low_files.size > total_files * 0.1
      puts "  ⚠️  More than 10% of files have low coverage."
      puts "      Consider adding specs for these files."
    end
    
    if avg_coverage > 95
      puts "  💭 Very high average coverage may indicate over-testing."
      puts "      Focus on testing complex logic rather than simple CRUD."
    end
    
    if high_files.size > total_files * 0.3
      puts "  💭 Many files have very high coverage."
      puts "      Check for redundant specs that test the same code paths."
    end
    
    # Detailed breakdown by group
    puts "\n📂 COVERAGE BY GROUP".cyan.bold
    puts "-" * 80
    groups = {
      'Models' => files.select { |f, _| f.include?('/models/') },
      'Controllers' => files.select { |f, _| f.include?('/controllers/') },
      'Policies' => files.select { |f, _| f.include?('/policies/') },
      'Services' => files.select { |f, _| f.include?('/services/') },
      'Jobs' => files.select { |f, _| f.include?('/jobs/') }
    }
    
    groups.each do |name, group_files|
      next if group_files.empty?
      avg = group_files.sum { |_f, d| d[:coverage_percent] } / group_files.size.to_f
      low = group_files.count { |_f, d| d[:coverage_percent] < 50 }
      status = low > 0 ? "⚠️ ".yellow : "✅ ".green
      puts sprintf("  %s %s %s (avg: %.1f%%, low: %d files)", status, name, avg, low)
    end
    
    puts "\n" + "=" * 80
    puts "✅ Analysis complete. Review coverage/index.html for detailed reports.".green
  end
end

if __FILE__ == $0
  SpecCoverageAnalyzer.new.analyze
end

