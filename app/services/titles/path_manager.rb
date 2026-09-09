# frozen_string_literal: true

module Titles
  # Syncs end_cap + TitlePath edges from manage-paths association params
  # (direction: inbound|outbound|none + path_type per other title).
  class PathManager
    Result = Struct.new(:ok?, :error, keyword_init: true)
    DEFAULT_PATH_TYPE = "natural_progression"

    def self.call(title:, end_cap:, associations:)
      new(title: title, end_cap: end_cap, associations: associations).call
    end

    def initialize(title:, end_cap:, associations:)
      @title = title
      @end_cap = ActiveModel::Type::Boolean.new.cast(end_cap)
      @associations = associations || {}
    end

    def call
      Title.transaction do
        if end_cap
          title.outbound_title_paths.destroy_all
          title.update!(end_cap: true)
        else
          title.update!(end_cap: false)
        end

        keep_path_ids = []

        associations.each do |other_title_id, attrs|
          attrs = attrs.to_h.with_indifferent_access
          direction = attrs[:direction].to_s
          next if direction.blank? || direction == "none"
          next if end_cap && direction == "outbound"

          other = Title.unarchived.find_by(id: other_title_id, company_id: title.company_id)
          next unless other

          path_type = attrs[:path_type].presence || DEFAULT_PATH_TYPE
          path_type = DEFAULT_PATH_TYPE unless TitlePath::PATH_TYPES.key?(path_type)

          path = upsert_path!(other: other, direction: direction, path_type: path_type)
          keep_path_ids << path.id
        end

        involving_paths.where.not(id: keep_path_ids).find_each(&:destroy!)
      end

      Result.new(ok?: true)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.record.errors.full_messages.to_sentence.presence || e.message)
    rescue StandardError => e
      Result.new(ok?: false, error: e.message)
    end

    private

    attr_reader :title, :end_cap, :associations

    def involving_paths
      TitlePath.where(from_title_id: title.id).or(TitlePath.where(to_title_id: title.id))
    end

    def upsert_path!(other:, direction:, path_type:)
      if direction == "outbound"
        title.inbound_title_paths.where(from_title_id: other.id).destroy_all
        path = TitlePath.find_or_initialize_by(from_title: title, to_title: other)
      else
        title.outbound_title_paths.where(to_title_id: other.id).destroy_all
        path = TitlePath.find_or_initialize_by(from_title: other, to_title: title)
      end

      path.path_type = path_type
      path.save!
      path
    end
  end
end
