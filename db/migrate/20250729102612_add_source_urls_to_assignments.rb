class AddSourceUrlsToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :assignments, :published_source_url, :string
    add_column :assignments, :draft_source_url, :string
  end
end
