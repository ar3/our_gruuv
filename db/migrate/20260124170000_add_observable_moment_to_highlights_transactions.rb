# frozen_string_literal: true

class AddObservableMomentToHighlightsTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :highlights_transactions, :observable_moment, null: true, foreign_key: true, index: true
  end
end
