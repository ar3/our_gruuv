class RemovePersonIdFromTables < ActiveRecord::Migration[8.0]
  def up
    # Remove person_id columns from tables that now have teammate_id
    tables_to_update = [
      'assignment_check_ins',
      'assignment_tenures', 
      'employment_tenures',
      'huddle_feedbacks',
      'huddle_participants',
      'person_milestones'
    ]

    tables_to_update.each do |table_name|
      if column_exists?(table_name, :person_id)
        # Remove foreign key constraint first
        if foreign_key_exists?(table_name, :people)
          remove_foreign_key table_name, :people
          puts "Removed foreign key constraint from #{table_name} to people"
        end

        # Remove indexes that include person_id
        indexes_to_remove = ActiveRecord::Base.connection.indexes(table_name).select do |index|
          index.columns.include?('person_id')
        end

        indexes_to_remove.each do |index|
          remove_index table_name, name: index.name
          puts "Removed index #{index.name} from #{table_name}"
        end

        # Remove the person_id column
        remove_column table_name, :person_id
        puts "Removed person_id column from #{table_name}"
      else
        puts "person_id column does not exist in #{table_name}"
      end
    end
  end

  def down
    # Add back person_id columns
    tables_to_update = [
      'assignment_check_ins',
      'assignment_tenures', 
      'employment_tenures',
      'huddle_feedbacks',
      'huddle_participants',
      'person_milestones'
    ]

    tables_to_update.each do |table_name|
      unless column_exists?(table_name, :person_id)
        add_column table_name, :person_id, :bigint, null: false
        puts "Added person_id column back to #{table_name}"
      end

      # Add back foreign key constraint
      unless foreign_key_exists?(table_name, :people)
        add_foreign_key table_name, :people, column: :person_id
        puts "Added foreign key constraint from #{table_name} to people"
      end

      # Add back indexes (this is a simplified version - you may need to adjust based on your specific needs)
      case table_name
      when 'assignment_check_ins'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:person_id, :assignment_id, :check_in_started_on], 
                  name: "idx_on_person_id_assignment_id_check_in_started_on_f9065653da" unless index_exists?(table_name, [:person_id, :assignment_id, :check_in_started_on])
        add_index table_name, [:person_id, :check_in_started_on], 
                  name: "idx_on_person_id_check_in_started_on_1e9a0aba88" unless index_exists?(table_name, [:person_id, :check_in_started_on])
      when 'assignment_tenures'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:person_id, :assignment_id, :started_at], 
                  name: "idx_on_person_id_assignment_id_started_at_0a6668f47e" unless index_exists?(table_name, [:person_id, :assignment_id, :started_at])
      when 'employment_tenures'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:person_id, :company_id, :started_at], 
                  name: "index_employment_tenures_on_person_company_started" unless index_exists?(table_name, [:person_id, :company_id, :started_at])
      when 'huddle_feedbacks'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:huddle_id, :person_id], 
                  name: "index_huddle_feedbacks_on_huddle_and_person_unique", unique: true unless index_exists?(table_name, [:huddle_id, :person_id])
      when 'huddle_participants'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:huddle_id, :person_id], 
                  name: "index_huddle_participants_on_huddle_and_person_unique", unique: true unless index_exists?(table_name, [:huddle_id, :person_id])
      when 'person_milestones'
        add_index table_name, :person_id unless index_exists?(table_name, :person_id)
        add_index table_name, [:person_id, :ability_id, :milestone_level], 
                  name: "index_person_milestones_on_person_ability_milestone_unique", unique: true unless index_exists?(table_name, [:person_id, :ability_id, :milestone_level])
      end
    end
  end
end