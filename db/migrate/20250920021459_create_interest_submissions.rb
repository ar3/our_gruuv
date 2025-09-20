class CreateInterestSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :interest_submissions do |t|
      t.text :thing_interested_in
      t.text :why_interested
      t.text :current_solution
      t.string :source_page
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end
  end
end
