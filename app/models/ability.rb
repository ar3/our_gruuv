class Ability < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :created_by, class_name: 'Person'
  belongs_to :updated_by, class_name: 'Person'

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :description, presence: true
  validates :semantic_version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/, message: 'must be in semantic version format (e.g., 1.0.0)' }

  scope :for_organization, ->(org) { where(organization: org) }
  scope :recent, -> { order(updated_at: :desc) }

  # Version bumping methods
  def bump_major_version(reason)
    update!(semantic_version: next_major_version)
  end

  def bump_minor_version(reason)
    update!(semantic_version: next_minor_version)
  end

  def bump_patch_version(reason)
    update!(semantic_version: next_patch_version)
  end

  # Version calculation methods
  def next_major_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major + 1}.0.0"
  end

  def next_minor_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor + 1}.0"
  end

  def next_patch_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor}.#{patch + 1}"
  end

  # Version status methods
  def current_version?
    # The current version is the latest one (no newer versions exist)
    !versions.where('created_at > ?', updated_at).exists?
  end

  def deprecated?
    !current_version?
  end

  # Display methods
  def display_name
    "#{name} v#{semantic_version}"
  end

  def version_with_guidance
    return display_name unless versions.any?

    latest_version = versions.last
    change_reason = latest_version.meta['change_reason']
    change_type = latest_version.meta['version_change_type']

    if change_reason && change_type
      "#{display_name} (#{change_type}: #{change_reason})"
    else
      display_name
    end
  end
end
