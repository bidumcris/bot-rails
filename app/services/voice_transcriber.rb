# frozen_string_literal: true

require "shellwords"
require "open3"
require "timeout"

class VoiceTranscriber
  MAX_SECONDS = 45
  DEFAULT_BIN = "/opt/whisper/whisper-cli"
  DEFAULT_MODEL = "/opt/whisper/models/ggml-base.bin"

  def self.available?
    ffmpeg_ok? && File.executable?(binary) && File.file?(model_path)
  end

  def self.ffmpeg_ok?
    system("command -v ffmpeg >/dev/null 2>&1")
  end

  def self.binary
    ENV["WHISPER_BIN"].presence ||
      Rails.root.join("vendor/whisper/whisper-cli").to_s.then { |p| File.executable?(p) ? p : nil } ||
      `command -v whisper-cli 2>/dev/null`.to_s.strip.presence ||
      DEFAULT_BIN
  end

  def self.model_path
    ENV["WHISPER_MODEL"].presence ||
      Rails.root.join("vendor/whisper/models/ggml-base.bin").to_s.then { |p| File.file?(p) ? p : nil } ||
      DEFAULT_MODEL
  end

  def self.language
    ENV["WHISPER_LANGUAGE"].presence || "es"
  end

  # Transcribe un audio (ogg/opus/mp3/m4a/wav). Devuelve texto o nil.
  def self.transcribe(path)
    return nil unless available? && File.file?(path.to_s)

    dir = Rails.root.join("tmp/voices")
    FileUtils.mkdir_p(dir)
    id = "#{Process.pid}-#{Time.now.to_i}-#{File.basename(path.to_s, ".*")}"
    wav = dir.join("#{id}.wav")
    out_base = dir.join(id.to_s)

    convert_ok = system(
      "ffmpeg -y -i #{Shellwords.escape(path.to_s)} -ar 16000 -ac 1 -c:a pcm_s16le #{Shellwords.escape(wav.to_s)}",
      out: File::NULL,
      err: File::NULL
    )
    return nil unless convert_ok && File.file?(wav)

    commands = [
      [binary, "-m", model_path, "-f", wav.to_s, "-l", language, "-nt", "-np", "-otxt", "-of", out_base.to_s],
      [binary, "-m", model_path, "-f", wav.to_s, "-l", language, "--output-txt", "--output-file", out_base.to_s],
      [binary, "-m", model_path, "-f", wav.to_s, "-l", language, "-otxt", "-of", out_base.to_s]
    ]

    stdout = ""
    commands.each do |cmd|
      stdout, _stderr, status = Timeout.timeout(90) { Open3.capture3(*cmd) }
      break if status.success? || File.file?("#{out_base}.txt")
    rescue Timeout::Error
      next
    end

    txt = Pathname.new("#{out_base}.txt")
    text = File.file?(txt) ? File.read(txt).to_s : ""
    text = clean(text)
    return text if text.present?

    clean(stdout.to_s).presence
  ensure
    FileUtils.rm_f(wav) if defined?(wav)
    FileUtils.rm_f("#{out_base}.txt") if defined?(out_base)
  end

  def self.clean(text)
    s = text.to_s
    s = s.gsub(/\[.*?\]/, " ")
    s = s.gsub(/^\s*(whisper|system|main|encoder|decoder|cpu|gpu|ggml).*$/i, " ")
    s = s.gsub(/\s+/, " ").strip
    s = s.gsub(/\A["'«»]+|["'«»]+\z/, "").strip
    s.presence
  end
end
