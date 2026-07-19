# frozen_string_literal: true

class RemovePossibleObservationSlackSearchFromObservations < ActiveRecord::Migration[8.0]
  def change
    remove_reference :observations, :possible_observation_slack_search, foreign_key: true
  end
end
