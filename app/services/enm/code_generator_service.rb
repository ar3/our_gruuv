class Enm::CodeGeneratorService
  def self.generate_unique_code(model_class)
    loop do
      code = SecureRandom.alphanumeric(8).upcase
      return code unless model_class.exists?(code: code)
    end
  end
end
