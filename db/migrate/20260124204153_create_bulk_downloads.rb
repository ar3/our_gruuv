class CreateBulkDownloads < ActiveRecord::Migration[8.0]
  def change
    create_table :bulk_downloads do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :downloaded_by, null: false, foreign_key: { to_table: :teammates }, index: true
      t.string :download_type, null: false
      t.string :s3_key, null: false
      t.string :s3_url, null: false
      t.string :filename, null: false
      t.bigint :file_size

      t.timestamps
    end

    add_index :bulk_downloads, :download_type
    add_index :bulk_downloads, :created_at
  end
end
