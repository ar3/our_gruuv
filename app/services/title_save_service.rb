class TitleSaveService
  def self.create(title:, params:)
    new(title: title, params: params).create
  end

  def self.update(title:, params:)
    new(title: title, params: params).update
  end

  def self.delete(title:)
    new(title: title).delete
  end

  def initialize(title:, params: nil)
    @title = title
    @params = params
  end

  def create
    ApplicationRecord.transaction do
      @title.assign_attributes(@params) if @params
      
      if @title.save
        Result.ok(@title)
      else
        Result.err(@title.errors.full_messages)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  def update
    ApplicationRecord.transaction do
      # Track if position_major_level_id is changing
      old_major_level_id = @title.position_major_level_id
      
      if @params
        @title.assign_attributes(@params)
      end
      
      new_major_level_id = @title.position_major_level_id
      major_level_changed = old_major_level_id != new_major_level_id && @title.persisted?
      if @title.save
        # If major level changed, update all associated positions
        if major_level_changed
          update_positions_for_new_major_level(old_major_level_id, new_major_level_id)
        end
        
        Result.ok(@title)
      else
        Result.err(@title.errors.full_messages)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  def delete
    ApplicationRecord.transaction do
      @title.destroy
      Result.ok(@title)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  rescue => e
    Result.err("Failed to delete title: #{e.message}")
  end

  private

  def update_positions_for_new_major_level(old_major_level_id, new_major_level_id)
    return unless old_major_level_id && new_major_level_id
    
    new_major_level = PositionMajorLevel.find(new_major_level_id)
    
    # Get all positions associated with this title
    @title.positions.each do |position|
      current_level_value = position.position_level.level
      minor_level = current_level_value.split('.').last
      new_position_level_level = new_major_level.major_level.to_s + '.' + minor_level
      Rails.logger.info("❌❌❌❌1️⃣1️⃣1️⃣1️⃣ TitleSaveService: position before anything: #{position.display_name}  || About to change to: #{new_position_level_level}")
      # Find or create a position level with the new major level and same level value
      new_position_level = PositionLevel.find_or_create_by!(
        position_major_level: new_major_level,
        level: new_position_level_level
      )
      Rails.logger.info("❌❌❌❌2️⃣2️⃣2️⃣2️⃣ TitleSaveService: new_position_level: #{new_position_level.display_name} for position: #{position.display_name}")
      # Update the position to use the new position level
      position.update!(position_level: new_position_level)
      Rails.logger.info("❌❌❌❌3️⃣3️⃣3️⃣3️⃣ TitleSaveService: position updated: #{position.display_name}")
    end
  end
end
