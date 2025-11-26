module ModelSemanticVersionable
  extend ActiveSupport::Concern

  included do
    validates :semantic_version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/, message: 'must be in semantic version format (e.g., 1.0.0)' }
    has_paper_trail
  end

  # Version bumping methods
  def bump_major_version(reason = nil)
    update!(semantic_version: next_major_version)
  end

  def bump_minor_version(reason = nil)
    update!(semantic_version: next_minor_version)
  end

  def bump_patch_version(reason = nil)
    update!(semantic_version: next_patch_version)
  end

  # Version calculation methods
  def next_major_version
    return "1.0.0" unless semantic_version.present?
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major + 1}.0.0"
  end

  def next_minor_version
    return "0.1.0" unless semantic_version.present?
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor + 1}.0"
  end

  def next_patch_version
    return "0.0.1" unless semantic_version.present?
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor}.#{patch + 1}"
  end

  # Extract major version number from semantic_version
  def major_version
    return 0 unless semantic_version.present?
    semantic_version.split('.').first.to_i
  end

  # Version status methods (uses PaperTrail's versions association)
  def current_version?
    # The current version is the latest one (no newer versions exist)
    !versions.where('created_at > ?', updated_at).exists?
  end

  def deprecated?
    !current_version?
  end

  # Display method - can be overridden by models that need different display logic
  def display_name_with_version
    name_field = respond_to?(:name) ? name : respond_to?(:title) ? title : respond_to?(:display_name) ? display_name : "Item"
    "#{name_field} v#{semantic_version}"
  end

  # PaperTrail version history with metadata
  def version_with_guidance
    return display_name_with_version unless versions.any?

    latest_version = versions.last
    # PaperTrail stores metadata in the object_changes column as YAML
    # We would need additional PaperTrail configuration to store custom metadata
    # For now, just return the display name with version
    display_name_with_version
  end
end


