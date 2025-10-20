class Enm::PartnershipsController < Enm::BaseController
  before_action :set_partnership, only: [:show, :edit, :update, :add_assessment, :remove_assessment]
  
  def new
    @partnership = EnmPartnership.new
  end
  
  def create
    # Parse assessment codes from comma-separated string
    codes_string = params[:enm_partnership][:assessment_codes]
    assessment_codes = codes_string.split(',').map(&:strip).reject(&:blank?)
    
    # Generate a unique code for the partnership
    code = Enm::CodeGeneratorService.generate_unique_code(EnmPartnership)
    
    @partnership = EnmPartnership.new(code: code, assessment_codes: assessment_codes)
    
    if @partnership.save
      analyzer = Enm::PartnershipAnalyzerService.new
      analysis = analyzer.analyze_compatibility(@partnership.assessment_codes)
      
      @partnership.update!(
        compatibility_analysis: analysis,
        relationship_type: analysis[:relationship_type]
      )
      
      redirect_to enm_partnership_path(@partnership.code)
    else
      render :new
    end
  end
  
  def show
    @assessments = @partnership.assessments
    @analyzer = Enm::PartnershipAnalyzerService.new
  end
  
  def add_assessment
    assessment_code = params[:assessment_code]
    
    if EnmAssessment.exists?(code: assessment_code)
      @partnership.add_assessment_code(assessment_code)
      @partnership.save!
      
      # Re-analyze compatibility
      analyzer = Enm::PartnershipAnalyzerService.new
      analysis = analyzer.analyze_compatibility(@partnership.assessment_codes)
      @partnership.update!(
        compatibility_analysis: analysis,
        relationship_type: analysis[:relationship_type]
      )
      
      redirect_to enm_partnership_path(@partnership.code)
    else
      flash[:error] = "Assessment code '#{assessment_code}' not found"
      redirect_to enm_partnership_path(@partnership.code)
    end
  end
  
  def remove_assessment
    assessment_code = params[:assessment_code]
    
    @partnership.remove_assessment_code(assessment_code)
    
    # Don't save if no assessments left - just redirect
    if @partnership.assessment_codes.empty?
      redirect_to enm_partnership_path(@partnership.code)
    else
      @partnership.save!
      
      # Re-analyze compatibility
      analyzer = Enm::PartnershipAnalyzerService.new
      analysis = analyzer.analyze_compatibility(@partnership.assessment_codes)
      @partnership.update!(
        compatibility_analysis: analysis,
        relationship_type: analysis[:relationship_type]
      )
      
      redirect_to enm_partnership_path(@partnership.code)
    end
  end
  
  def edit
    # Edit partnership form
  end
  
  def update
    if @partnership.update(partnership_params)
      # Re-analyze compatibility
      analyzer = Enm::PartnershipAnalyzerService.new
      analysis = analyzer.analyze_compatibility(@partnership.assessment_codes)
      @partnership.update!(
        compatibility_analysis: analysis,
        relationship_type: analysis[:relationship_type]
      )
      
      redirect_to enm_partnership_path(@partnership.code)
    else
      render :edit
    end
  end
  
  private
  
  def set_partnership
    @partnership = EnmPartnership.find_by!(code: params[:code])
  end
  
  def partnership_params
    params.require(:enm_partnership).permit(:assessment_codes)
  end
end
