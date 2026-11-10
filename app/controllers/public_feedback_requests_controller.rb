# frozen_string_literal: true

# Public Feedback Request answer surface — outside the org namespace so Person-only
# sessions stay isolated from teammate-required controllers.
class PublicFeedbackRequestsController < ApplicationController
  layout 'public_maap'

  before_action :set_feedback_request
  before_action :ensure_public_audience
  before_action :ensure_not_archived, only: %i[show submit start_verification verify]
  before_action :authenticate_person_only!, only: :submit

  def show
    clear_public_fr_verify_session! if params[:restart_verification].present?
    # So login-page / Google returns here after authenticate.
    session[:return_to] = public_feedback_request_path(@feedback_request.public_answer_token) unless current_person
    load_answer_assigns
  end

  def start_verification
    full_name = params[:full_name].to_s.strip
    full_name = 'Anonymous User' if full_name.blank?
    phone = params[:phone].to_s

    result = PhoneOtp.send_code!(phone: phone)
    unless result.ok?
      load_answer_assigns
      @verify_full_name = full_name
      @verify_phone = phone
      flash.now[:alert] = result.error
      render :show, status: :unprocessable_entity
      return
    end

    session[:public_fr_verify_phone] = result.phone
    session[:public_fr_verify_full_name] = full_name
    session[:public_fr_verify_token] = @feedback_request.public_answer_token
    session[:return_to] = public_feedback_request_path(@feedback_request.public_answer_token)

    notice = 'We texted you a code.'
    notice = "#{notice} (dev code: #{result.debug_code})" if result.debug_code.present?
    redirect_to public_feedback_request_path(@feedback_request.public_answer_token), notice: notice
  end

  def verify
    phone = session[:public_fr_verify_phone].presence || params[:phone].to_s
    full_name = session[:public_fr_verify_full_name].to_s.strip
    result = PhoneOtp.verify_code!(phone: phone, code: params[:code])
    unless result.ok?
      load_answer_assigns
      flash.now[:alert] = result.error
      render :show, status: :unprocessable_entity
      return
    end

    person = Person.find_by_textable_phone(result.phone)
    if person
      person.mark_phone_verified!
    else
      person = create_person_from_public_verify!(phone: result.phone, full_name: full_name)
      unless person
        load_answer_assigns
        flash.now[:alert] = 'We could not create your account. Check your name and try again.'
        render :show, status: :unprocessable_entity
        return
      end
    end

    clear_public_fr_verify_session!
    establish_person_session!(person)
    redirect_to public_feedback_request_path(@feedback_request.public_answer_token),
                notice: 'You’re verified — you can submit feedback below.'
  end

  def submit
    answers = params[:answers] || {}
    privacy_level = params[:privacy_level] || 'observed_and_managers'
    complete = params[:save_and_complete].present?

    result = FeedbackRequests::AnswerService.call(
      feedback_request: @feedback_request,
      answers: answers,
      responder_person: current_person,
      privacy_level: privacy_level,
      complete: complete
    )

    if result.ok?
      maybe_track_org_responder_completion!(complete)

      notice = if complete
        "Your feedback has been saved — you're done with this request."
      else
        'Your feedback has been saved and kept incomplete.'
      end
      if @feedback_request.answerable?
        flash[:continue_public_feedback_token] = @feedback_request.public_answer_token
      end
      redirect_to me_path, notice: notice
    else
      load_answer_assigns
      flash.now[:alert] = Array(result.error).to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_feedback_request
    @feedback_request = FeedbackRequest.find_by_public_answer_token!(params[:token])
    @organization = @feedback_request.company
  end

  def ensure_public_audience
    return if @feedback_request.open_to_public?

    raise ActiveRecord::RecordNotFound
  end

  def ensure_not_archived
    return unless @feedback_request.archived?

    redirect_to root_path, alert: 'This feedback request has been archived and is no longer accepting responses.'
  end

  def load_answer_assigns
    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    @person_signed_in = current_person.present?
    @form_enabled = @person_signed_in && @feedback_request.answerable?
    @awaiting_code = !@person_signed_in &&
                     session[:public_fr_verify_phone].present? &&
                     session[:public_fr_verify_token] == @feedback_request.public_answer_token
    @verify_phone = session[:public_fr_verify_phone]
    @verify_full_name = session[:public_fr_verify_full_name].presence || @verify_full_name

    if current_person
      draft_observations = @feedback_request.observations
        .drafts
        .where(observer: current_person)
        .includes(:observation_ratings)
      @draft_ogo_count = draft_observations.size
      @observation_by_question_id = draft_observations.index_by(&:feedback_request_question_id)
      @prior_published_observations = @feedback_request.observations
        .published
        .where(observer: current_person)
        .includes(:feedback_request_question)
        .order(published_at: :desc)
    else
      @draft_ogo_count = 0
      @observation_by_question_id = {}
      @prior_published_observations = []
    end

    @org_teammate_answer_path = org_teammate_answer_path_for_current_person
    @subject_casual_name = @feedback_request.subject_of_feedback_teammate.person.casual_name.presence ||
                           @feedback_request.subject_of_feedback_teammate.person.display_name
  end

  # Only when this browser session is actually that org's teammate — not merely
  # because a CompanyTeammate row exists, and not for person-only / other-org sessions.
  def org_teammate_answer_path_for_current_person
    teammate = current_company_teammate
    return if teammate.blank?
    return if teammate.last_terminated_at.present?
    return unless teammate.organization_id == @organization.id

    answer_organization_feedback_request_path(@organization, @feedback_request)
  end

  # When the Person is also an org teammate, keep inbox completion in sync.
  def maybe_track_org_responder_completion!(complete)
    teammate = current_person.company_teammates.find_by(organization_id: @organization.id)
    return if teammate.blank? || teammate.last_terminated_at.present?

    responder_record = @feedback_request.feedback_request_responders
      .find_or_create_by!(teammate_id: teammate.id)
    responder_record.update!(completed_at: complete ? Time.current : nil)
  end

  def clear_public_fr_verify_session!
    session.delete(:public_fr_verify_phone)
    session.delete(:public_fr_verify_full_name)
    session.delete(:public_fr_verify_token)
  end

  def create_person_from_public_verify!(phone:, full_name:)
    return nil if full_name.blank?

    person = Person.new(
      email: Person.phone_placeholder_email_for(phone),
      unique_textable_phone_number: phone,
      phone_verified_at: Time.current
    )
    person.full_name = full_name
    return person if person.first_name.present? && person.save

    nil
  end
end
