# frozen_string_literal: true

class CreateMaapProposals < ActiveRecord::Migration[8.0]
  def change
    create_table :maap_proposals do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :proposable_type, null: false
      t.bigint :proposable_id, null: false
      t.string :kind, null: false, default: "edit"
      t.string :status, null: false, default: "draft"
      t.references :proposer, null: false, foreign_key: { to_table: :teammates }
      t.references :decided_by, null: true, foreign_key: { to_table: :teammates }
      t.datetime :submitted_at
      t.datetime :decided_at
      t.text :decision_note
      t.string :based_on_semantic_version
      t.string :source, null: false, default: "in_product"
      t.jsonb :proposed_payload, null: false, default: {}
      t.integer :content_schema_version, null: false, default: 1
      t.text :source_markdown
      t.string :applied_version_type

      t.timestamps
    end

    add_index :maap_proposals, [:proposable_type, :proposable_id, :status],
              name: "index_maap_proposals_on_proposable_and_status"
    add_index :maap_proposals, [:organization_id, :status],
              name: "index_maap_proposals_on_organization_and_status"
    add_index :maap_proposals, [:proposer_id, :status],
              name: "index_maap_proposals_on_proposer_and_status"
  end
end
