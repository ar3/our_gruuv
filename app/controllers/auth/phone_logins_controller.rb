# frozen_string_literal: true

module Auth
  class PhoneLoginsController < ApplicationController
    layout 'application'

    before_action :redirect_if_already_signed_in, only: %i[new create verify_form verify]

    def new
    end

    def create
      phone = params[:phone].to_s
      result = PhoneOtp.send_code!(phone: phone)
      unless result.ok?
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
        return
      end

      session[:phone_login_phone] = result.phone
      notice = 'We sent a code to that number.'
      notice = "#{notice} (dev code: #{result.debug_code})" if result.debug_code.present?
      redirect_to verify_auth_phone_login_path, notice: notice
    end

    def verify_form
      @phone = session[:phone_login_phone]
      return if @phone.present?

      redirect_to new_auth_phone_login_path, alert: 'Enter your phone number first.'
    end

    def verify
      phone = session[:phone_login_phone].presence || params[:phone].to_s
      result = PhoneOtp.verify_code!(phone: phone, code: params[:code])
      unless result.ok?
        @phone = phone
        flash.now[:alert] = result.error
        render :verify_form, status: :unprocessable_entity
        return
      end

      person = Person.find_by_textable_phone(result.phone)
      if person
        person.mark_phone_verified!
        establish_person_session!(person)
        session.delete(:phone_login_phone)
        redirect_after_phone_login(person)
        return
      end

      session[:phone_login_phone] = result.phone
      session[:phone_login_verified] = true
      redirect_to new_auth_phone_registration_path,
                  notice: 'We don’t recognize that number yet. Tell us who you are to create an account.'
    end

    private

    def redirect_if_already_signed_in
      return unless current_person

      redirect_to(current_company_teammate ? root_path : me_path)
    end

    def redirect_after_phone_login(person)
      path = consume_return_to_path
      if path.present?
        redirect_to path
      elsif person.active_teammates.any?
        redirect_to root_path, notice: 'Signed in with phone.'
      else
        redirect_to me_path, notice: 'Signed in with phone.'
      end
    end
  end
end
