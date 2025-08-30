class AddFilenameToUploadEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :upload_events, :filename, :string
  end
end
