class RenamePositionTypesToTitles < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :positions, :position_types
    remove_foreign_key :seats, :position_types
    remove_foreign_key :position_types, :organizations
    remove_foreign_key :position_types, :position_major_levels

    rename_table :position_types, :titles

    rename_column :positions, :position_type_id, :title_id
    rename_column :seats, :position_type_id, :title_id

    # Rename indexes only if they exist
    if index_exists?(:titles, 'index_position_types_on_org_level_title_unique')
      rename_index :titles, 'index_position_types_on_org_level_title_unique', 'index_titles_on_org_level_title_unique'
    end
    if index_exists?(:titles, 'index_position_types_on_organization_id')
      rename_index :titles, 'index_position_types_on_organization_id', 'index_titles_on_organization_id'
    end
    if index_exists?(:titles, 'index_position_types_on_position_major_level_id')
      rename_index :titles, 'index_position_types_on_position_major_level_id', 'index_titles_on_position_major_level_id'
    end
    # Rename indexes only if they exist
    if index_exists?(:positions, 'index_positions_on_position_type_id')
      rename_index :positions, 'index_positions_on_position_type_id', 'index_positions_on_title_id'
    end
    if index_exists?(:positions, 'index_positions_on_type_and_level_unique')
      rename_index :positions, 'index_positions_on_type_and_level_unique', 'index_positions_on_title_and_level_unique'
    end
    if index_exists?(:seats, 'index_seats_on_position_type_id')
      rename_index :seats, 'index_seats_on_position_type_id', 'index_seats_on_title_id'
    end
    if index_exists?(:seats, 'index_seats_on_position_type_and_needed_by')
      rename_index :seats, 'index_seats_on_position_type_and_needed_by', 'index_seats_on_title_and_needed_by'
    end

    add_foreign_key :titles, :organizations
    add_foreign_key :titles, :position_major_levels
    add_foreign_key :positions, :titles
    add_foreign_key :seats, :titles
  end

  def down
    remove_foreign_key :positions, :titles
    remove_foreign_key :seats, :titles
    remove_foreign_key :titles, :organizations
    remove_foreign_key :titles, :position_major_levels

    rename_index :seats, 'index_seats_on_title_and_needed_by', 'index_seats_on_position_type_and_needed_by'
    rename_index :seats, 'index_seats_on_title_id', 'index_seats_on_position_type_id'
    rename_index :positions, 'index_positions_on_title_and_level_unique', 'index_positions_on_type_and_level_unique'
    rename_index :positions, 'index_positions_on_title_id', 'index_positions_on_position_type_id'
    rename_index :titles, 'index_titles_on_position_major_level_id', 'index_position_types_on_position_major_level_id'
    rename_index :titles, 'index_titles_on_organization_id', 'index_position_types_on_organization_id'
    rename_index :titles, 'index_titles_on_org_level_title_unique', 'index_position_types_on_org_level_title_unique'

    rename_column :positions, :title_id, :position_type_id
    rename_column :seats, :title_id, :position_type_id

    rename_table :titles, :position_types

    add_foreign_key :position_types, :organizations
    add_foreign_key :position_types, :position_major_levels
    add_foreign_key :positions, :position_types
    add_foreign_key :seats, :position_types
  end
end
