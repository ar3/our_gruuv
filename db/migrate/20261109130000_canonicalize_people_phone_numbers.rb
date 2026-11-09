# frozen_string_literal: true

class CanonicalizePeoplePhoneNumbers < ActiveRecord::Migration[8.0]
  def up
    say_with_time 'Canonicalize unique_textable_phone_number to E.164' do
      Person.reset_column_information
      Person.where.not(unique_textable_phone_number: [nil, '']).find_each do |person|
        normalized = PhoneNumberNormalizer.call(person.unique_textable_phone_number)
        next if normalized.blank? || normalized == person.unique_textable_phone_number

        conflict = Person.where(unique_textable_phone_number: normalized).where.not(id: person.id).exists?
        if conflict
          say "skip person #{person.id}: #{person.unique_textable_phone_number.inspect} → #{normalized} (conflict)", true
          next
        end

        person.update_columns(unique_textable_phone_number: normalized, updated_at: Time.current)
      end
    end
  end

  def down
    # Irreversible: original formatting is not retained.
  end
end
