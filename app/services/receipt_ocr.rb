# frozen_string_literal: true

require "shellwords"

class ReceiptOcr
  def self.available?
    system("command -v tesseract >/dev/null 2>&1")
  end

  # Extrae texto de una imagen. Devuelve string o nil.
  def self.extract_text(path)
    return nil unless available? && File.file?(path.to_s)

    langs = spanish_trained? ? "spa+eng" : "eng"
    cmd = "tesseract #{Shellwords.escape(path.to_s)} stdout -l #{langs} --psm 6"
    text = `#{cmd} 2>/dev/null`.to_s.strip
    text.presence
  end

  def self.spanish_trained?
    `tesseract --list-langs 2>/dev/null`.include?("spa")
  end
end
