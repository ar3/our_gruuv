# frozen_string_literal: true

class NormalizePeopleEmailToLowercase < ActiveRecord::Migration[7.0]
  def up
    Person.where("email != LOWER(email)").find_each do |person|
      person.update_columns(email: person.email.downcase)
    end
  end

  def down
    # No reversible way to restore original casing
  end
end
