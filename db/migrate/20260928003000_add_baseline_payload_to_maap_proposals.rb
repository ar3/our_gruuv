# frozen_string_literal: true

class AddBaselinePayloadToMaapProposals < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_proposals, :baseline_payload, :jsonb
  end
end
