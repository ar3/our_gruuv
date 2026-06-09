# frozen_string_literal: true

require 'csv'

module Insights
  class ObservationsValuesCountsCsvBuilder
    RATING_LABELS = {
      'strongly_agree' => 'Exceptional',
      'agree' => 'Solid',
      'disagree' => 'Misaligned',
      'strongly_disagree' => 'Concerning'
    }.freeze

    PRIVATE_RATING_KEYS = %w[strongly_agree agree disagree strongly_disagree].freeze
    PUBLIC_RATING_KEYS = %w[strongly_agree agree].freeze
    PRIVACY_BUCKETS = %w[Private Public].freeze
    PRIVATE_LEVELS = %w[observed_only managers_only observed_and_managers].freeze
    PUBLIC_LEVELS = %w[public_to_company public_to_world].freeze

    IDENTIFIER_HEADERS = %w[all_names_display_name email department].freeze

    def initialize(company, published_at_range: nil, show_private_counts: true)
      @company = company
      @published_at_range = published_at_range
      @show_private_counts = show_private_counts
    end

    def call
      aspirations = Aspiration.for_company(company).ordered.to_a
      counts = aggregate_counts
      teammate_ids = counts.keys.map(&:first).uniq
      teammates_by_id = load_teammates(teammate_ids)

      sorted_teammate_ids = teammate_ids.sort_by do |id|
        teammate = teammates_by_id[id]
        teammate&.person&.all_names_display_name.to_s.downcase
      end

      CSV.generate(headers: true) do |csv|
        csv << header_row(aspirations)
        sorted_teammate_ids.each do |teammate_id|
          teammate = teammates_by_id[teammate_id]
          next unless teammate

          csv << data_row(teammate, aspirations, counts, teammate_id)
        end
      end
    end

    private

    attr_reader :company, :published_at_range, :show_private_counts

    def header_row(aspirations)
      IDENTIFIER_HEADERS + value_count_headers(aspirations)
    end

    def value_count_headers(aspirations)
      aspirations.flat_map do |aspiration|
        PRIVACY_BUCKETS.flat_map do |privacy_bucket|
          rating_keys_for(privacy_bucket).map do |rating_key|
            "#{aspiration.name} : #{privacy_bucket} : #{RATING_LABELS[rating_key]}"
          end
        end
      end
    end

    def data_row(teammate, aspirations, counts, teammate_id)
      person = teammate.person
      department_name = teammate.active_employment_tenure&.position&.title&.department&.name.to_s

      identifier_values = [
        person&.all_names_display_name.to_s,
        person&.email.to_s,
        department_name
      ]

      value_counts = aspirations.flat_map do |aspiration|
        PRIVACY_BUCKETS.flat_map do |privacy_bucket|
          rating_keys_for(privacy_bucket).map do |rating_key|
            cell_value(teammate_id, aspiration.id, privacy_bucket, rating_key, counts)
          end
        end
      end

      identifier_values + value_counts
    end

    def rating_keys_for(privacy_bucket)
      privacy_bucket == 'Public' ? PUBLIC_RATING_KEYS : PRIVATE_RATING_KEYS
    end

    def cell_value(teammate_id, aspiration_id, privacy_bucket, rating_key, counts)
      return 'X' if privacy_bucket == 'Private' && !show_private_counts

      label = RATING_LABELS[rating_key]
      counts[[teammate_id, aspiration_id, privacy_bucket, label]] || 0
    end

    def aggregate_counts
      privacy_bucket_sql = <<~SQL.squish
        CASE
          WHEN observations.privacy_level IN ('public_to_company', 'public_to_world') THEN 'Public'
          ELSE 'Private'
        END
      SQL

      scope = ObservationRating
        .joins(observation: :observees)
        .joins('INNER JOIN teammates ON teammates.id = observees.teammate_id')
        .where(rateable_type: 'Aspiration')
        .where.not(rating: 'na')
        .merge(
          Observation
            .for_company(company)
            .not_soft_deleted
            .published
            .not_journal
            .where(privacy_level: PRIVATE_LEVELS + PUBLIC_LEVELS)
        )
        .where('observations.observer_id != teammates.person_id')

      scope = scope.where(observations: { published_at: published_at_range }) if published_at_range

      scope
        .group(
          'observees.teammate_id',
          'observation_ratings.rateable_id',
          Arel.sql(privacy_bucket_sql),
          'observation_ratings.rating'
        )
        .count
        .each_with_object(Hash.new(0)) do |((teammate_id, aspiration_id, privacy_bucket, rating), count), totals|
          label = RATING_LABELS[rating.to_s]
          next unless label

          totals[[teammate_id, aspiration_id, privacy_bucket, label]] = count
        end
    end

    def load_teammates(teammate_ids)
      return {} if teammate_ids.empty?

      CompanyTeammate
        .where(id: teammate_ids)
        .includes(:person, employment_tenures: { position: { title: :department } })
        .index_by(&:id)
    end
  end
end
