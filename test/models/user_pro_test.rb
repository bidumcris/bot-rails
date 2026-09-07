# frozen_string_literal: true

require "test_helper"

class UserProTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(telegram_user_id: "1001")
  end

  test "gratis al empezar" do
    assert_not @user.pro?
    assert @user.trial_available?
    assert_equal ProPlan.free_movements, @user.free_movements_left
  end

  test "trial de 5 dias" do
    assert @user.start_trial!
    assert @user.pro?
    assert_in_delta ProPlan.trial_days.days.from_now, @user.pro_until, 2
    assert_not @user.trial_available?
    assert_not @user.start_trial!
  end

  test "pago extiende 30 dias" do
    @user.grant_pro!(source: "mercadopago", payment_id: "pay_1")
    assert @user.pro?
    assert_equal "pay_1", @user.mp_payment_id
    assert_in_delta ProPlan.paid_days.days.from_now, @user.pro_until, 2
  end

  test "tope mensual en gratis" do
    ProPlan.free_movements.times do |i|
      @user.expenses.create!(
        amount_cents: 1000,
        currency: "ARS",
        description: "x#{i}",
        category: "Otros",
        kind: "expense",
        raw_text: "x",
        spent_at: Time.zone.now
      )
    end
    @user.reload
    assert_equal 0, @user.free_movements_left
    assert_not @user.can_add_movements?(1)
  end

  test "pro no tiene tope" do
    @user.start_trial!
    assert @user.can_add_movements?(100)
  end

  test "onboarded requiere nombre y rubro" do
    assert_not @user.onboarded?
    @user.update!(occupation: "Empleado")
    assert @user.needs_onboarding?
    @user.update!(display_name: "Cristian")
    assert @user.onboarded?
    assert_not @user.needs_onboarding?
  end

  test "normalize_name acepta nombres y rechaza montos" do
    assert_equal "Cristian", User.normalize_name("cristian")
    assert_equal "Ana Maria", User.normalize_name("ana maria")
    assert_nil User.normalize_name("almohadillas 2500")
    assert_nil User.normalize_name("hamburguesa 8500")
    assert_nil User.normalize_name("Empleado")
    assert_nil User.normalize_name("/inicio")
    assert_nil User.normalize_name("hola")
  end
end
