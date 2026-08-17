require "test_helper"

class NormalizersTest < ActiveSupport::TestCase
  test "normaliza RUT con puntos, guiones y K" do
    assert_equal "673135771", Normalizers.rut("67.313.577-1")
    assert_equal "900606267", Normalizers.rut("90.060.626-7")
    assert_equal "991192917", Normalizers.rut("99119291-7")
    assert_equal "958507930", Normalizers.rut("958507930")
  end

  test "rechaza RUT inválidos" do
    assert_nil Normalizers.rut("")
    assert_nil Normalizers.rut("abc")
    assert_nil Normalizers.rut("1234567890123456")
  end

  test "parsea montos con separadores chilenos" do
    assert_equal 24_963_000.00, Normalizers.monto("24.963.000,00")
    assert_equal 61.26, Normalizers.monto("61,26")
    assert_equal 32_053_000.0, Normalizers.monto("32.053.000")
    assert_equal 4_800_000.0, Normalizers.monto("4.800.000")
  end

  test "rechaza montos inválidos" do
    assert_nil Normalizers.monto("")
    assert_nil Normalizers.monto("abc")
  end

  test "parsea fechas en tres formatos" do
    assert_equal Date.new(2025, 8, 2), Normalizers.fecha("2025-08-02")
    assert_equal Date.new(2025, 10, 1), Normalizers.fecha("01/10/2025")
    assert_equal Date.new(2025, 10, 6), Normalizers.fecha("06-10-2025")
  end

  test "rechaza fechas inválidas" do
    assert_nil Normalizers.fecha("not a date")
    assert_nil Normalizers.fecha("2025-13-99")
  end

  test "normaliza moneda" do
    assert_equal "CLP", Normalizers.moneda("$")
    assert_equal "CLP", Normalizers.moneda("clp")
    assert_equal "CLP", Normalizers.moneda("CLP")
    assert_equal "UF", Normalizers.moneda("uf")
    assert_nil Normalizers.moneda("")
  end

  test "extrae folio de una referencia" do
    assert_equal "102464", Normalizers.folio("PAGO FACTURA 102464 DISTRIBUIDORA SUR EIRL")
    assert_equal "101336", Normalizers.folio("101336")
    assert_nil Normalizers.folio("SIN DATOS")
  end

  test "fingerprint es estable y distinto" do
    a = Normalizers.fingerprint("2025-10-28", "25125000.0", "desc", "ref")
    b = Normalizers.fingerprint("2025-10-28", "25125000.0", "desc", "ref")
    c = Normalizers.fingerprint("2025-10-29", "25125000.0", "desc", "ref")
    assert_equal a, b
    assert_not_equal a, c
  end
end
