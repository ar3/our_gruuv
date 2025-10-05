class AddMissingColumnsToTeammates < ActiveRecord::Migration[8.0]
  def up
    # Add first_employed_at column if it doesn't exist
    unless column_exists?(:teammates, :first_employed_at)
      add_column :teammates, :first_employed_at, :datetime
      puts "Added first_employed_at column to teammates"
    else
      puts "first_employed_at column already exists in teammates"
    end

    # Add last_terminated_at column if it doesn't exist
    unless column_exists?(:teammates, :last_terminated_at)
      add_column :teammates, :last_terminated_at, :datetime
      puts "Added last_terminated_at column to teammates"
    else
      puts "last_terminated_at column already exists in teammates"
    end

    # Add type column if it doesn't exist
    unless column_exists?(:teammates, :type)
      add_column :teammates, :type, :string
      puts "Added type column to teammates"
    else
      puts "type column already exists in teammates"
    end

    # Add indexes if they don't exist
    unless index_exists?(:teammates, [:first_employed_at, :last_terminated_at])
      add_index :teammates, [:first_employed_at, :last_terminated_at], 
                name: "index_teammates_on_first_employed_at_and_last_terminated_at"
      puts "Added index_teammates_on_first_employed_at_and_last_terminated_at"
    else
      puts "index_teammates_on_first_employed_at_and_last_terminated_at already exists"
    end

    unless index_exists?(:teammates, :first_employed_at)
      add_index :teammates, :first_employed_at, 
                name: "index_teammates_on_first_employed_at"
      puts "Added index_teammates_on_first_employed_at"
    else
      puts "index_teammates_on_first_employed_at already exists"
    end

    unless index_exists?(:teammates, :last_terminated_at)
      add_index :teammates, :last_terminated_at, 
                name: "index_teammates_on_last_terminated_at"
      puts "Added index_teammates_on_last_terminated_at"
    else
      puts "index_teammates_on_last_terminated_at already exists"
    end
  end

  def down
    # Remove indexes if they exist
    if index_exists?(:teammates, :last_terminated_at)
      remove_index :teammates, name: "index_teammates_on_last_terminated_at"
      puts "Removed index_teammates_on_last_terminated_at"
    end

    if index_exists?(:teammates, :first_employed_at)
      remove_index :teammates, name: "index_teammates_on_first_employed_at"
      puts "Removed index_teammates_on_first_employed_at"
    end

    if index_exists?(:teammates, [:first_employed_at, :last_terminated_at])
      remove_index :teammates, name: "index_teammates_on_first_employed_at_and_last_terminated_at"
      puts "Removed index_teammates_on_first_employed_at_and_last_terminated_at"
    end

    # Remove columns if they exist
    if column_exists?(:teammates, :type)
      remove_column :teammates, :type
      puts "Removed type column from teammates"
    end

    if column_exists?(:teammates, :last_terminated_at)
      remove_column :teammates, :last_terminated_at
      puts "Removed last_terminated_at column from teammates"
    end

    if column_exists?(:teammates, :first_employed_at)
      remove_column :teammates, :first_employed_at
      puts "Removed first_employed_at column from teammates"
    end
  end
end