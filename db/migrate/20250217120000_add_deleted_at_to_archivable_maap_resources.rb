# frozen_string_literal: true

class AddDeletedAtToArchivableMaapResources < ActiveRecord::Migration[8.0]
  def change
    add_column :assignments, :deleted_at, :datetime
    add_index :assignments, :deleted_at

    add_column :abilities, :deleted_at, :datetime
    add_index :abilities, :deleted_at

    add_column :positions, :deleted_at, :datetime
    add_index :positions, :deleted_at
  end
end
