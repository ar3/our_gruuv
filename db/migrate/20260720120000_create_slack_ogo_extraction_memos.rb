# frozen_string_literal: true

class CreateSlackOgoExtractionMemos < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_ogo_extraction_memos do |t|
      t.references :subject_company_teammate, null: false, foreign_key: { to_table: :teammates },
                   index: { name: "idx_slack_ogo_extraction_memos_on_subject_id" }
      t.string :context_fingerprint, null: false, limit: 64
      t.string :prompt_version, null: false
      t.string :model_id, null: false
      t.string :channel_id, null: false
      t.string :message_ts, null: false
      t.jsonb :raw_items, null: false, default: []

      t.timestamps
    end

    add_index :slack_ogo_extraction_memos,
              %i[subject_company_teammate_id context_fingerprint prompt_version model_id channel_id message_ts],
              unique: true,
              name: "idx_slack_ogo_extraction_memos_uniq"
  end
end
