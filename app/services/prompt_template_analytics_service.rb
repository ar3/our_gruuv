class PromptTemplateAnalyticsService
  def initialize(prompt_template)
    @prompt_template = prompt_template
  end

  def call
    {
      closed_prompts: calculate_closed_prompts_analytics,
      open_prompts: calculate_open_prompts_analytics
    }
  end

  private

  def calculate_closed_prompts_analytics
    closed_prompts = @prompt_template.prompts.closed.includes(:prompt_answers, :company_teammate)
    
    return empty_analytics if closed_prompts.empty?
    
    employee_count = closed_prompts
      .distinct
      .count('company_teammate_id')
    
    prompt_count = closed_prompts.count
    
    # Calculate average completed questions
    total_questions = @prompt_template.prompt_questions.active.count
    return empty_analytics.merge(employee_count: employee_count, prompt_count: prompt_count, avg_completed_questions: "0/#{total_questions}") if total_questions == 0
    
    completed_counts = closed_prompts.map do |prompt|
      completed = prompt.prompt_answers.joins(:prompt_question)
        .where(prompt_questions: { archived_at: nil })
        .where('LENGTH(COALESCE(prompt_answers.text, \'\')) > 5')
        .count
      completed
    end
    
    avg_completed = completed_counts.any? ? (completed_counts.sum.to_f / completed_counts.size).round(1) : 0
    avg_completed_int = avg_completed.to_i
    
    {
      employee_count: employee_count,
      prompt_count: prompt_count,
      avg_completed_questions: "#{avg_completed_int}/#{total_questions}"
    }
  end

  def calculate_open_prompts_analytics
    open_prompts = @prompt_template.prompts.open.includes(:prompt_answers, :company_teammate)
    
    return empty_analytics if open_prompts.empty?
    
    employee_count = open_prompts
      .distinct
      .count('company_teammate_id')
    
    prompt_count = open_prompts.count
    
    # Calculate average completed questions
    total_questions = @prompt_template.prompt_questions.active.count
    return empty_analytics.merge(employee_count: employee_count, prompt_count: prompt_count, avg_completed_questions: "0/#{total_questions}") if total_questions == 0
    
    completed_counts = open_prompts.map do |prompt|
      completed = prompt.prompt_answers.joins(:prompt_question)
        .where(prompt_questions: { archived_at: nil })
        .where('LENGTH(COALESCE(prompt_answers.text, \'\')) > 5')
        .count
      completed
    end
    
    avg_completed = completed_counts.any? ? (completed_counts.sum.to_f / completed_counts.size).round(1) : 0
    avg_completed_int = avg_completed.to_i
    
    {
      employee_count: employee_count,
      prompt_count: prompt_count,
      avg_completed_questions: "#{avg_completed_int}/#{total_questions}"
    }
  end

  def empty_analytics
    {
      employee_count: 0,
      prompt_count: 0,
      avg_completed_questions: "0/0"
    }
  end
end

