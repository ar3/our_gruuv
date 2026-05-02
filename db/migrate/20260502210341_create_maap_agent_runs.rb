# frozen_string_literal: true

class CreateMaapAgentRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :maap_agent_runs do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :agent_kind, null: false
      t.string :status, null: false, default: 'pending'
      t.string :clarity_rating
      t.text :output_text
      t.text :error_message
      t.string :prompt_version
      t.string :model_id
      t.references :triggered_by, foreign_key: { to_table: :teammates }, null: true

      t.timestamps
    end

    add_index :maap_agent_runs,
              %i[subject_type subject_id agent_kind],
              unique: true,
              name: 'index_maap_agent_runs_on_subject_and_agent_kind'

    add_index :maap_agent_runs, :status
  end
end
