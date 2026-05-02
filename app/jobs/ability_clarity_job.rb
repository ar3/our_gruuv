# frozen_string_literal: true

class AbilityClarityJob < ApplicationJob
  queue_as :default

  def perform(ability_id, maap_agent_run_id)
    ability = Ability.find_by(id: ability_id)
    run = MaapAgentRun.find_by(id: maap_agent_run_id)
    return if ability.nil? || run.nil?

    run.update!(status: 'processing')
    Maap::AbilityClarityRunner.call(ability: ability, maap_agent_run: run)
  end

end
