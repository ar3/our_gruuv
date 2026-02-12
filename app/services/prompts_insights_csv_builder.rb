# frozen_string_literal: true

require 'csv'

class PromptsInsightsCsvBuilder
  def initialize(company, teammate_ids: nil)
    @company = company
    @teammate_ids = teammate_ids
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << header_row
      open_prompts.find_each { |prompt| csv << data_row(prompt) }
    end
  end

  private

  attr_reader :company, :teammate_ids

  def open_prompts_base
    scope = Prompt
      .open
      .joins('INNER JOIN teammates ON teammates.id = prompts.company_teammate_id')
      .joins(:prompt_template)
      .where(teammates: { organization_id: company.id })
      .where(prompt_templates: { company_id: company.id })
    scope = scope.where(company_teammate_id: teammate_ids) if teammate_ids
    scope
  end

  def open_prompts
    open_prompts_base
      .includes(company_teammate: :person, prompt_template: :prompt_questions, prompt_answers: :prompt_question, prompt_goals: [])
      .order('prompts.created_at')
  end

  def template_ids_with_open_prompts
    @template_ids_with_open_prompts ||= open_prompts_base.reorder(nil).distinct.pluck(:prompt_template_id)
  end

  def max_question_count
    @max_question_count ||= begin
      return 0 if template_ids_with_open_prompts.blank?
      PromptQuestion
        .where(prompt_template_id: template_ids_with_open_prompts)
        .group(:prompt_template_id)
        .count
        .values
        .max || 0
    end
  end

  def header_row
    ['Teammate', 'Prompt template name', 'Date created', 'Goals count'] +
      (1..max_question_count).map { |i| "Question #{i}" }
  end

  def answers_by_position(prompt)
    prompt.prompt_answers.each_with_object({}) do |answer, h|
      h[answer.prompt_question.position] = answer.text.to_s
    end
  end

  def question_labels_by_position(prompt)
    prompt.prompt_template.prompt_questions.each_with_object({}) do |q, h|
      h[q.position] = q.label.to_s
    end
  end

  def data_row(prompt)
    teammate_name = prompt.company_teammate.person&.display_name.to_s
    template_name = prompt.prompt_template.title.to_s
    date_created = prompt.created_at&.strftime('%Y-%m-%d').to_s
    goals_count = prompt.prompt_goals.size
    labels = question_labels_by_position(prompt)
    answers = answers_by_position(prompt)
    answer_cols = (1..max_question_count).map do |pos|
      label = labels[pos].presence || "Question #{pos}"
      answer_text = (answers[pos] || '').to_s
      "#{label}:\n#{answer_text}"
    end
    [teammate_name, template_name, date_created, goals_count] + answer_cols
  end
end
