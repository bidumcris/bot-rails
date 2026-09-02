# frozen_string_literal: true

module MoneyFormat
  module_function

  def ars(amount_cents)
    pesos = amount_cents.to_i / 100.0
    sign = pesos.negative? ? "-" : ""
    abs = pesos.abs
    int = abs.floor
    dec = ((abs.round(2) - int) * 100).round
    dec = 0 if dec.negative?
    if dec >= 100
      int += 1
      dec = 0
    end
    "#{sign}$#{thousands(int)},#{format('%02d', dec)}"
  end

  def usd(amount)
    return nil if amount.nil?

    format("USD %.2f", amount)
  end

  def ars_with_usd(amount_cents, rate: BnaOfficialDollar.current)
    text = "#{ars(amount_cents)} ARS"
    usd_amount = BnaOfficialDollar.ars_to_usd(amount_cents, rate: rate)
    return text unless usd_amount

    "#{text} (≈ #{usd(usd_amount)} oficial BNA)"
  end

  def thousands(int)
    int.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end
