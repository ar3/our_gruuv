# frozen_string_literal: true

module Organizations
  class AskOgController < Organizations::OrganizationNamespaceBaseController
    before_action :authenticate_person!
    before_action :set_consultation, only: %i[status confirm reply show]
    after_action :verify_authorized

    # HTML fragment for search Ask OG panel (AJAX).
    def panel
      authorize company, :view_search?
      @query = params[:q].to_s.strip
      @consultation = nil
      if params[:id].present?
        @consultation = OgConsultation.find_by(
          id: params[:id],
          organization_id: @organization.id,
          kind: OgConsultation::KIND_ASK_OG,
          triggered_by_teammate_id: current_company_teammate.id
        )
        @query = @consultation.result.query if @consultation&.result.is_a?(AskOgResult)
      end
      @auto_start = @consultation.nil? && @query.present?
      render layout: false
    end

    def show
      authorize company, :view_search?
      redirect_to organization_search_path(@organization, ask_og_id: @consultation.id)
    end

    def create
      authorize company, :view_search?
      started = Assistant::StartAskOg.call(
        organization: @organization,
        company_teammate: current_company_teammate,
        query: params[:q]
      )

      unless started.ok?
        return render json: { ok: false, error: Array(started.error).join(", ") }, status: :unprocessable_entity
      end

      consultation = started.value[:consultation]
      render json: status_json(consultation).merge(
        ok: true,
        consultation_id: consultation.id,
        status_url: status_organization_ask_og_path(@organization, consultation),
        reply_url: reply_organization_ask_og_path(@organization, consultation)
      )
    end

    def reply
      authorize company, :view_search?
      replied = Assistant::ReplyAskOg.call(
        og_consultation: @consultation,
        message: params[:message]
      )

      unless replied.ok?
        return render json: { ok: false, error: Array(replied.error).join(", ") }, status: :unprocessable_entity
      end

      render json: {
        ok: true,
        consultation_id: @consultation.id,
        status_url: status_organization_ask_og_path(@organization, @consultation),
        reply_url: reply_organization_ask_og_path(@organization, @consultation)
      }
    end

    def status
      authorize company, :view_search?
      render json: status_json(@consultation)
    end

    def confirm
      authorize company, :view_search?
      context = Assistant::ContextBuilder.call(
        organization: @organization,
        company_teammate: current_company_teammate,
        impersonating_teammate: impersonating_teammate
      )
      confirmed = Assistant::ConfirmProposedAction.call(
        og_consultation: @consultation,
        action_index: params[:action_index],
        context: context
      )

      unless confirmed.ok?
        return render json: { ok: false, error: Array(confirmed.error).join(", ") }, status: :unprocessable_entity
      end

      redirect_path = confirmed.value[:redirect_path]
      render json: { ok: true, redirect_path: redirect_path }
    end

    private

    def set_consultation
      @consultation = OgConsultation.find_by!(
        id: params[:id],
        organization_id: @organization.id,
        kind: OgConsultation::KIND_ASK_OG,
        triggered_by_teammate_id: current_company_teammate.id
      )
    end

    def status_json(consultation)
      result = consultation.result
      messages = []
      if result.is_a?(AskOgResult)
        messages = result.ask_og_messages.ordered.map do |message|
          {
            id: message.id,
            role: message.role,
            body: message.body,
            body_html: message.assistant? ? helpers.render_markdown(message.body) : nil,
            proposed_actions: message.assistant? ? (message.proposed_actions || []) : []
          }
        end
      end

      latest_actions = result.try(:proposed_actions) || []
      OgConsultations::StatusPayload.for_consultation(consultation).merge(
        answer_text: result.try(:answer_text),
        answer_html: helpers.render_markdown(result.try(:answer_text)),
        proposed_actions: latest_actions,
        query: result.try(:query),
        error_message: consultation.error_message,
        messages: messages,
        confirms_count: result.try(:confirms_count).to_i,
        user_message_count: result.is_a?(AskOgResult) ? result.user_message_count : 0,
        reply_url: reply_organization_ask_og_path(@organization, consultation),
        status_url: status_organization_ask_og_path(@organization, consultation)
      )
    end
  end
end
