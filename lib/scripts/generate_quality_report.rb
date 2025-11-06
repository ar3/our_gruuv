#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates comprehensive quality report combining coverage, performance, and RubyCritic analysis
require 'json'
require 'colorize'
require 'fileutils'

class QualityReportGenerator
  def initialize
    @report_dir = 'tmp/quality_reports'
    @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  end

  def generate
    puts "\n📊 GENERATING COMPREHENSIVE QUALITY REPORT\n".cyan.bold
    puts "=" * 80
    
    FileUtils.mkdir_p(@report_dir)
    
    report = {
      timestamp: Time.now.iso8601,
      coverage: generate_coverage_report,
      performance: generate_performance_report,
      summary: generate_summary
    }
    
    save_report(report)
    print_summary(report)
    
    puts "\n✅ Quality report saved to #{@report_dir}/report_#{@timestamp}.json".green
    puts "   Open #{@report_dir}/report_#{@timestamp}.html in your browser for detailed analysis.".green
  end

  private

  def generate_coverage_report
    puts "\n📈 Analyzing Coverage...".yellow
    # Coverage data will be populated after running specs
    {
      method: 'SimpleCov',
      status: coverage_data_exists? ? 'complete' : 'pending',
      note: coverage_data_exists? ? 
        'Coverage data available. Run rake quality:coverage to view report.' : 
        'Run specs first to generate coverage data.'
    }
  end

  def generate_performance_report
    puts "\n⏱️  Analyzing Performance...".yellow
    {
      method: 'RSpec timing',
      status: examples_file_exists? ? 'complete' : 'pending',
      note: examples_file_exists? ? 
        'Performance data available.' : 
        'Run specs with --format json to analyze performance.'
    }
  end

  def generate_summary
    puts "\n💡 Generating Summary...".yellow
    
    coverage_status = coverage_data_exists? ? '✅ Data available' : '⚠️  Run specs to generate'
    perf_status = examples_file_exists? ? '✅ Data available' : '⚠️  No timing data'
    rubycritic_status = rubycritic_data_exists? ? '✅ Analysis complete' : '⚠️  Run rubycritic'
    
    {
      overall: 'Review individual reports for detailed analysis',
      next_steps: [
        'Run: rake quality:coverage   - View coverage report',
        'Run: bundle exec rubycritic - View code quality scores',
        'Run: ruby lib/scripts/analyze_spec_performance.rb - Analyze slow tests',
        'Review app files with lowest coverage for testing gaps',
        'Review slowest system specs for optimization opportunities'
      ],
      tools_status: {
        coverage: coverage_status,
        performance: perf_status,
        rubycritic: rubycritic_status
      }
    }
  end

  def coverage_data_exists?
    File.exist?('coverage/.resultset.json') || File.exist?('coverage/index.html')
  end

  def examples_file_exists?
    File.exist?('spec/examples.json') || File.exist?('spec/examples.txt')
  end

  def rubycritic_data_exists?
    Dir.glob('tmp/rubycritic/**/*').any?
  end

  def save_report(report)
    json_file = File.join(@report_dir, "report_#{@timestamp}.json")
    File.write(json_file, JSON.pretty_generate(report))
    
    # Generate simple HTML report
    html_file = File.join(@report_dir, "report_#{@timestamp}.html")
    File.write(html_file, generate_html_report(report))
  end

  def generate_html_report(report)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Quality Report - #{@timestamp}</title>
        <style>
          body { font-family: -apple-system, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
          h1 { color: #333; }
          .section { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 5px; }
          .status { display: inline-block; padding: 5px 10px; border-radius: 3px; }
          .success { background: #d4edda; color: #155724; }
          .warning { background: #fff3cd; color: #856404; }
          .next-steps { background: #e7f3ff; padding: 15px; border-radius: 5px; }
          .next-steps ul { list-style-position: inside; }
          pre { background: #f8f8f8; padding: 10px; overflow-x: auto; }
        </style>
      </head>
      <body>
        <h1>📊 Quality Report</h1>
        <p><strong>Generated:</strong> #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
        
        <div class="section">
          <h2>Summary</h2>
          <p>#{report[:summary][:overall]}</p>
          
          <h3>Tools Status</h3>
          <ul>
            <li>Coverage: <span class="status #{report[:summary][:tools_status][:coverage].include?('✅') ? 'success' : 'warning'}">#{report[:summary][:tools_status][:coverage]}</span></li>
            <li>Performance: <span class="status #{report[:summary][:tools_status][:performance].include?('✅') ? 'success' : 'warning'}">#{report[:summary][:tools_status][:performance]}</span></li>
            <li>RubyCritic: <span class="status #{report[:summary][:tools_status][:rubycritic].include?('✅') ? 'success' : 'warning'}">#{report[:summary][:tools_status][:rubycritic]}</span></li>
          </ul>
        </div>
        
        <div class="section">
          <h2>Next Steps</h2>
          <div class="next-steps">
            <ul>
              #{report[:summary][:next_steps].map { |step| "<li>#{step}</li>" }.join("\n")}
            </ul>
          </div>
        </div>
        
        <div class="section">
          <h2>Recommendations for AI-Assisted Development</h2>
          <ol>
            <li><strong>Before AI generates code:</strong> Run <code>rake quality:coverage</code> to see what's already tested</li>
            <li><strong>After AI generates specs:</strong> Check if specs are redundant by reviewing coverage report</li>
            <li><strong>Weekly:</strong> Run <code>rake quality:full</code> to catch quality issues early</li>
            <li><strong>When feeling "sloppy":</strong> Run <code>bundle exec rubycritic</code> to identify complexity issues</li>
            <li><strong>Before refactoring:</strong> Review RubyCritic scores to identify complex code that needs simplification</li>
          </ol>
        </div>
        
        <div class="section">
          <h2>Full Report Data</h2>
          <pre>#{JSON.pretty_generate(report)}</pre>
        </div>
      </body>
      </html>
    HTML
  end

  def print_summary(report)
    puts "\n" + "=" * 80
    puts "\n📋 REPORT SUMMARY".cyan.bold
    puts "-" * 80
    
    report[:summary][:next_steps].each do |step|
      puts "  • #{step}"
    end
    
    puts "\n💡 QUICK ACTIONS".blue.bold
    puts "-" * 80
    puts "  rake quality:coverage    - Generate coverage report"
    puts "  rake quality:specs       - Analyze spec performance"
    puts "  rake quality:critique    - Run RubyCritic analysis"
    puts "  rake quality:full       - Complete quality check"
    puts "\n"
  end
end

if __FILE__ == $0
  QualityReportGenerator.new.generate
end







