# frozen_string_literal: true

class CreateClarityLibraryDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :kind, null: false, default: "handbook"
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.datetime :published_at

      t.timestamps
    end

    add_index :documents, [:organization_id, :title]
    add_index :documents, [:owner_type, :owner_id]
    add_index :documents, :kind

    create_table :blocks do |t|
      t.references :document, null: false, foreign_key: true
      t.string :uuid, null: false
      t.string :block_type, null: false, default: "text"
      t.integer :position, null: false, default: 1
      t.text :content
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :blocks, :uuid, unique: true
    add_index :blocks, [:document_id, :position]

    create_table :document_links do |t|
      t.references :document, null: false, foreign_key: true
      t.string :linkable_type, null: false
      t.bigint :linkable_id, null: false

      t.timestamps
    end

    add_index :document_links,
              [:document_id, :linkable_type, :linkable_id],
              unique: true,
              name: "index_document_links_on_document_and_linkable"
    add_index :document_links, [:linkable_type, :linkable_id]
  end
end
