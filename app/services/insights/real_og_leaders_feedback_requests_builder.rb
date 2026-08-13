# frozen_string_literal: true

module Insights
  # Insights: Real OG Leaders — Feedback requests board.
  # Four signals per person in a timeframe (non-deleted requests only):
  # requested about (subject), sent (requestor), received (respondent),
  # completed (respondent with completed_at). Star when all four are present.
  class RealOgLeadersFeedbackRequestsBuilder
    Entry = Struct.new(
      :person,
      :company_teammate,
      :requested_about_count,
      :sent_count,
      :received_count,
      :completed_count,
      :has_requested_about,
      :has_sent,
      :has_received,
      :has_completed,
      :has_all_four,
      :most_recent_at,
      :display_name,
      keyword_init: true
    )

    def initialize(company:, range: nil)
      @company = company
      @range = range
    end

    def call
      stats_by_person_id = {}

      add_subjects_and_requestors(stats_by_person_id)
      add_respondents(stats_by_person_id)

      return [] if stats_by_person_id.empty?

      persons_by_id = Person.where(id: stats_by_person_id.keys).index_by(&:id)
      teammates_by_person_id = CompanyTeammate
        .where(organization: @company, person_id: stats_by_person_id.keys)
        .index_by(&:person_id)

      stats_by_person_id.filter_map do |person_id, stats|
        person = persons_by_id[person_id]
        next unless person

        about = stats[:requested_about_count]
        sent = stats[:sent_count]
        received = stats[:received_count]
        completed = stats[:completed_count]
        next if about.zero? && sent.zero? && received.zero? && completed.zero?

        has_about = about.positive?
        has_sent = sent.positive?
        has_received = received.positive?
        has_completed = completed.positive?

        Entry.new(
          person: person,
          company_teammate: teammates_by_person_id[person_id],
          requested_about_count: about,
          sent_count: sent,
          received_count: received,
          completed_count: completed,
          has_requested_about: has_about,
          has_sent: has_sent,
          has_received: has_received,
          has_completed: has_completed,
          has_all_four: has_about && has_sent && has_received && has_completed,
          most_recent_at: stats[:most_recent_at],
          display_name: person.display_name
        )
      end.sort_by { |entry| Insights::RealOgLeadersFeedbackRequestsSort.sort_key(entry) }
    end

    private

    def open_requests
      FeedbackRequest.not_deleted.where(company: @company)
    end

    def add_subjects_and_requestors(stats_by_person_id)
      scope = open_requests
      scope = scope.where(created_at: @range) if @range

      teammate_ids = scope.pluck(:requestor_teammate_id, :subject_of_feedback_teammate_id).flatten.uniq
      person_by_teammate = person_id_by_teammate_id(teammate_ids)

      scope.pluck(
        :requestor_teammate_id,
        :subject_of_feedback_teammate_id,
        :created_at
      ).each do |requestor_id, subject_id, created_at|
        if (person_id = person_by_teammate[requestor_id])
          bucket = stats_for(stats_by_person_id, person_id)
          bucket[:sent_count] += 1
          touch_recent(bucket, created_at)
        end

        if (person_id = person_by_teammate[subject_id])
          bucket = stats_for(stats_by_person_id, person_id)
          bucket[:requested_about_count] += 1
          touch_recent(bucket, created_at)
        end
      end
    end

    def add_respondents(stats_by_person_id)
      base = FeedbackRequestResponder
        .joins(:feedback_request)
        .merge(FeedbackRequest.not_deleted.where(company: @company))

      add_received(stats_by_person_id, base)
      add_completed(stats_by_person_id, base)
    end

    def add_received(stats_by_person_id, base)
      scope = base
      scope = scope.where(feedback_request_responders: { created_at: @range }) if @range

      teammate_ids = scope.distinct.pluck(:teammate_id)
      person_by_teammate = person_id_by_teammate_id(teammate_ids)

      scope.pluck(:teammate_id, "feedback_request_responders.created_at").each do |teammate_id, created_at|
        person_id = person_by_teammate[teammate_id]
        next unless person_id

        bucket = stats_for(stats_by_person_id, person_id)
        bucket[:received_count] += 1
        touch_recent(bucket, created_at)
      end
    end

    def add_completed(stats_by_person_id, base)
      scope = base.where.not(feedback_request_responders: { completed_at: nil })
      scope = scope.where(feedback_request_responders: { completed_at: @range }) if @range

      teammate_ids = scope.distinct.pluck(:teammate_id)
      person_by_teammate = person_id_by_teammate_id(teammate_ids)

      scope.pluck(:teammate_id, :completed_at).each do |teammate_id, completed_at|
        person_id = person_by_teammate[teammate_id]
        next unless person_id

        bucket = stats_for(stats_by_person_id, person_id)
        bucket[:completed_count] += 1
        touch_recent(bucket, completed_at)
      end
    end

    def person_id_by_teammate_id(teammate_ids)
      return {} if teammate_ids.blank?

      CompanyTeammate
        .where(id: teammate_ids, organization: @company)
        .pluck(:id, :person_id)
        .to_h
    end

    def stats_for(hash, person_id)
      hash[person_id] ||= {
        requested_about_count: 0,
        sent_count: 0,
        received_count: 0,
        completed_count: 0,
        most_recent_at: nil
      }
    end

    def touch_recent(bucket, at)
      return if at.nil?
      return if bucket[:most_recent_at].present? && at <= bucket[:most_recent_at]

      bucket[:most_recent_at] = at
    end
  end
end
