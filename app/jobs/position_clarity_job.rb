# frozen_string_literal: true

class PositionClarityJob < ApplicationJob
  queue_as :default

  def perform(position_id, maap_agent_run_id)
    position = Position.find_by(id: position_id)
    run = MaapAgentRun.find_by(id: maap_agent_run_id)
    return if position.nil? || run.nil?

    run.update!(status: 'processing')
    Maap::PositionClarityRunner.call(position: position, maap_agent_run: run)
  end
end
