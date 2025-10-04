class AddTypeToUploadEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :upload_events, :type, :string
    
    # Set default type for existing records based on their file content or other attributes
    # We'll need to make an educated guess about existing records
    reversible do |dir|
      dir.up do
        # For now, we'll set all existing records to UploadAssignmentCheckins
        # If there are any unassigned employee uploads, they'll need manual migration
        execute "UPDATE upload_events SET type = 'UploadAssignmentCheckins'"
      end
    end
  end
end
