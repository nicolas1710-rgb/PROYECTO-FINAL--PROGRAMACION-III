defmodule Emergencias.Aplicacion.AsignacionRecursosNecesidadesTest do
  @moduledoc """
  Pruebas de verificación de la vinculación transaccional entre recursos y necesidades humanitarias.
  Verifica que una necesidad inexistente, cerrada o sobreasignada impida el descuento de inventario.
  """

  use ExUnit.Case, async: false

  alias Emergencias.Aplicacion.CasosUso.{GestionarNecesidades, GestionarRecursos}
  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Soporte.RepositorioMemoria

  setup do
    RepositorioMemoria.limpiar()

    {:ok, coord} =
      Usuario.construir(%{
        id: "U002",
        nombre: "Laura",
        rol: :coordinador,
        clave_hash: "hash_coord",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, vol} =
      Usuario.construir(%{
        id: "U003",
        nombre: "Carlos",
        rol: :voluntario,
        clave_hash: "hash_vol",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    opts = [repositorio: RepositorioMemoria]

    # Registrar lote de 50 litros de agua en Z001
    params_rec = %{
      tipo: "agua",
      unidad_medida: "litros",
      cantidad_total: 50,
      codigo_zona: "Z001"
    }
    {:ok, rec} = GestionarRecursos.registrar_recurso(params_rec, vol, opts)

    # Registrar necesidad de 30 litros de agua en Z001
    params_nec = %{
      codigo_zona: "Z001",
      tipo_recurso: "agua",
      cantidad_solicitada: 30,
      prioridad: :critica
    }
    {:ok, nec} = GestionarNecesidades.registrar_necesidad(params_nec, coord, opts)

    %{coord: coord, vol: vol, rec: rec, nec: nec, opts: opts}
  end

  test "asignar a una necesidad inexistente falla y no descuenta inventario", %{
    coord: coord,
    rec: rec,
    opts: opts
  } do
    assert {:error, :necesidad_no_encontrada} =
             GestionarRecursos.asignar_recurso(rec.id, "N999", 10, coord, opts)

    {:ok, [r_actual]} = GestionarRecursos.listar_recursos([], coord, opts)
    assert r_actual.cantidad_disponible == 50
  end

  test "asignar una cantidad mayor a la solicitada falla y no descuenta inventario", %{
    coord: coord,
    rec: rec,
    nec: nec,
    opts: opts
  } do
    # La necesidad solicita 30, intentar asignar 45
    assert {:error, :cantidad_excede_necesidad} =
             GestionarRecursos.asignar_recurso(rec.id, nec.id, 45, coord, opts)

    {:ok, [r_actual]} = GestionarRecursos.listar_recursos([], coord, opts)
    assert r_actual.cantidad_disponible == 50
  end

  test "asignar a una necesidad cancelada falla y no descuenta inventario", %{
    coord: coord,
    rec: rec,
    nec: nec,
    opts: opts
  } do
    assert {:ok, nec_cancelada} =
             GestionarNecesidades.actualizar_necesidad(nec.id, :cancelada, coord, opts)
    assert nec_cancelada.estado == :cancelada

    assert {:error, :necesidad_cancelada} =
             GestionarRecursos.asignar_recurso(rec.id, nec.id, 10, coord, opts)

    {:ok, [r_actual]} = GestionarRecursos.listar_recursos([], coord, opts)
    assert r_actual.cantidad_disponible == 50
  end

  test "asignacion parcial actualiza cantidad_asignada y estado :asignada", %{
    coord: coord,
    rec: rec,
    nec: nec,
    opts: opts
  } do
    assert {:ok, {r_act, _mov}} =
             GestionarRecursos.asignar_recurso(rec.id, nec.id, 5, coord, opts)

    assert r_act.cantidad_disponible == 45

    {:ok, nec_actualizada} = GestionarNecesidades.consultar_necesidad(nec.id, coord, opts)
    assert nec_actualizada.cantidad_asignada == 5
    assert nec_actualizada.estado == :asignada
  end

  test "asignacion total completa la necesidad y transita a :atendida", %{
    coord: coord,
    rec: rec,
    nec: nec,
    opts: opts
  } do
    assert {:ok, {r_act, _mov}} =
             GestionarRecursos.asignar_recurso(rec.id, nec.id, 30, coord, opts)

    assert r_act.cantidad_disponible == 20

    {:ok, nec_actualizada} = GestionarNecesidades.consultar_necesidad(nec.id, coord, opts)
    assert nec_actualizada.cantidad_asignada == 30
    assert nec_actualizada.estado == :atendida

    # Intentar asignar nuevamente a necesidad ya atendida falla
    assert {:error, :necesidad_ya_atendida} =
             GestionarRecursos.asignar_recurso(rec.id, nec.id, 5, coord, opts)
  end

  test "tipo de recurso incompatible es rechazado", %{coord: coord, nec: nec, vol: vol, opts: opts} do
    # Registrar frazadas
    params_frazadas = %{
      tipo: "frazadas",
      unidad_medida: "unidades",
      cantidad_total: 20,
      codigo_zona: "Z001"
    }
    {:ok, r_frazadas} = GestionarRecursos.registrar_recurso(params_frazadas, vol, opts)

    assert {:error, :tipo_recurso_incompatible} =
             GestionarRecursos.asignar_recurso(r_frazadas.id, nec.id, 10, coord, opts)
  end
end
