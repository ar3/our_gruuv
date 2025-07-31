class RemoveUrlFieldsFromAssignments < ActiveRecord::Migration[8.0]
  def change
    remove_column :assignments, :published_source_url, :string
    remove_column :assignments, :draft_source_url, :string
  end
end
