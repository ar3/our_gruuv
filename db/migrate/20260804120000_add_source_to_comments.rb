class AddSourceToComments < ActiveRecord::Migration[8.0]
  def change
    add_reference :comments, :source, polymorphic: true, null: true, index: true
  end
end
