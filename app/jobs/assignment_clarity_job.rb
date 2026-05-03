# frozen_string_literal: true

class AssignmentClarityJob < ApplicationJob
  queue_as :default

  def perform(assignment_id, maap_agent_run_id)
    assignment = Assignment.find_by(id: assignment_id)
    run = MaapAgentRun.find_by(id: maap_agent_run_id)
    return if assignment.nil? || run.nil?

    run.update!(status: 'processing')
    Maap::AssignmentClarityRunner.call(assignment: assignment, maap_agent_run: run)
  end
end
