# frozen_string_literal: true

module PossibleObservationConsults
  # Step 2/3 keep a single observee <select>. "multi" means keep the named set;
  # blank means intentional team / no named people.
  module ObserveeSelection
    MULTI = "multi"

    module_function

    def normalize_ids(raw)
      Array(raw).filter_map { |value|
        id = value.to_i
        id if id.positive?
      }.uniq
    end

    # Returns { primary:, ids: } from a select value + optional multi ids.
    def resolve(select_value:, multi_ids: [])
      value = select_value.to_s
      multi = normalize_ids(multi_ids)

      case value
      when ""
        { primary: nil, ids: [] }
      when MULTI
        { primary: multi.first, ids: multi }
      else
        id = value.to_i
        id = nil unless id.positive?
        { primary: id, ids: id ? [id] : [] }
      end
    end

    def select_value(ids)
      list = normalize_ids(ids)
      return MULTI if list.size > 1
      return list.first.to_s if list.one?

      ""
    end

    def multi_option_label(ids, teammates_by_id)
      names = normalize_ids(ids).filter_map { |id|
        tm = teammates_by_id[id]
        tm&.person&.casual_name.presence || tm&.person&.display_name
      }
      return "More than one person" if names.empty?

      names.to_sentence(two_words_connector: " + ", last_word_connector: " + ")
    end

    def ready_for_promote?(observer_id:)
      observer_id.present?
    end
  end
end
