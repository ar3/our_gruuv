# frozen_string_literal: true

class CreatePossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    create_table :possible_observation_consults do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :creator_company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :display_name, null: false
      t.text :source_text
      t.jsonb :suggested_teammate_ids, null: false, default: []
      t.jsonb :confirmed_teammate_ids, null: false, default: []
      t.string :people_status, null: false, default: "suggested"
      t.string :extraction_status, null: false, default: "ready"
      t.text :extraction_error
      t.jsonb :extractions, null: false, default: {}
      t.timestamps
    end

    add_index :possible_observation_consults, :extraction_status
    add_index :possible_observation_consults, :people_status
  end
end
