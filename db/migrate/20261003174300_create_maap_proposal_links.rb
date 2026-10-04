# frozen_string_literal: true

class CreateMaapProposalLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :maap_proposal_links do |t|
      t.references :parent_proposal, null: false, foreign_key: { to_table: :maap_proposals }
      t.references :child_proposal, null: false, foreign_key: { to_table: :maap_proposals }
      t.string :role, null: false
      t.timestamps
    end

    add_index :maap_proposal_links,
              %i[parent_proposal_id child_proposal_id role],
              unique: true,
              name: "index_maap_proposal_links_on_parent_child_role"
    add_index :maap_proposal_links, :role
  end
end
