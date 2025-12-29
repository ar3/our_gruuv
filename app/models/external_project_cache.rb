class ExternalProjectCache < ApplicationRecord
  # Associations
  belongs_to :cacheable, polymorphic: true
  belongs_to :last_synced_by_teammate, class_name: 'Teammate', optional: true

  # Validations
  validates :source, presence: true, inclusion: { in: %w[asana jira linear] }
  validates :external_project_id, presence: true
  validate :items_data_limit

  # Scopes
  scope :for_source, ->(source) { where(source: source) }
  scope :recently_synced, -> { where('last_synced_at > ?', 7.days.ago) }
  scope :stale, -> { where('last_synced_at < ? OR last_synced_at IS NULL', 7.days.ago) }
  scope :for_cacheable, ->(cacheable) { where(cacheable: cacheable) }

  # Instance methods
  def incomplete_items
    items_data.select { |item| item['completed'] == false }
  end

  def recently_completed_items(days = 14)
    cutoff_date = days.days.ago
    items_data.select do |item|
      item['completed'] == true && 
      item['completed_at'].present? && 
      Time.parse(item['completed_at']) >= cutoff_date
    end
  end

  def items_for_section(section_gid)
    sorted_items = items_data.select { |item| item['section_gid'] == section_gid }
    sort_items(sorted_items)
  end

  def section_by_gid(gid)
    sections_data.find { |section| section['gid'] == gid }
  end

  def synced_by_display
    return 'Never synced' unless last_synced_at.present?
    
    syncer_name = last_synced_by_teammate&.person&.display_name || 'Unknown'
    synced_date = last_synced_at.strftime('%b %d, %Y at %I:%M %p')
    "Synced by #{syncer_name} on #{synced_date}"
  end

  private

  def items_data_limit
    if items_data.present? && items_data.is_a?(Array) && items_data.length > 200
      errors.add(:items_data, 'cannot exceed 200 items')
    end
  end

  def business_days_until(date)
    today = Date.current
    return 0 if date <= today

    days = 0
    (today...date).each do |d|
      days += 1 unless d.saturday? || d.sunday?
    end
    days
  end

  def sort_items(items)
    items.sort_by do |item|
      due_on = item['due_on'] ? Date.parse(item['due_on']) : nil
      assigned = item['assignee'].present? ? 0 : 1
      created_at = item['created_at'] ? Time.parse(item['created_at']) : Time.at(0)
      name = item['name'] || ''

      # Due date sorting: overdue first, then due today, then due soon, then future, then no due date
      due_date_priority = case
                          when due_on && due_on < Date.current
                            0 # Overdue
                          when due_on && due_on == Date.current
                            1 # Due today
                          when due_on && business_days_until(due_on) <= 2
                            2 # Due soon
                          when due_on
                            3 # Future due date
                          else
                            4 # No due date
                          end

      [due_date_priority, due_on || Date.new(9999, 12, 31), assigned, created_at, name]
    end
  end
end

