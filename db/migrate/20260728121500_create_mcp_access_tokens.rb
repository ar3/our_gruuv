# frozen_string_literal: true

class CreateMcpAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_access_tokens do |t|
      t.references :person, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :token_digest, null: false
      t.string :name, null: false, default: "Claude Desktop"
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :mcp_access_tokens, :token_digest, unique: true
    add_index :mcp_access_tokens, :revoked_at
  end
end
