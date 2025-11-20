module SemanticVersionable
  extend ActiveSupport::Concern

  included do
    validates :semantic_version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/, message: 'must be in semantic version format (e.g., 1.0.0)' }
    has_paper_trail
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

  # Display method - can be overridden by models that need different display logic
  def display_name_with_version
    name_field = respond_to?(:name) ? name : respond_to?(:title) ? title : respond_to?(:display_name) ? display_name : "Item"
    "#{name_field} v#{semantic_version}"
  end
end


