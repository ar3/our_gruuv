class AddVisitCountToPageVisits < ActiveRecord::Migration[8.0]
  def up
    # Truncate existing data (not valuable enough to migrate)
    execute "TRUNCATE TABLE page_visits"
    
    # Remove old index that we're replacing
    remove_index :page_visits, name: "index_page_visits_on_person_id_and_visited_at" if index_exists?(:page_visits, [:person_id, :visited_at], name: "index_page_visits_on_person_id_and_visited_at")
    
    # Add visit_count column
    add_column :page_visits, :visit_count, :integer, default: 1, null: false
    
    # Add unique index on person_id + url
    add_index :page_visits, [:person_id, :url], unique: true, name: "index_page_visits_on_person_id_and_url_unique"
  end
  
  def down
    # Remove unique index
    remove_index :page_visits, name: "index_page_visits_on_person_id_and_url_unique" if index_exists?(:page_visits, [:person_id, :url], name: "index_page_visits_on_person_id_and_url_unique")
    
    # Remove visit_count column
    remove_column :page_visits, :visit_count if column_exists?(:page_visits, :visit_count)
    
    # Restore old index
    add_index :page_visits, [:person_id, :visited_at], name: "index_page_visits_on_person_id_and_visited_at" unless index_exists?(:page_visits, [:person_id, :visited_at], name: "index_page_visits_on_person_id_and_visited_at")
  end
end
