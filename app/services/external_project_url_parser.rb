class ExternalProjectUrlParser
  def self.detect_source(url)
    return nil unless url.present?
    if url.include?('app.asana.com') || url.include?('asana.com')
      'asana'
    elsif url.include?('jira.com')
      'jira'
    elsif url.include?('linear.app')
      'linear'
    else
      nil
    end
  end

  def self.extract_project_id(url, source)
    return nil unless url.present? && source.present?
    case source
    when 'asana'
      AsanaUrlParser.extract_project_id(url)
    when 'jira'
      # Example: https://jira.com/browse/PROJECT-123 -> PROJECT
      match = url.match(%r{/browse/([A-Z0-9]+)-})
      match[1] if match
    when 'linear'
      # Example: https://linear.app/team/project-name/issue/PRO-123 -> PRO
      match = url.match(%r{/issue/([A-Z0-9]+)-})
      match[1] if match
    else
      nil
    end
  end

  def self.valid_project_url?(url, source)
    return false unless url.present? && source.present?
    case source
    when 'asana'
      url.include?('app.asana.com') || url.include?('asana.com')
    when 'jira'
      url.include?('jira.com')
    when 'linear'
      url.include?('linear.app')
    else
      false
    end
  end
end

