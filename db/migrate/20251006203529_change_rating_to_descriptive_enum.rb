class ChangeRatingToDescriptiveEnum < ActiveRecord::Migration[8.0]
  def up
    # First, add a temporary string column
    add_column :observation_ratings, :rating_string, :string
    
    # Migrate existing data from integer to string
    execute <<-SQL
      UPDATE observation_ratings 
      SET rating_string = CASE rating
        WHEN 1 THEN 'strongly_disagree'
        WHEN 2 THEN 'disagree'
        WHEN 3 THEN 'na'
        WHEN 4 THEN 'agree'
        WHEN 5 THEN 'strongly_agree'
        ELSE 'na'
      END
    SQL
    
    # Remove the old integer column
    remove_column :observation_ratings, :rating
    
    # Rename the new column to the original name
    rename_column :observation_ratings, :rating_string, :rating
    
    # Add not null constraint and default
    change_column_null :observation_ratings, :rating, false
    change_column_default :observation_ratings, :rating, 'na'
  end

  def down
    # Add a temporary integer column
    add_column :observation_ratings, :rating_int, :integer
    
    # Migrate existing data from string to integer
    execute <<-SQL
      UPDATE observation_ratings 
      SET rating_int = CASE rating
        WHEN 'strongly_disagree' THEN 1
        WHEN 'disagree' THEN 2
        WHEN 'na' THEN 3
        WHEN 'agree' THEN 4
        WHEN 'strongly_agree' THEN 5
        ELSE 3
      END
    SQL
    
    # Remove the string column
    remove_column :observation_ratings, :rating
    
    # Rename the integer column to the original name
    rename_column :observation_ratings, :rating_int, :rating
    
    # Add not null constraint and default
    change_column_null :observation_ratings, :rating, false
    change_column_default :observation_ratings, :rating, 3
  end
end