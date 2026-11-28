# frozen_string_literal: true

class AddCanManageClarityLibraryAndRemapDocumentKinds < ActiveRecord::Migration[8.0]
  def up
    add_column :teammates, :can_manage_clarity_library, :boolean, default: false, null: false
    add_index :teammates, :can_manage_clarity_library

    say_with_time "Remap legacy document kinds" do
      execute <<~SQL.squish
        UPDATE documents SET kind = 'how_to' WHERE kind = 'handbook';
        UPDATE documents SET kind = 'reference' WHERE kind = 'general';
      SQL
    end
  end

  def down
    say_with_time "Restore legacy document kinds" do
      execute <<~SQL.squish
        UPDATE documents SET kind = 'handbook' WHERE kind = 'how_to';
        UPDATE documents SET kind = 'general' WHERE kind = 'reference';
      SQL
    end

    remove_index :teammates, :can_manage_clarity_library
    remove_column :teammates, :can_manage_clarity_library
  end
end
