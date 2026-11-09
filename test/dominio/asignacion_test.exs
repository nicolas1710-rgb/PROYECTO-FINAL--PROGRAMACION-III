defmodule Emergencias.Dominio.AsignacionTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Modelos.{Necesidad, Recurso}
  alias Emergencias.Dominio.Reglas.Asignacion

  setup do
    rec = %Recurso{id: "R001", nombre: "agua", categoria: "hidratacion", unidad_medida: "litros", cantidad_total: 50, cantidad_disponible: 50, cantidad_reservada: 0, ubicacion: "Z001"}
    nec = %Necesidad{id: "N001", codigo_zona: "Z001", tipo_recurso: "agua", descripcion: "Agua potable", cantidad_solicitada: 30, cantidad_asignada: 0, prioridad: :critica, estado: :pendiente, responsable: "Pedro", historial: []}
    estado = %{recursos: %{"R001" => rec}, necesidades: %{"N001" => nec}, movimientos: []}
    {:ok, estado: estado}
  end

  test "asigna recurso exitosamente y actualiza necesidad a atendida", %{estado: est} do
    {:ok, nuevo, {rec_act, nec_act, mov}} = Asignacion.asignar(est, "R001", "N001", 30, "Laura", "2026-11-09T00:00:00Z")
    assert rec_act.cantidad_disponible == 20
    assert rec_act.cantidad_reservada == 30
    assert nec_act.cantidad_asignada == 30
    assert nec_act.estado == :atendida
    assert mov.tipo == :asignacion
    assert length(nuevo.movimientos) == 1
  end

  test "asigna parcialmente y pasa necesidad a asignada", %{estado: est} do
    {:ok, _nuevo, {rec_act, nec_act, _mov}} = Asignacion.asignar(est, "R001", "N001", 10, "Laura", "2026-11-09T00:00:00Z")
    assert rec_act.cantidad_disponible == 40
    assert nec_act.cantidad_asignada == 10
    assert nec_act.estado == :asignada
  end

  test "rechaza si cantidad excede el saldo pendiente", %{estado: est} do
    assert {:error, :cantidad_excede_necesidad} = Asignacion.asignar(est, "R001", "N001", 35, "Laura", "2026-11-09T00:00:00Z")
  end

  test "rechaza si el stock es insuficiente", %{estado: est} do
    rec_escaso = put_in(est.recursos["R001"].cantidad_disponible, 5)
    assert {:error, :stock_insuficiente} = Asignacion.asignar(rec_escaso, "R001", "N001", 20, "Laura", "2026-11-09T00:00:00Z")
  end

  test "rechaza si la necesidad ya esta atendida o cerrada", %{estado: est} do
    nec_cerrada = put_in(est.necesidades["N001"].estado, :atendida)
    assert {:error, :necesidad_ya_cerrada} = Asignacion.asignar(nec_cerrada, "R001", "N001", 10, "Laura", "2026-11-09T00:00:00Z")
  end

  test "rechaza recurso incompatible o inexistente", %{estado: est} do
    assert {:error, :recurso_no_encontrado} = Asignacion.asignar(est, "R999", "N001", 10, "Laura", "2026-11-09T00:00:00Z")
    rec_distinto = put_in(est.recursos["R001"].nombre, "frazadas")
    assert {:error, :tipo_recurso_incompatible} = Asignacion.asignar(rec_distinto, "R001", "N001", 10, "Laura", "2026-11-09T00:00:00Z")
  end
end
