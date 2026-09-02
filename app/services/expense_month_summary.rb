# frozen_string_literal: true

class ExpenseMonthSummary
  MONTHS = {
    "enero" => 1, "febrero" => 2, "marzo" => 3, "abril" => 4,
    "mayo" => 5, "junio" => 6, "julio" => 7, "agosto" => 8,
    "septiembre" => 9, "setiembre" => 9, "octubre" => 10,
    "noviembre" => 11, "diciembre" => 12
  }.freeze

  Result = Struct.new(:range_start, :range_end, :label, :total_cents, :count, :by_category, keyword_init: true)

  def self.parse_month_query(text, now: Time.zone.now)
    t = text.to_s.strip.downcase
    t = t.sub(%r{\A/}, "")

    # /septiembre, /mes septiembre, /mes 9, /mes 2026-09, /resumen
    if t.match?(/\A(resumen|mes)\z/)
      return [now.beginning_of_month.to_date, now.end_of_month.to_date]
    end

    if (m = t.match(/\Ames\s+(\d{4})-(\d{1,2})\z/))
      y, mo = m[1].to_i, m[2].to_i
      d = Date.new(y, mo, 1)
      return [d, d.end_of_month]
    end

    if (m = t.match(/\Ames\s+(\d{1,2})\z/))
      mo = m[1].to_i
      d = Date.new(now.year, mo, 1)
      return [d, d.end_of_month]
    end

    if (m = t.match(/\Ames\s+([a-záéíóúñ]+)\s*(\d{4})?\z/))
      mo = MONTHS[m[1]]
      return nil unless mo
      y = m[2].present? ? m[2].to_i : now.year
      d = Date.new(y, mo, 1)
      return [d, d.end_of_month]
    end

    # /septiembre or /septiembre 2025
    if (m = t.match(/\A([a-záéíóúñ]+)\s*(\d{4})?\z/))
      mo = MONTHS[m[1]]
      return nil unless mo
      y = m[2].present? ? m[2].to_i : now.year
      d = Date.new(y, mo, 1)
      return [d, d.end_of_month]
    end

    nil
  rescue ArgumentError
    nil
  end

  def self.for_user(user, from:, to:)
    scope = user.expenses.where(spent_at: from.beginning_of_day..to.end_of_day)
    by_cat = scope.group(:category).sum(:amount_cents).sort_by { |_, cents| -cents }
    month_name = MONTHS.key(from.month)&.capitalize || from.strftime("%m")
    Result.new(
      range_start: from,
      range_end: to,
      label: "#{month_name} #{from.year}",
      total_cents: scope.sum(:amount_cents),
      count: scope.count,
      by_category: by_cat
    )
  end

  def self.format_message(result, format_ars:)
    lines = []
    lines << "📅 #{result.label}"
    lines << "Gastos: #{result.count} — Total: #{format_ars.call(result.total_cents)}"
    if result.by_category.any?
      lines << ""
      lines << "Por categoría:"
      result.by_category.each do |cat, cents|
        lines << "• #{cat}: #{format_ars.call(cents)}"
      end
    else
      lines << ""
      lines << "No hay gastos en este período."
    end
    lines.join("\n")
  end
end
