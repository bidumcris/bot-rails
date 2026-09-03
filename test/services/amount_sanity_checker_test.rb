# frozen_string_literal: true

require "test_helper"

class AmountSanityCheckerTest < ActiveSupport::TestCase
  def rate
    BnaOfficialDollar::Rate.new(
      compra: 1485.0,
      venta: 1500.0,
      updated_at: Time.zone.now,
      source: "test",
      stale: false
    )
  end

  def check(amount_cents, description, category: nil)
    AmountSanityChecker.check(
      amount_cents: amount_cents,
      description: description,
      kind: "expense",
      category: category,
      rate: rate
    )
  end

  test "30 en el medico pregunta por 30 mil" do
    result = check(3_000, "medico")
    assert result.suspicious
    assert_equal :too_low, result.reason
    assert_equal 3_000_000, result.suggestions.first.amount_cents
  end

  test "30 mil en el medico no pregunta" do
    result = check(3_000_000, "el médico")
    assert_not result.suspicious
  end

  test "cafe 30 sugiere 3000 no 30 mil" do
    result = check(3_000, "café")
    assert result.suspicious
    assert_equal :too_low, result.reason
    assert_equal 300_000, result.suggestions.first.amount_cents
    assert result.suggestions.none? { |s| s.amount_cents == 3_000_000 }
  end

  test "hamburguesa cara sigue preguntando" do
    result = check(12_500_000, "hamburguesa")
    assert result.suspicious
    assert_equal :too_high, result.reason
    assert result.suggestions.any? { |s| s.amount_cents == 1_250_000 }
  end
end
