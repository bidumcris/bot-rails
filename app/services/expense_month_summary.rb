# frozen_string_literal: true

class ExpenseMonthSummary
  MONTHS = {
    "enero" => 1, "febrero" => 2, "marzo" => 3, "abril" => 4,
    "mayo" => 5, "junio" => 6, "julio" => 7, "agosto" => 8,
    "septiembre" => 9, "setiembre" => 9, "octubre" => 10,
    "noviembre" => 11, "diciembre" => 12
  }.freeze

  Result = Struct.new(
    :range_start, :range_end, :label,
    :expense_total_cents, :income_total_cents, :expense_count, :income_count,
    :expenses_by_category, :incomes_by_category, :expenses_by_payment,
    keyword_init: true
  )

  def self.parse_month_query(text, now: Time.zone.now)
    t = text.to_s.strip.downcase
    t = t.sub(%r{\A/}, "")

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
    expenses = scope.expenses_only
    incomes = scope.incomes_only
    month_name = MONTHS.key(from.month)&.capitalize || from.strftime("%m")

    Result.new(
      range_start: from,
      range_end: to,
      label: "#{month_name} #{from.year}",
      expense_total_cents: expenses.sum(:amount_cents),
      income_total_cents: incomes.sum(:amount_cents),
      expense_count: expenses.count,
      income_count: incomes.count,
      expenses_by_category: expenses.group(:category).sum(:amount_cents).sort_by { |_, c| -c },
      incomes_by_category: incomes.group(:category).sum(:amount_cents).sort_by { |_, c| -c },
      expenses_by_payment: expenses.where.not(payment_method: [nil, ""]).group(:payment_method).sum(:amount_cents).sort_by { |_, c| -c }
    )
  end

  def self.format_message(result, format_ars:, usd_rate: nil)
    balance = result.income_total_cents - result.expense_total_cents
    lines = []
    lines << "📅 #{result.label}"
    lines << "Ingresos: #{result.income_count} — #{format_ars.call(result.income_total_cents)}"
    lines << "Gastos: #{result.expense_count} — #{format_ars.call(result.expense_total_cents)}"
    lines << "Balance: #{format_ars.call(balance)}"
    if usd_rate&.venta.to_f.positive?
      to_usd = ->(cents) { format("USD %.2f", (cents.to_i / 100.0) / usd_rate.venta) }
      lines << "≈ #{to_usd.call(result.income_total_cents)} ingresos / #{to_usd.call(result.expense_total_cents)} gastos"
      stale = usd_rate.stale ? " (última conocida)" : ""
      lines << "Oficial BNA venta #{MoneyFormat.ars((usd_rate.venta * 100).round)}#{stale}"
    end

    if result.incomes_by_category.any?
      lines << ""
      lines << "Ingresos por categoría:"
      result.incomes_by_category.each { |cat, cents| lines << "• #{cat}: #{format_ars.call(cents)}" }
    end

    if result.expenses_by_category.any?
      lines << ""
      lines << "Gastos por categoría:"
      result.expenses_by_category.each { |cat, cents| lines << "• #{cat}: #{format_ars.call(cents)}" }
    end

    if result.expenses_by_payment&.any?
      lines << ""
      lines << "Gastos por medio de pago:"
      result.expenses_by_payment.each { |method, cents| lines << "• #{method}: #{format_ars.call(cents)}" }
    end

    if result.income_count.zero? && result.expense_count.zero?
      lines << ""
      lines << "No hay movimientos en este período."
    end

    lines.join("\n")
  end
end
