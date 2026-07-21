# frozen_string_literal: true

module Organizations
  class PossibleObservationConsultsController < OrganizationNamespaceBaseController
    before_action :authenticate_person!
    before_action :set_consult, only: %i[
      show update confirm_teammates extract re_extract
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
      if stronger_model_requested?
        PossibleObservationConsultExtractionJob.perform_later(
          @consult.id,
          model_id: Llm::MultiTeammateMomentsExtractor.stronger_model_id
        )
        redirect_to consult_path,
                    notice: "OG Consult started with a slower, more powerful model — finding potential OGOs for the confirmed teammates."
      else
        PossibleObservationConsultExtractionJob.perform_later(@consult.id)
        redirect_to consult_path,
                    notice: "OG Consult started — finding potential OGOs for the confirmed teammates."
      end
    end

    def extract
      authorize @consult
      @consult.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
      if stronger_model_requested?
        PossibleObservationConsultExtractionJob.perform_later(
          @consult.id,
          model_id: Llm::MultiTeammateMomentsExtractor.stronger_model_id
        )
        redirect_to consult_path,
                    notice: "OG Consult started again with a slower, more powerful model."
      else
        PossibleObservationConsultExtractionJob.perform_later(@consult.id)
        redirect_to consult_path, notice: "OG Consult started again."
      end
    end

    def re_extract
      extract
    end

    # Save all: actualize every row's status — dismiss dismissed rows, promote included
    # rows to draft OGOs, and leave "reviewing" rows as unprocessed candidates. When
    # dismiss_item_id / promote_item_id is present, act on that single row instead.
    def update
      authorize @consult
      items = normalize_items_param(params[:items])
      if params[:dismiss_item_id].present?
        dismiss_single!(items, params[:dismiss_item_id].to_s)
      elsif params[:promote_item_id].present?
        promote_single!(items, params[:promote_item_id].to_s, publish: false)
      elsif params[:publish_item_id].present?
        promote_single!(items, params[:publish_item_id].to_s, publish: true)
      else
        save_all!(items)
      end
    end

    # Backward-compatible route; behaves like Save all.
    def create_draft_observations
      authorize @consult
      items = normalize_items_param(params[:items])
      save_all!(items)
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

    def consult_path
      organization_possible_observation_consult_path(organization, @consult)
    end

    def stronger_model_requested?
      params[:model].to_s == "stronger"
    end

    def included_item?(item)
      ActiveModel::Type::Boolean.new.cast(item["include"])
    end

    # One-at-a-time promote (Create draft OGO now / Create published OGO now). Saves the
    # current on-screen state, promotes just the targeted row to a draft OGO, then (when
    # publishing) publishes it only if the viewer is the resolved observer.
    def promote_single!(items, target_id, publish:)
      target = items.find { |item| item["id"].to_s == target_id }
      if target.nil?
        redirect_to consult_path, alert: "Candidate not found."
        return
      end
      if target["observation_id"].present?
        redirect_to consult_path, notice: "This candidate already has an OGO."
        return
      end
      if target["responder_company_teammate_id"].blank? || target["subject_company_teammate_id"].blank?
        redirect_to consult_path, alert: "Choose both observer and subject before creating an OGO."
        return
      end

      items = items.map do |item|
        next item unless item["id"].to_s == target_id

        item = item.dup
        item["include"] = true
        item["dismissed_at"] = nil
        item["dismissed_by_company_teammate_id"] = nil
        item
      end
      @consult.replace_extraction_items!(items)

      authorize @consult, :create_draft_observations?
      result = PossibleObservationConsults::BatchCreateDraftObservationsService.call(
        consult: @consult.reload,
        creator: current_company_teammate,
        extraction_ids: [target_id]
      )

      unless result.ok?
        redirect_to consult_path, alert: Array(result.error).join(", ")
        return
      end

      payload = result.value
      if payload[:errors].any?
        redirect_to consult_path, alert: payload[:errors].join(" ")
        return
      end
      if payload[:created].to_i.zero?
        redirect_to consult_path, alert: "Could not create an OGO from this candidate."
        return
      end

      observation = created_observation_for(target_id)

      unless publish
        redirect_to consult_path, notice: "Draft OGO created."
        return
      end

      if observation.nil?
        redirect_to consult_path, notice: "Draft OGO created."
      elsif observation.observer_id == current_company_teammate&.person_id
        observation.publish!
        redirect_to consult_path, notice: "Published OGO created (stakeholder-only; no notifications sent)."
      else
        redirect_to consult_path, alert: "OGO created, but you can only publish OGOs where you are the observer."
      end
    end

    def created_observation_for(target_id)
      item = @consult.reload.extraction_items.find { |i| i[:id].to_s == target_id }
      observation_id = item&.dig(:observation_id)
      observation_id.present? ? Observation.find_by(id: observation_id) : nil
    end

    # One-at-a-time quick dismiss (Dismiss now). Saves the current on-screen state of
    # every row (no promotion) and force-dismisses the targeted row.
    def dismiss_single!(items, target_id)
      matched = false
      items = items.map do |item|
        next item unless item["id"].to_s == target_id

        matched = true
        item["include"] = false
        item["dismissed_at"] = item["dismissed_at"].presence || Time.current.iso8601
        item["dismissed_by_company_teammate_id"] =
          item["dismissed_by_company_teammate_id"].presence || current_company_teammate&.id
        item
      end
      @consult.replace_extraction_items!(items) if items.any?
      redirect_to consult_path, notice: matched ? "Candidate dismissed." : "Candidates saved."
    end

    def save_all!(items)
      if items.empty?
        redirect_to consult_path, alert: "No candidate rows to save."
        return
      end

      invalid_rows = items.select do |item|
        included_item?(item) && item["observation_id"].blank? &&
          (item["responder_company_teammate_id"].blank? || item["subject_company_teammate_id"].blank?)
      end
      if invalid_rows.any?
        redirect_to consult_path, alert: "Rows set to Include must have both observer and subject selected."
        return
      end

      @consult.replace_extraction_items!(items)
      dismissed_count = items.count { |item| item["dismissed_at"].present? }

      promotable = items.any? { |item| included_item?(item) && item["observation_id"].blank? }
      unless promotable
        redirect_to consult_path, notice: saved_notice(dismissed_count)
        return
      end

      authorize @consult, :create_draft_observations?
      result = PossibleObservationConsults::BatchCreateDraftObservationsService.call(
        consult: @consult.reload,
        creator: current_company_teammate
      )

      if result.ok?
        payload = result.value
        notice_parts = []
        notice_parts << "Created #{payload[:created]} draft OGO#{"s" if payload[:created] != 1}." if payload[:created].positive?
        notice_parts << "#{payload[:skipped_already]} already had drafts." if payload[:skipped_already].positive?
        notice_parts << dismissed_summary(dismissed_count) if dismissed_count.positive?
        if payload[:errors].any?
          redirect_to consult_path,
                      alert: [notice_parts.presence&.join(" "), payload[:errors].join(" ")].compact.join(" ")
        elsif notice_parts.empty?
          redirect_to consult_path, notice: "Candidates saved."
        else
          redirect_to consult_path, notice: notice_parts.join(" ")
        end
      else
        redirect_to consult_path, alert: Array(result.error).join(", ")
      end
    end

    def saved_notice(dismissed_count)
      return "Candidates saved." unless dismissed_count.positive?

      "Candidates saved. #{dismissed_summary(dismissed_count)}"
    end

    def dismissed_summary(count)
      "#{count} candidate#{"s" unless count == 1} currently dismissed."
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

      stored_by_id = @consult.extraction_items.index_by { |item| item[:id].to_s }

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
        submitted = if h.respond_to?(:permit)
          h.permit(
            :id, :state, :quote, :summary, :short_quote, :full_quote, :kind,
            :speaker_label, :recipient_label,
            :responder_company_teammate_id, :subject_company_teammate_id,
            :observer_unknown, :observee_unknown,
            :suggested_rateable_type, :suggested_rateable_id, :suggested_rating, :suggested_goal_id,
            :suggested_rateable_name, :association_reason, :rating_reason,
            :confidence, :observation_id,
            :dismissed_at, :dismissed_by_company_teammate_id
          ).to_h.stringify_keys
        else
          h.stringify_keys
        end

        # Merge submitted values onto the stored item so fields that are hidden or disabled
        # in the form (e.g. observer/subject on non-included rows, or any field on a locked
        # row) are preserved instead of being wiped out on save. Otherwise the item loses
        # its subject and drops out of the per-teammate grouping (appears to vanish).
        stored = stored_by_id[submitted["id"].to_s]
        out = stored ? stored.to_h.stringify_keys.merge(submitted) : submitted

        out["observer_unknown"] = out["responder_company_teammate_id"].blank?
        out["observee_unknown"] = out["subject_company_teammate_id"].blank?
        apply_state!(out)
        out
      end
    end

    STATES = %w[needs_processed included dismissed].freeze

    # Reconcile the row's single tri-state (needs_processed | included | dismissed) into
    # the stored flags. Preserves the original dismissal timestamp/actor on re-save.
    def apply_state!(out)
      state = out.delete("state").to_s
      state = "needs_processed" unless STATES.include?(state)

      out["include"] = (state == "included")

      if state == "dismissed"
        out["dismissed_at"] = out["dismissed_at"].presence || Time.current.iso8601
        out["dismissed_by_company_teammate_id"] =
          out["dismissed_by_company_teammate_id"].presence || current_company_teammate&.id
      else
        out["dismissed_at"] = nil
        out["dismissed_by_company_teammate_id"] = nil
      end
      out
    end
  end
end
