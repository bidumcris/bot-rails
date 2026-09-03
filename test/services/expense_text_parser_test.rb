# frozen_string_literal: true

require "test_helper"

class ExpenseTextParserTest < ActiveSupport::TestCase
  def parse_many(text, usd_venta: 1500)
    ExpenseTextParser.parse_many(text, usd_venta: usd_venta)
  end

  test "un solo gasto sigue igual" do
    items = parse_many("hamburguesa 8500")
    assert_equal 1, items.size
    assert_equal 850_000, items.first.amount_cents
    assert_match(/hamburguesa/i, items.first.description)
    assert_equal "expense", items.first.kind
  end

  test "dos gastos unidos con y" do
    items = parse_many("hamburguesa 8500 y coca 2000")
    assert_equal 2, items.size
    assert_equal [850_000, 200_000], items.map(&:amount_cents)
    assert_match(/hamburguesa/i, items[0].description)
    assert_match(/coca/i, items[1].description)
  end

  test "dos gastos en líneas" do
    items = parse_many("hamburguesa 8500\ncoca 2000")
    assert_equal 2, items.size
    assert_equal [850_000, 200_000], items.map(&:amount_cents)
  end

  test "voz: monto primero y después descripción" do
    items = parse_many("gasté 8500 en hamburguesa y 2500 en almohadillas")
    assert_equal 2, items.size
    assert_equal [850_000, 250_000], items.map(&:amount_cents)
    assert_match(/hamburguesa/i, items[0].description)
    assert_match(/almohadill/i, items[1].description)
  end

  test "mixto ars y usd" do
    items = parse_many("hamburguesa 8500 y netflix 8 usd", usd_venta: 1500)
    assert_equal 2, items.size
    assert_equal 850_000, items[0].amount_cents
    assert_equal 1_200_000, items[1].amount_cents
    assert_match(/netflix/i, items[1].description)
  end

  test "cada uno no se parte en dos" do
    items = parse_many("2 menús 9000 cada uno")
    assert_equal 1, items.size
    assert_equal 1_800_000, items.first.amount_cents
  end

  test "cada uno más otro gasto" do
    items = parse_many("2 menús 9000 cada uno y coca 2000")
    assert_equal 2, items.size
    assert_equal [1_800_000, 200_000], items.map(&:amount_cents)
  end

  test "ingreso y gasto en el mismo mensaje" do
    items = parse_many("cobro 84150 pilates y hamburguesa 8500")
    assert_equal 2, items.size
    assert_equal "income", items[0].kind
    assert_equal "expense", items[1].kind
    assert_equal 8_415_000, items[0].amount_cents
    assert_equal 850_000, items[1].amount_cents
  end

  test "sin monto devuelve un item vacío" do
    items = parse_many("compré facturas")
    assert_equal 1, items.size
    assert_nil items.first.amount_cents
  end

  test "tres gastos con coma y y" do
    items = parse_many("luz 23000, gas 15000 y agua 8000")
    assert_equal 3, items.size
    assert_equal [2_300_000, 1_500_000, 800_000], items.map(&:amount_cents)
    assert_match(/luz/i, items[0].description)
    assert_match(/gas/i, items[1].description)
    assert_match(/agua/i, items[2].description)
  end
end
