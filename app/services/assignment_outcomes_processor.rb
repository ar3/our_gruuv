class AssignmentOutcomesProcessor
  attr_reader :assignment, :outcomes_text, :created_count, :skipped_count

  def initialize(assignment, outcomes_text)
    @assignment = assignment
    @outcomes_text = outcomes_text.to_s
    @created_count = 0
    @skipped_count = 0
  end

  def process
    return if @outcomes_text.blank?

    # Split by newlines, strip whitespace, and filter out empty lines
    descriptions = @outcomes_text.split("\n").map(&:strip).reject(&:blank?)

    descriptions.each do |description|
      process_outcome(description)
    end
  end

  private

  def process_outcome(description)
    # Check if outcome with exact same description already exists
    existing = AssignmentOutcome.find_by(
      assignment: @assignment,
      description: description
    )

    if existing
      # Skip existing outcomes - they may have attributes defined
      @skipped_count += 1
      return
    end

    # Determine type based on content
    outcome_type = if description.downcase.match?(/agree:|agrees:/)
      'sentiment'
    else
      'quantitative'
    end

    # Create new outcome
    AssignmentOutcome.create!(
      assignment: @assignment,
      description: description,
      outcome_type: outcome_type
    )

    @created_count += 1
  end
end
