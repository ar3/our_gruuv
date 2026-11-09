# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Person, 'phone verification' do
  it 'clears phone_verified_at when the phone number changes' do
    person = create(:person, unique_textable_phone_number: '+13175550400', phone_verified_at: 1.day.ago)
    person.update!(unique_textable_phone_number: '+13175550401')
    expect(person.reload.phone_verified_at).to be_nil
  end

  it 'normalizes phone on save' do
    person = create(:person, unique_textable_phone_number: '3175550402')
    expect(person.reload.unique_textable_phone_number).to eq('+13175550402')
  end

  it 'finds people by legacy unnormalized phone when login uses E.164' do
    person = create(:person)
    person.update_columns(unique_textable_phone_number: '3172898859')

    expect(Person.find_by_textable_phone('+13172898859')).to eq(person)
    expect(Person.find_by_textable_phone('3172898859')).to eq(person)
  end

  it 'finds people stored as plus + 10 digits when login adds US country code' do
    person = create(:person)
    person.update_columns(unique_textable_phone_number: '+3172866905')

    expect(Person.find_by_textable_phone('3172866905')).to eq(person)
    expect(Person.find_by_textable_phone('+13172866905')).to eq(person)
  end

  it 'canonicalizes legacy phone when marking verified' do
    person = create(:person)
    person.update_columns(unique_textable_phone_number: '+3172866905', phone_verified_at: nil)
    person.mark_phone_verified!
    expect(person.reload.unique_textable_phone_number).to eq('+13172866905')
    expect(person.phone_verified?).to eq(true)
  end
end


