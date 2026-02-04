require 'set'

class SeatHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns an array of root seat nodes, each with nested children
  # Each node is a hash with: seat, children (array of child nodes), direct_reports_count, total_reports_count
  def call
    return [] unless @organization

    # Get all seats for this organization
    seats = Seat.for_organization(@organization)
               .includes(:title, :reports_to_seat, :reporting_seats, employment_tenures: { company_teammate: :person })
               .order('titles.external_title ASC, seats.seat_needed_by ASC')

    # Build seat data hash and parent-child map
    seat_data = {}
    parent_child_map = {}
    seats_with_parents = Set.new

    seats.each do |seat|
      seat_id = seat.id

      # Store seat data
      seat_data[seat_id] = {
        seat: seat
      }

      # Build parent-child relationships
      if seat.reports_to_seat_id
        parent_id = seat.reports_to_seat_id
        parent_child_map[parent_id] ||= []
        parent_child_map[parent_id] << seat_id
        seats_with_parents.add(seat_id)

        # Ensure parent data exists
        unless seat_data[parent_id]
          parent_seat = seats.find { |s| s.id == parent_id }
          if parent_seat
            seat_data[parent_id] = {
              seat: parent_seat
            }
          end
        end
      end
    end

    # Find root seats (those with no parent)
    all_seat_ids = seat_data.keys.to_set
    root_seat_ids = all_seat_ids - seats_with_parents

    # Build tree structure starting from roots
    root_seat_ids.map do |seat_id|
      build_tree_node(seat_id, seat_data, parent_child_map)
    end.compact.sort_by { |node| node[:seat].display_name }
  end

  private

  def build_tree_node(seat_id, seat_data, parent_child_map)
    data = seat_data[seat_id]
    return nil unless data

    children_ids = parent_child_map[seat_id] || []
    children = children_ids.map do |child_id|
      build_tree_node(child_id, seat_data, parent_child_map)
    end.compact.sort_by { |node| node[:seat].display_name }

    # Calculate direct reports (immediate children) and total reports (all descendants)
    direct_reports_count = children.length
    total_reports_count = direct_reports_count + children.sum { |child| child[:total_reports_count] || 0 }

    {
      seat: data[:seat],
      children: children,
      direct_reports_count: direct_reports_count,
      total_reports_count: total_reports_count
    }
  end
end

