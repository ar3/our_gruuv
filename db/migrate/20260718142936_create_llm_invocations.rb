# frozen_string_literal: true

class CreateLlmInvocations < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_invocations do |t|
      t.string :purpose, null: false
      t.string :model_id, null: false
      t.string :status, null: false, default: 'pending'
      t.text :error_message
      t.string :prompt_version

      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cached_tokens
      t.integer :cache_creation_tokens
      t.bigint :cost_micros

      t.bigint :organization_id
      t.bigint :triggered_by_teammate_id

      t.string :parent_type
      t.bigint :parent_id

      t.datetime :started_at
      t.datetime :finished_at
      t.integer :duration_ms

      t.timestamps
    end

    add_index :llm_invocations, :purpose
    add_index :llm_invocations, :organization_id
    add_index :llm_invocations, [:parent_type, :parent_id]
    add_index :llm_invocations, [:purpose, :status, :finished_at]
    add_index :llm_invocations, :triggered_by_teammate_id
  end
end
