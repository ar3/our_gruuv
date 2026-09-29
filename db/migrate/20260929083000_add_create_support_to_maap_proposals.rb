# frozen_string_literal: true

class AddCreateSupportToMaapProposals < ActiveRecord::Migration[8.0]
  def change
    change_column_null :maap_proposals, :proposable_type, true
    change_column_null :maap_proposals, :proposable_id, true

    add_column :maap_proposals, :create_key, :string

    add_index :maap_proposals, [:organization_id, :create_key],
              unique: true,
              where: "create_key IS NOT NULL",
              name: "index_maap_proposals_on_organization_and_create_key"
    add_index :maap_proposals, [:organization_id, :kind, :status],
              name: "index_maap_proposals_on_organization_kind_and_status"
  end
end
