# frozen_string_literal: true

module Auth
  class PhoneRegistrationsController < ApplicationController
    layout 'application'

    before_action :require_verified_unknown_phone

    def new
      @phone = session[:phone_login_phone]
      @person = Person.new
    end

    def create
      @phone = session[:phone_login_phone]
      email = params.dig(:person, :email).to_s.strip.downcase
      first_name = params.dig(:person, :first_name).to_s.strip
      last_name = params.dig(:person, :last_name).to_s.strip

      if email.blank? || first_name.blank?
        @person = Person.new(first_name: first_name, last_name: last_name, email: email)
        @person.errors.add(:base, 'First name and email are required.')
        render :new, status: :unprocessable_entity
        return
      end

      if Person.find_by_email_insensitive(email)
        flash.now[:alert] =
          'That email already belongs to an OurGruuv account. Sign in with Google, then add this phone on your profile.'
        @person = Person.new(first_name: first_name, last_name: last_name, email: email)
        @existing_email = true
        render :new, status: :unprocessable_entity
        return
      end

      @person = Person.new(
        first_name: first_name,
        last_name: last_name,
        email: email,
        unique_textable_phone_number: @phone,
        phone_verified_at: Time.current
      )

      unless @person.save
        render :new, status: :unprocessable_entity
        return
      end

      session.delete(:phone_login_phone)
      session.delete(:phone_login_verified)
      establish_person_session!(@person)
      redirect_to me_path, notice: 'Welcome to OurGruuv. Your phone is verified.'
    end

    private

    def require_verified_unknown_phone
      phone = session[:phone_login_phone]
      unless phone.present? && session[:phone_login_verified]
        redirect_to new_auth_phone_login_path, alert: 'Verify your phone number first.'
        return
      end

      if Person.find_by_textable_phone(phone)
        session.delete(:phone_login_verified)
        redirect_to verify_auth_phone_login_path, alert: 'That phone is already registered. Enter the code again to sign in.'
      end
    end
  end
end
