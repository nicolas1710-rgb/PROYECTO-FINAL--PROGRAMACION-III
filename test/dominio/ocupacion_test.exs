defmodule Emergencias.Dominio.OcupacionTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Dominio.Reglas.Ocupacion

  setup do
    {:ok, alb} =
      Albergue.construir(%{
        id: "ALB001",
        nombre: "Albergue Estadio",
        codigo_zona: "Z001",
        capacidad_maxima: 2,
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    %{albergue: alb}
  end

  test "control de cupo e ingreso de personas con MapSet", %{albergue: alb} do
    assert Ocupacion.tener_cupo?(alb)

    assert {:ok, alb1} = Ocupacion.ingresar_persona(alb, "10949001")
    assert MapSet.member?(alb1.personas_alojadas, "10949001")
    assert Ocupacion.tener_cupo?(alb1)

    # Evitar duplicados de la misma persona
    assert {:error, :persona_ya_alojada} = Ocupacion.ingresar_persona(alb1, "10949001")

    assert {:ok, alb2} = Ocupacion.ingresar_persona(alb1, "10949002")
    refute Ocupacion.tener_cupo?(alb2)

    # Intentar ingresar cuando se alcanzo la capacidad maxima
    assert {:error, :sin_cupo} = Ocupacion.ingresar_persona(alb2, "10949003")
  end

  test "retirar persona del albergue", %{albergue: alb} do
    {:ok, alb_ocupado} = Ocupacion.ingresar_persona(alb, "10949001")

    assert {:ok, alb_liberado} = Ocupacion.retirar_persona(alb_ocupado, "10949001")
    assert MapSet.size(alb_liberado.personas_alojadas) == 0

    assert {:error, :persona_no_encontrada} =
             Ocupacion.retirar_persona(alb_liberado, "99999999")
  end

  test "calcular porcentaje de ocupacion y ordenar", %{albergue: alb} do
    assert Ocupacion.calcular_porcentaje_ocupacion(alb) == 0.0

    {:ok, alb1} = Ocupacion.ingresar_persona(alb, "10949001")
    assert Ocupacion.calcular_porcentaje_ocupacion(alb1) == 50.0

    {:ok, alb2} = Ocupacion.ingresar_persona(alb1, "10949002")
    assert Ocupacion.calcular_porcentaje_ocupacion(alb2) == 100.0

    albergues_ordenados = Ocupacion.ordenar_por_ocupacion([alb, alb2, alb1])
    assert Enum.map(albergues_ordenados, & &1.personas_alojadas |> MapSet.size()) == [2, 1, 0]
  end
end
