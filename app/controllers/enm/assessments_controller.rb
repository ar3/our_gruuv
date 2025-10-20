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
  end
  
  def update_phase
    @phase = params[:phase].to_i
    @form = form_for_phase(@phase)
    
    if @form.validate(assessment_params)
      update_assessment_from_form(@form, @phase)
      
      if @phase < 3
        redirect_to phase_enm_assessment_path(@assessment.code, phase: @phase + 1)
      else
        redirect_to enm_assessment_path(@assessment.code)
      end
    else
      render :show_phase
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
      Enm::AssessmentPhase1Form.new(@assessment)
    when 2
      Enm::AssessmentPhase2Form.new(@assessment)
    when 3
      Enm::AssessmentPhase3Form.new(@assessment)
    else
      raise ArgumentError, "Invalid phase: #{phase}"
    end
  end
  
  def assessment_params
    # Reform forms send params with their model name (e.g., enm_assessment_phase1)
    # Try to find the params for the current phase
    params[:enm_assessment_phase1] || params[:enm_assessment_phase2] || params[:enm_assessment_phase3] || params[:assessment] || {}
  end
  
  def update_assessment_from_form(form, phase)
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
      results = calculator.calculate_phase_2_results(form.phase_2_data)
      @assessment.update!(
        phase_2_data: form.phase_2_data,
        completed_phase: 2,
        style: results[:style]
      )
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
end
