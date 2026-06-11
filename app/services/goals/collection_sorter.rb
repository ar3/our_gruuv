module Goals
  # Sorts in-memory goal collections using the same rules as GoalsController#apply_sorting.
  class CollectionSorter
    def self.call(goals, sort: 'most_likely_target_date', direction: 'asc')
      new(goals, sort: sort, direction: direction).call
    end

    def initialize(goals, sort: 'most_likely_target_date', direction: 'asc')
      @goals = Array(goals).compact
      @sort = sort.presence || 'most_likely_target_date'
      @direction = direction.to_s == 'desc' ? :desc : :asc
    end

    def call
      case @sort
      when 'smart_sort'
        sort_smart
      when 'most_likely_target_date'
        sort_by_date_then_title(:most_likely_target_date)
      when 'earliest_target_date'
        sort_by_date(:earliest_target_date)
      when 'latest_target_date'
        sort_by_date(:latest_target_date)
      when 'created_at'
        sort_by_timestamp(:created_at)
      when 'title'
        sort_by_title
      else
        sort_by_date_then_title(:most_likely_target_date)
      end
    end

    private

    def sort_smart
      sorted = @goals.sort_by do |goal|
        [goal.most_likely_target_date&.day || 99, goal.title.to_s.downcase]
      end
      @direction == :desc ? sorted.reverse : sorted
    end

    def sort_by_date_then_title(date_attribute)
      @goals.sort do |left, right|
        comparison = compare_dates(left.public_send(date_attribute), right.public_send(date_attribute))
        next comparison unless comparison.zero?

        left.title.to_s.downcase <=> right.title.to_s.downcase
      end
    end

    def sort_by_date(date_attribute)
      @goals.sort do |left, right|
        compare_dates(left.public_send(date_attribute), right.public_send(date_attribute))
      end
    end

    def sort_by_timestamp(timestamp_attribute)
      @goals.sort do |left, right|
        compare_timestamps(left.public_send(timestamp_attribute), right.public_send(timestamp_attribute))
      end
    end

    def sort_by_title
      sorted = @goals.sort_by { |goal| goal.title.to_s.downcase }
      @direction == :desc ? sorted.reverse : sorted
    end

    def compare_dates(left_date, right_date)
      if left_date.nil? && right_date.nil?
        0
      elsif left_date.nil?
        @direction == :asc ? -1 : 1
      elsif right_date.nil?
        @direction == :asc ? 1 : -1
      elsif @direction == :asc
        left_date <=> right_date
      else
        right_date <=> left_date
      end
    end

    def compare_timestamps(left_time, right_time)
      if left_time.nil? && right_time.nil?
        0
      elsif left_time.nil?
        @direction == :asc ? -1 : 1
      elsif right_time.nil?
        @direction == :asc ? 1 : -1
      elsif @direction == :asc
        left_time <=> right_time
      else
        right_time <=> left_time
      end
    end
  end
end
