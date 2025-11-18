module Goals
  class FilterQuery
    def initialize(relation = Goal.all)
      @relation = relation
    end

    def call(show_deleted: false, show_completed: false)
      # If both are shown, return everything
      return @relation if show_deleted && show_completed
      
      # If neither are shown, exclude both
      return @relation.where(deleted_at: nil, completed_at: nil) unless show_deleted || show_completed
      
      # If only one is shown, we need OR logic
      if show_deleted && !show_completed
        # Show: active (neither) + deleted (deleted only) + deleted_and_completed (both)
        # Exclude: completed (completed only)
        # Logic: NOT (completed_at IS NOT NULL AND deleted_at IS NULL)
        @relation.where('deleted_at IS NOT NULL OR completed_at IS NULL')
      else # show_completed && !show_deleted
        # Show: active (neither) + completed (completed only) + deleted_and_completed (both)
        # Exclude: deleted (deleted only)
        # Logic: NOT (deleted_at IS NOT NULL AND completed_at IS NULL)
        @relation.where('completed_at IS NOT NULL OR deleted_at IS NULL')
      end
    end
  end
end

