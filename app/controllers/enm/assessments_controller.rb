class Enm::AssessmentsController < Enm::BaseController
  before_action :set_assessment, only: [:show, :edit, :update, :show_phase, :update_phase]
  
  def new
    # Create a new assessment with a unique code
    code = Enm::CodeGeneratorService.generate_unique_code(EnmAssessment)
    @assessment = EnmAssessment.create!(code: code, completed_phase: 1)
    
    redirect_to phase_enm_assessment_path(@assessment.code, phase: 1)
  end
  
  def show
    # Assessment results page
  end
  
  def show_phase
    @phase = params[:phase].to_i
    @form = form_for_phase(@phase)
    
    # Add progressive analysis for Phase 1
    if @phase == 1
      calculator = Enm::AssessmentCalculatorService.new
      @partial_analysis = calculator.partial_phase_1_analysis(@assessment.phase_1_data)
    end
  end
  
  def update_phase
    @phase = params[:phase].to_i
    @form = form_for_phase(@phase)
    
    # Check which save progress button was clicked
    is_save_progress = params[:save_progress_physical].present? || params[:save_progress_emotional].present?
    
    # Determine the anchor based on which button was clicked
    anchor = if params[:save_progress_physical].present?
               "#physical-intimacy-section"
             elsif params[:save_progress_emotional].present?
               "#emotional-intimacy-section"
             else
               ""
             end
    
    if @form.validate(assessment_params)
      update_assessment_from_form(@form, @phase, is_save_progress)
      
      # If this is a save progress request, stay on same page with anchor
      if is_save_progress
        redirect_to "#{phase_enm_assessment_path(@assessment.code, phase: @phase)}#{anchor}", 
                    notice: 'Progress saved successfully!'
      elsif @phase < 3
        redirect_to phase_enm_assessment_path(@assessment.code, phase: @phase + 1)
      else
        redirect_to enm_assessment_path(@assessment.code)
      end
    else
      # If validation fails but it's a save progress, still try to save partial data
      if is_save_progress
        save_partial_progress(@form, @phase)
        redirect_to "#{phase_enm_assessment_path(@assessment.code, phase: @phase)}#{anchor}", 
                    notice: 'Progress saved (some fields may need completion)'
      else
        render :show_phase
      end
    end
  end
  
  def edit
    @phase = @assessment.completed_phase
    @form = form_for_phase(@phase)
  end
  
  def update
    @phase = @assessment.completed_phase
    @form = form_for_phase(@phase)
    
    if @form.validate(assessment_params)
      update_assessment_from_form(@form, @phase)
      redirect_to enm_assessment_path(@assessment.code)
    else
      render :edit
    end
  end
  
  private
  
  def set_assessment
    @assessment = EnmAssessment.find_by!(code: params[:code])
  end
  
  def form_for_phase(phase)
    case phase
    when 1
      form = Enm::AssessmentPhase1Form.new(@assessment)
      form.populate_from_existing_data if @assessment.phase_1_data.present?
      form
    when 2
      form = Enm::AssessmentPhase2Form.new(@assessment)
      form.populate_from_existing_data if @assessment.phase_2_data.present?
      form
    when 3
      form = Enm::AssessmentPhase3Form.new(@assessment)
      form.populate_from_existing_data if @assessment.phase_3_data.present?
      form
    else
      raise ArgumentError, "Invalid phase: #{phase}"
    end
  end
  
  def assessment_params
    # Reform forms send params with their model name (e.g., enm_assessment_phase1)
    # Try to find the params for the current phase
    params[:enm_assessment_phase1] || params[:enm_assessment_phase2] || params[:enm_assessment_phase3] || params[:assessment] || {}
  end
  
  def update_assessment_from_form(form, phase, is_save_progress = false)
    calculator = Enm::AssessmentCalculatorService.new
    
    case phase
    when 1
      results = calculator.calculate_phase_1_results(form.phase_1_data)
      @assessment.update!(
        phase_1_data: form.phase_1_data,
        completed_phase: 1,
        macro_category: results[:macro_category],
        readiness: results[:readiness]
      )
    when 2
      if is_save_progress
        # For save progress, just save the data without calculating results
        existing_data = @assessment.phase_2_data || {}
        merged_data = existing_data.deep_merge(form.phase_2_data)
        @assessment.update!(phase_2_data: merged_data)
      else
        # Normal completion - calculate results
        results = calculator.calculate_phase_2_results(form.phase_2_data)
        @assessment.update!(
          phase_2_data: form.phase_2_data,
          completed_phase: 2,
          style: results[:style]
        )
      end
    when 3
      full_code = calculator.generate_final_code(
        @assessment.macro_category,
        @assessment.readiness,
        @assessment.style
      )
      @assessment.update!(
        phase_3_data: { confirmed: true },
        completed_phase: 3,
        full_code: full_code
      )
    end
  end

  def save_partial_progress(form, phase)
    # Save whatever data we can, even if validation fails
    case phase
    when 2
      existing_data = @assessment.phase_2_data || {}
      # Get the raw params and merge them
      new_data = form.phase_2_data rescue {}
      merged_data = existing_data.deep_merge(new_data)
      @assessment.update!(phase_2_data: merged_data)
    end
  end
end
