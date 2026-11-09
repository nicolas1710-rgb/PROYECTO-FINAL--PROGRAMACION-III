defmodule Emergencias.Dominio.InventarioTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.Recurso
  alias Emergencias.Dominio.Reglas.Inventario

  setup do
    {:ok, r1} =
      Recurso.construir(%{
        id: "R001",
        tipo: "agua",
        unidad_medida: "litros",
        cantidad_total: 50,
        cantidad_disponible: 50,
        codigo_zona: "Z001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, r2} =
      Recurso.construir(%{
        id: "R002",
        tipo: "agua",
        unidad_medida: "litros",
        cantidad_total: 20,
        cantidad_disponible: 20,
        codigo_zona: "Z002",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, r_meds} =
      Recurso.construir(%{
        id: "R003",
        tipo: "medicamentos",
        unidad_medida: "cajas",
        cantidad_total: 10,
        cantidad_disponible: 10,
        codigo_zona: "Z001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    %{r1: r1, r2: r2, r_meds: r_meds}
  end

  test "descontar con existencias y con insuficiencia", %{r1: r1} do
    assert {:ok, {actualizado, mov}} =
             Inventario.descontar(
               r1,
               30,
               "MOV001",
               "Punto Salud",
               "coordinador1",
               "2026-03-01T10:10:00Z"
             )

    assert actualizado.cantidad_disponible == 20
    assert actualizado.cantidad_total == 20
    assert mov.cantidad == 30
    assert mov.tipo_movimiento == :salida

    # Intentar descontar 25 sobre los 20 restantes
    assert {:error, :cantidad_insuficiente} =
             Inventario.descontar(
               actualizado,
               25,
               "MOV002",
               "Otro Punto",
               "coordinador1",
               "2026-03-01T10:15:00Z"
             )
  end

  test "asignar reserva cantidad sin reducir total", %{r1: r1} do
    assert {:ok, {actualizado, mov}} =
             Inventario.asignar(
               r1,
               25,
               "MOV001",
               "N001",
               "coordinador1",
               "2026-03-01T10:10:00Z"
             )

    assert actualizado.cantidad_disponible == 25
    assert actualizado.cantidad_reservada == 25
    assert actualizado.cantidad_total == 50
    assert mov.tipo_movimiento == :asignacion
  end

  test "transferir entre recursos con exito y atomicidad pura", %{r1: r1, r2: r2} do
    assert {:ok, {nuevo_r1, nuevo_r2, mov1, mov2}} =
             Inventario.transferir(
               r1,
               r2,
               20,
               {"MOV001", "MOV002"},
               "coordinador1",
               "2026-03-01T10:20:00Z"
             )

    assert nuevo_r1.cantidad_disponible == 30
    assert nuevo_r2.cantidad_disponible == 40
    assert mov1.tipo_movimiento == :transferencia_origen
    assert mov2.tipo_movimiento == :transferencia_destino

    # Transferencia con saldo insuficiente
    assert {:error, :cantidad_insuficiente} =
             Inventario.transferir(
               nuevo_r1,
               nuevo_r2,
               50,
               {"MOV003", "MOV004"},
               "coordinador1",
               "2026-03-01T10:25:00Z"
             )
  end

  test "rechazar transferencia entre recursos de tipos distintos", %{r1: r1, r_meds: meds} do
    assert {:error, :tipos_incompatibles} =
             Inventario.transferir(
               r1,
               meds,
               5,
               {"MOV001", "MOV002"},
               "coordinador1",
               "2026-03-01T10:30:00Z"
             )
  end
end
