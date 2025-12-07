class RenameUploadEventsToBulkSyncEvents < ActiveRecord::Migration[8.0]
  def up
    # Rename table
    rename_table :upload_events, :bulk_sync_events
    
    # Rename file_content column to source_contents
    rename_column :bulk_sync_events, :file_content, :source_contents
    
    # Add source_data JSONB column for metadata
    add_column :bulk_sync_events, :source_data, :jsonb, default: {}
    
    # Populate source_data for existing records
    execute <<-SQL
      UPDATE bulk_sync_events
      SET source_data = jsonb_build_object(
        'type', 'file_upload',
        'filename', filename,
        'file_size', LENGTH(source_contents),
        'uploaded_at', created_at
      )
      WHERE source_data = '{}'::jsonb;
    SQL
    
    # Update foreign key references in other tables (if any)
    # Note: Rails typically handles this automatically, but we'll check for any manual references
    
    # Update STI type column values if needed
    # Keep existing type values for backward compatibility during transition
  end

  def down
    # Remove source_data column
    remove_column :bulk_sync_events, :source_data
    
    # Rename source_contents back to file_content
    rename_column :bulk_sync_events, :source_contents, :file_content
    
    # Rename table back
    rename_table :bulk_sync_events, :upload_events
  end
end
