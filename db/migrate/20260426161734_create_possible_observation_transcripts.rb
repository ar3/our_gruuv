class CreatePossibleObservationTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :possible_observation_transcripts do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.references :creator_company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :display_name, null: false
      t.jsonb :extractions, null: false, default: {}
      t.string :extraction_status, null: false, default: "pending"
      t.text :extraction_error

      t.timestamps
    end

    add_index :possible_observation_transcripts, :extraction_status
  end
end
