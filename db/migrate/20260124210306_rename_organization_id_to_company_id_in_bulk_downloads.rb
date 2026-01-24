class RenameOrganizationIdToCompanyIdInBulkDownloads < ActiveRecord::Migration[8.0]
  def change
    # Rename the index first if it exists
    if index_exists?(:bulk_downloads, :organization_id, name: 'index_bulk_downloads_on_organization_id')
      rename_index :bulk_downloads, 'index_bulk_downloads_on_organization_id', 'index_bulk_downloads_on_company_id'
    end
    
    # Remove old foreign key and add new one
    remove_foreign_key :bulk_downloads, :organizations if foreign_key_exists?(:bulk_downloads, :organizations)
    
    # Then rename the column
    rename_column :bulk_downloads, :organization_id, :company_id
    
    # Add new foreign key
    add_foreign_key :bulk_downloads, :organizations, column: :company_id
  end
end
