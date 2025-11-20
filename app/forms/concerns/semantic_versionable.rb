module SemanticVersionable
  def self.included(base)
    base.class_eval do
      property :version_type, virtual: true
      validates :version_type, presence: true, unless: :new_form_without_data?
      validate :version_type_for_context

      def calculate_semantic_version
        if model.persisted?
          calculate_version_for_existing
        else
          calculate_version_for_new
        end
      end

      def calculate_version_for_new
        case version_type
        when 'ready'
          "1.0.0"
        when 'nearly_ready'
          "0.1.0"
        when 'early_draft'
          "0.0.1"
        else
          "0.0.1"  # Default to early draft
        end
      end

      def calculate_version_for_existing
        return model.semantic_version unless model.semantic_version.present?

        major, minor, patch = model.semantic_version.split('.').map(&:to_i)

        case version_type
        when 'fundamental'
          "#{major + 1}.0.0"
        when 'clarifying'
          "#{major}.#{minor + 1}.0"
        when 'insignificant'
          "#{major}.#{minor}.#{patch + 1}"
        else
          model.semantic_version
        end
      end

      private

      def new_form_without_data?
        # Don't validate version_type on initial page load (new action)
        # Only validate when form has been submitted with data
        model.new_record? && !@form_data_empty.nil? && @form_data_empty
      end

      def version_type_for_context
        return unless version_type.present?
        
        if model.persisted?
          # For existing records, only allow update types
          unless %w[fundamental clarifying insignificant].include?(version_type)
            errors.add(:version_type, "must be fundamental, clarifying, or insignificant for existing #{model_name}")
          end
        else
          # For new records, only allow creation types
          unless %w[ready nearly_ready early_draft].include?(version_type)
            errors.add(:version_type, "must be ready, nearly ready, or early draft for new #{model_name}")
          end
        end
      end

      def model_name
        model.class.name.underscore.humanize.downcase
      end
    end
  end
end


