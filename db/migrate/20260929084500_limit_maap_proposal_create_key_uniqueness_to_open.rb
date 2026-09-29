# frozen_string_literal: true

class LimitMaapProposalCreateKeyUniquenessToOpen < ActiveRecord::Migration[8.0]
  def change
    remove_index :maap_proposals,
                 name: "index_maap_proposals_on_organization_and_create_key"

    add_index :maap_proposals, [:organization_id, :create_key],
              unique: true,
              where: "create_key IS NOT NULL AND status IN ('draft', 'submitted')",
              name: "index_maap_proposals_on_organization_and_create_key"
  end
end
