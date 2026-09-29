# frozen_string_literal: true

class AddDecisionWarningsToMaapProposals < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_proposals, :decision_warnings, :jsonb, null: false, default: []
  end
end
