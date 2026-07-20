# frozen_string_literal: true

module Organizations
  class PossibleObservationConsultsController < OrganizationNamespaceBaseController
    before_action :authenticate_person!
    before_action :set_consult, only: %i[
      show update confirm_teammates extract re_extract re_extract_with_stronger_model
      extraction_status create_draft_observations
    ]
    after_action :verify_authorized

    def index
      authorize PossibleObservationConsult
      @consults = policy_scope(PossibleObservationConsult).recent_first.limit(50)
    end

    def new
      authorize PossibleObservationConsult
      @consult = PossibleObservationConsult.new(
        organization: organization,
        creator_company_teammate: current_company_teammate,
        display_name: "OG Consult #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      )
    end

    def create
      authorize PossibleObservationConsult
      @consult = PossibleObservationConsult.new(consult_params.merge(
                                                  organization: organization,
                                                  creator_company_teammate: current_company_teammate,
                                                  people_status: "suggested",
                                                  extraction_status: "ready"
                                                ))
      attach_source!(@consult)

      if @consult.save
        after_source_saved!(@consult)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def import_google_meet
      authorize PossibleObservationConsult, :import_google_meet?
      redirect_to new_organization_possible_observation_consult_path(organization),
                  alert: "Google Meet import is coming soon. Upload or paste a Meet transcript instead."
    end

    def import_zoom
      authorize PossibleObservationConsult, :import_zoom?
      redirect_to new_organization_possible_observation_consult_path(organization),
                  alert: "Zoom import is coming soon. Upload or paste a Zoom transcript instead."
    end

    def show
      authorize @consult
      load_show_context
    end

    def confirm_teammates
      authorize @consult
      ids = Array(params[:confirmed_teammate_ids]).map(&:to_i).reject(&:zero?).uniq
      org_ids = organization.self_and_descendants.map(&:id)
      valid_ids = CompanyTeammate.where(id: ids, organization_id: org_ids).pluck(:id)

      if valid_ids.empty?
        redirect_to organization_possible_observation_consult_path(organization, @consult),
                    alert: "Select at least one teammate."
        return
      end

      @consult.update!(
        confirmed_teammate_ids: valid_ids,
        people_status: "confirmed",
        extraction_status: "pending",
        extraction_error: nil,
        extractions: {}
      )
      PossibleObservationConsultExtractionJob.perform_later(@consult.id)
      redirect_to organization_possible_observation_consult_path(organization, @consult),
                  notice: "OG Consult started — finding potential OGOs for the confirmed teammates."
    end

    def extract
      authorize @consult
      @consult.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
      PossibleObservationConsultExtractionJob.perform_later(@consult.id)
      redirect_to organization_possible_observation_consult_path(organization, @consult),
                  notice: "OG Consult started again."
    end

    def re_extract
      extract
    end

    def re_extract_with_stronger_model
      authorize @consult, :re_extract_with_stronger_model?
      @consult.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
      PossibleObservationConsultExtractionJob.perform_later(
        @consult.id,
        model_id: Llm::MultiTeammateMomentsExtractor.stronger_model_id
      )
      redirect_to organization_possible_observation_consult_path(organization, @consult),
                  notice: "OG Consult started with a stronger model — finding potential OGOs."
    end

    def update
      authorize @consult
      items = normalize_items_param(params[:items])
      if items.empty?
        redirect_to organization_possible_observation_consult_path(organization, @consult),
                    alert: "No candidate rows to save."
        return
      end

      if create_drafts_commit?
        authorize @consult, :create_draft_observations?
        promote_drafts!(items)
        return
      end

      @consult.replace_extraction_items!(items)
      redirect_to organization_possible_observation_consult_path(organization, @consult),
                  notice: "Candidates saved."
    end

    def create_draft_observations
      authorize @consult
      items = normalize_items_param(params[:items])
      promote_drafts!(items)
    end

    def extraction_status
      authorize @consult
      consultation = OgConsultation.latest_for(
        subject: @consult,
        kind: OgConsultation::KIND_OGO_SEARCH_CONSULT
      )
      progress_extras = {
        search_error: @consult.extraction_error,
        processed_teammates_count: @consult.processed_teammate_ids.size,
        confirmed_teammates_count: Array(@consult.confirmed_teammate_ids).size,
        items_count: @consult.extraction_items.size
      }
      payload =
        if consultation
          OgConsultations::StatusPayload.for_consultation(
            consultation,
            status: @consult.extraction_status,
            **progress_extras
          )
        else
          OgConsultations::StatusPayload.for_heartbeat(
            record: @consult,
            status: @consult.extraction_status,
            **progress_extras
          )
        end
      render json: payload
    end

    private

    def set_consult
      @consult = policy_scope(PossibleObservationConsult).find(params[:id])
    end

    def consult_params
      params.require(:possible_observation_consult).permit(:display_name, :source_text, :source_file)
    end

    def attach_source!(consult)
      file = params.dig(:possible_observation_consult, :source_file)
      consult.source_file.attach(file) if file.present?
    end

    def after_source_saved!(consult, notice: "Content saved. Confirm which teammates to include, then run OG Consult.")
      suggested = PossibleObservationConsults::SuggestTeammatesFromText.call(
        organization: organization,
        plaintext: consult.plaintext
      )
      consult.update!(suggested_teammate_ids: suggested.map(&:id))
      redirect_to organization_possible_observation_consult_path(organization, consult), notice: notice
    end

    def create_drafts_commit?
      params[:commit].to_s.include?("Create draft OGOs")
    end

    def promote_drafts!(items)
      if items.empty?
        redirect_to organization_possible_observation_consult_path(organization, @consult),
                    alert: "No candidate rows to promote."
        return
      end

      @consult.replace_extraction_items!(items)
      result = PossibleObservationConsults::BatchCreateDraftObservationsService.call(
        consult: @consult.reload,
        creator: current_company_teammate
      )
      if result.ok?
        payload = result.value
        notice_parts = []
        notice_parts << "Created #{payload[:created]} draft OGO#{"s" if payload[:created] != 1}." if payload[:created].positive?
        notice_parts << "#{payload[:skipped_already]} already had drafts." if payload[:skipped_already].positive?
        if payload[:errors].any?
          redirect_to organization_possible_observation_consult_path(organization, @consult),
                      alert: [notice_parts.presence&.join(" "), payload[:errors].join(" ")].compact.join(" ")
        elsif notice_parts.empty?
          redirect_to organization_possible_observation_consult_path(organization, @consult),
                      alert: "No included candidates were ready."
        else
          redirect_to organization_possible_observation_consult_path(organization, @consult),
                      notice: notice_parts.join(" ")
        end
      else
        redirect_to organization_possible_observation_consult_path(organization, @consult),
                    alert: Array(result.error).join(", ")
      end
    end

    def load_show_context
      @suggested_teammates = @consult.suggested_teammates.includes(:person)
      @confirmed_teammates = @consult.confirmed_teammates.includes(:person)
      @selectable_teammates = CompanyTeammate
                             .where(organization_id: organization.self_and_descendants.map(&:id))
                             .includes(:person)
                             .sort_by { |tm| tm.person.casual_name.to_s.downcase }
      @observation_type_options = [["Kudos", "kudos"], ["Feedback", "feedback"]]
      @teammates_grouped_for_select = [
        [
          organization.name,
          @selectable_teammates.map { |tm| [tm.person.display_name, tm.id] }
        ]
      ]
      @latest_consultation = OgConsultation.latest_for(
        subject: @consult,
        kind: OgConsultation::KIND_OGO_SEARCH_CONSULT
      )
    end

    def normalize_items_param(raw)
      return [] if raw.blank?

      list =
        case raw
        when ActionController::Parameters
          raw.to_unsafe_h.sort_by { |k, _| k.to_s.to_i }.map(&:last)
        when Hash
          raw.sort_by { |k, _| k.to_s.to_i }.map(&:last)
        else
          []
        end

      list.map do |h|
        h = if h.respond_to?(:permit)
          h.permit(
            :id, :include, :quote, :summary, :short_quote, :full_quote, :kind,
            :speaker_label, :recipient_label,
            :responder_company_teammate_id, :subject_company_teammate_id,
            :observer_unknown, :observee_unknown,
            :suggested_rateable_type, :suggested_rateable_id, :suggested_rating, :suggested_goal_id,
            :suggested_rateable_name, :association_reason, :rating_reason,
            :confidence, :observation_id
          ).to_h
        else
          h.stringify_keys
        end
        out = h.stringify_keys
        out["include"] = (out["include"].to_s == "1")
        out
      end
    end
  end
end
