# frozen_string_literal: true

class CreateMcpOauthTables < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_oauth_clients do |t|
      t.string :client_id, null: false
      t.string :client_name
      t.jsonb :redirect_uris, null: false, default: []
      t.string :token_endpoint_auth_method, null: false, default: "none"
      t.jsonb :grant_types, null: false, default: []
      t.jsonb :response_types, null: false, default: []
      t.string :client_uri
      t.string :logo_uri
      t.string :registration_source, null: false, default: "dcr" # dcr | cimd
      t.datetime :expires_at

      t.timestamps
    end
    add_index :mcp_oauth_clients, :client_id, unique: true

    create_table :mcp_oauth_authorization_codes do |t|
      t.string :code_digest, null: false
      t.references :mcp_oauth_client, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :code_challenge_method, null: false, default: "S256"
      t.string :scope, null: false, default: "mcp"
      t.string :resource
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end
    add_index :mcp_oauth_authorization_codes, :code_digest, unique: true

    create_table :mcp_oauth_access_tokens do |t|
      t.string :token_digest, null: false
      t.references :mcp_oauth_client, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :scope, null: false, default: "mcp"
      t.string :resource
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :mcp_oauth_access_tokens, :token_digest, unique: true

    create_table :mcp_oauth_refresh_tokens do |t|
      t.string :token_digest, null: false
      t.references :mcp_oauth_client, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :scope, null: false, default: "mcp offline_access"
      t.string :resource
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :rotated_at

      t.timestamps
    end
    add_index :mcp_oauth_refresh_tokens, :token_digest, unique: true
  end
end
