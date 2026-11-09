# frozen_string_literal: true

class AddPhoneVerifiedAtToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :phone_verified_at, :datetime
  end
end
