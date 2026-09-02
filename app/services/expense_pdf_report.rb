# frozen_string_literal: true

require "prawn"
require "prawn/table"

class ExpensePdfReport
  FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
  ].freeze
  FONT_BOLD = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
  ].freeze

  def self.build(user, from:, to:)
    new(user, from: from, to: to).build
  end

  def initialize(user, from:, to:)
    @user = user
    @from = from
    @to = to
    @result = ExpenseMonthSummary.for_user(user, from: from, to: to)
    @rate = BnaOfficialDollar.current
    @movements = user.expenses.where(spent_at: from.beginning_of_day..to.end_of_day).order(spent_at: :asc)
  end

  def build
    dir = Rails.root.join("tmp/reports")
    FileUtils.mkdir_p(dir)
    stamp = Time.zone.now.strftime("%Y%m%d-%H%M")
    path = dir.join("reporte-#{safe_label}-#{stamp}.pdf")
    generate(path)
    path
  end

  def filename
    "reporte-#{safe_label}.pdf"
  end

  private

  def safe_label
    @result.label.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end

  def generate(path)
    Prawn::Document.generate(path.to_s, page_size: "A4", margin: 40) do |pdf|
      setup_fonts(pdf)
      header(pdf)
      totals(pdf)
      breakdowns(pdf)
      movements_table(pdf)
      footer(pdf)
    end
  end

  def setup_fonts(pdf)
    regular = FONTS.find { |p| File.file?(p) }
    bold = FONT_BOLD.find { |p| File.file?(p) }
    return unless regular

    family = {
      normal: regular,
      bold: bold || regular
    }
    pdf.font_families.update("Report" => family)
    pdf.font "Report"
  end

  def header(pdf)
    pdf.fill_color "1F3A5F"
    pdf.font_size(18) { pdf.text "Reporte de gastos e ingresos" }
    pdf.move_down 4
    pdf.fill_color "334155"
    pdf.font_size(12) { pdf.text @result.label }
    pdf.font_size(9) do
      pdf.text "Generado: #{Time.zone.now.strftime("%d/%m/%Y %H:%M")}  ·  Rubro: #{@user.occupation.presence || "sin cargar"}"
      pdf.text dollar_line
    end
    pdf.move_down 10
    pdf.stroke_color "1F3A5F"
    pdf.stroke_horizontal_rule
    pdf.move_down 14
    pdf.fill_color "111827"
  end

  def dollar_line
    if @rate&.venta.to_f.positive?
      stale = @rate.stale ? " (última conocida)" : ""
      "Dólar oficial BNA  compra #{MoneyFormat.ars((@rate.compra * 100).round)}  /  venta #{MoneyFormat.ars((@rate.venta * 100).round)}#{stale}"
    else
      "Dólar oficial BNA no disponible al generar el reporte"
    end
  end

  def totals(pdf)
    balance = @result.income_total_cents - @result.expense_total_cents
    data = [
      ["", "Cantidad", "ARS", "USD oficial"],
      ["Ingresos", @result.income_count.to_s, MoneyFormat.ars(@result.income_total_cents), usd_cell(@result.income_total_cents)],
      ["Gastos", @result.expense_count.to_s, MoneyFormat.ars(@result.expense_total_cents), usd_cell(@result.expense_total_cents)],
      ["Balance", "", MoneyFormat.ars(balance), usd_cell(balance)]
    ]
    pdf.table(data, header: true, width: pdf.bounds.width) do
      cells.size = 9
      cells.padding = [6, 8]
      row(0).font_style = :bold
      row(0).background_color = "1F3A5F"
      row(0).text_color = "FFFFFF"
      columns(1..3).align = :right
      row(1).text_color = "166534"
      row(2).text_color = "991B1B"
      row(3).font_style = :bold
      row(3).background_color = balance.negative? ? "FEE2E2" : "DCFCE7"
    end
    pdf.move_down 16
  end

  def breakdowns(pdf)
    draw_kv_table(pdf, "Ingresos por categoría", @result.incomes_by_category)
    draw_kv_table(pdf, "Gastos por categoría", @result.expenses_by_category)
    draw_kv_table(pdf, "Gastos por medio de pago", @result.expenses_by_payment)
  end

  def draw_kv_table(pdf, title, pairs)
    return if pairs.blank?

    pdf.font_size(11) { pdf.text title, style: :bold }
    pdf.move_down 6
    rows = [["Concepto", "ARS", "USD oficial"]]
    pairs.each do |name, cents|
      rows << [name.to_s, MoneyFormat.ars(cents), usd_cell(cents)]
    end
    pdf.table(rows, header: true, width: pdf.bounds.width) do
      cells.size = 9
      cells.padding = [5, 8]
      row(0).font_style = :bold
      row(0).background_color = "E2E8F0"
      columns(1..2).align = :right
    end
    pdf.move_down 14
  end

  def movements_table(pdf)
    pdf.start_new_page if pdf.cursor < 120
    pdf.font_size(11) { pdf.text "Movimientos", style: :bold }
    pdf.move_down 6

    if @movements.empty?
      pdf.font_size(9) { pdf.text "No hay movimientos en este período." }
      return
    end

    rows = [["Fecha", "Tipo", "Categoría", "Pago", "Descripción", "Monto"]]
    @movements.each do |e|
      sign = e.income? ? "+" : "−"
      rows << [
        e.spent_at.in_time_zone.strftime("%d/%m"),
        e.income? ? "Ingreso" : "Gasto",
        [e.category, e.subcategory].compact.join(" / "),
        e.payment_method.to_s,
        (e.description.presence || e.raw_text).to_s.truncate(42),
        "#{sign}#{MoneyFormat.ars(e.amount_cents)}"
      ]
    end

    pdf.table(rows, header: true, width: pdf.bounds.width, row_colors: %w[FFFFFF F8FAFC]) do
      cells.size = 8
      cells.padding = [4, 4]
      row(0).font_style = :bold
      row(0).background_color = "1F3A5F"
      row(0).text_color = "FFFFFF"
      columns(5).align = :right
      columns(0).width = 42
      columns(1).width = 52
      columns(5).width = 72
    end
  end

  def footer(pdf)
    pdf.repeat(:all) do
      pdf.fill_color "64748B"
      pdf.font_size(8) do
        pdf.draw_text Brand::CREDIT, at: [0, 0]
      end
      pdf.fill_color "111827"
    end
    pdf.number_pages "Página <page> de <total>", at: [0, 0], align: :right, size: 8, color: "64748B"
  end

  def usd_cell(amount_cents)
    usd = BnaOfficialDollar.ars_to_usd(amount_cents, rate: @rate)
    usd ? MoneyFormat.usd(usd) : "—"
  end
end
