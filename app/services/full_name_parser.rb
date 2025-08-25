class FullNameParser
  # Common suffixes that should be extracted
  SUFFIXES = %w[
    I II III IV V VI VII VIII IX X
    Jr Jr. Junior
    Sr Sr. Senior
    Esq Esq. Esquire
    PhD Ph.D. PHD
    MD M.D.
    DDS D.D.S.
    RN R.N.
    CPA C.P.A.
    MBA M.B.A.
    JD J.D.
    LLM L.L.M.
    MS M.S. MSc
    MA M.A. M.A.
    BA B.A. B.S. BS
    PhD Ph.D. PHD
    Dr Dr.
    Prof Professor
    Rev Reverend
    Hon Honorable
    Capt Captain
    Col Colonel
    Gen General
    Lt Lieutenant
    Maj Major
    Sgt Sergeant
  ].freeze

  attr_reader :full_name, :first_name, :middle_name, :last_name, :suffix

  def initialize(full_name)
    @full_name = full_name.to_s.strip
    parse_name
  end

  def parse_name
    if @full_name.blank?
      @first_name = ''
      @middle_name = nil
      @last_name = nil
      @suffix = nil
      return
    end

    # Extract suffix first
    extract_suffix
    
    # Split remaining name into parts
    name_parts = @full_name.split(/\s+/)
    
    case name_parts.length
    when 0
      # No name parts
      @first_name = @full_name
      @middle_name = nil
      @last_name = nil
    when 1
      # Single name - treat as first name
      @first_name = name_parts[0]
      @middle_name = nil
      @last_name = nil
    when 2
      # Two names - first and last
      @first_name = name_parts[0]
      @middle_name = nil
      @last_name = name_parts[1]
    when 3
      # Three names - first, middle, last
      @first_name = name_parts[0]
      @middle_name = name_parts[1]
      @last_name = name_parts[2]
    else
      # Four or more names - first, middle (combined), last
      @first_name = name_parts[0]
      @middle_name = name_parts[1...-1].join(' ')
      @last_name = name_parts.last
    end
  end

  def to_h
    {
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      suffix: suffix
    }.compact
  end

  def to_params
    to_h
  end

  private

  def extract_suffix
    # Check if the last word is a suffix
    words = @full_name.split(/\s+/)
    return if words.empty?
    
    last_word = words.last
    
    # Check if the last word matches any suffix (case insensitive)
    SUFFIXES.each do |suffix|
      if last_word.downcase == suffix.downcase
        @suffix = last_word
        # Remove the suffix from the full name
        @full_name = words[0...-1].join(' ').strip
        return
      end
    end
    
    @suffix = nil
  end
end
