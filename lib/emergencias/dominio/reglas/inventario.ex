defmodule Emergencias.Dominio.Reglas.Inventario do
  @moduledoc """
  Reglas puras de gestión de inventario, stock y trazabilidad de movimientos.
  Garantiza que ningún saldo resulte negativo y genera auditoría de cada transacción.
  """

  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Recurso}

  @doc """
  Descontar una cantidad del inventario disponible de un recurso.
  Retorna `{:ok, {recurso_actualizado, movimiento}}` o `{:error, :cantidad_insuficiente}`.
  """
  @spec descontar(Recurso.t(), pos_integer(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, :cantidad_insuficiente}
  def descontar(%Recurso{} = recurso, cantidad, id_movimiento, destino, usuario, fecha)
      when is_integer(cantidad) and cantidad > 0 do
    if recurso.cantidad_disponible >= cantidad do
      nuevo_recurso = %{
        recurso
        | cantidad_disponible: recurso.cantidad_disponible - cantidad,
          cantidad_total: recurso.cantidad_total - cantidad
      }

      {:ok, movimiento} =
        MovimientoInventario.construir(%{
          id: id_movimiento,
          codigo_recurso: recurso.id,
          tipo_movimiento: :salida,
          cantidad: cantidad,
          origen: recurso.codigo_zona,
          destino: destino,
          fecha: fecha,
          usuario_responsable: usuario
        })

      {:ok, {nuevo_recurso, movimiento}}
    else
      {:error, :cantidad_insuficiente}
    end
  end

  @doc """
  Asignar una cantidad de un recurso para atender una necesidad específica.
  Reduce la cantidad disponible e incrementa la reservada o entregada.
  """
  @spec asignar(Recurso.t(), pos_integer(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, :cantidad_insuficiente}
  def asignar(%Recurso{} = recurso, cantidad, id_movimiento, id_necesidad, usuario, fecha)
      when is_integer(cantidad) and cantidad > 0 do
    if recurso.cantidad_disponible >= cantidad do
      nuevo_recurso = %{
        recurso
        | cantidad_disponible: recurso.cantidad_disponible - cantidad,
          cantidad_reservada: recurso.cantidad_reservada + cantidad
      }

      {:ok, movimiento} =
        MovimientoInventario.construir(%{
          id: id_movimiento,
          codigo_recurso: recurso.id,
          tipo_movimiento: :asignacion,
          cantidad: cantidad,
          origen: recurso.codigo_zona,
          destino: "Necesidad:#{id_necesidad}",
          fecha: fecha,
          usuario_responsable: usuario
        })

      {:ok, {nuevo_recurso, movimiento}}
    else
      {:error, :cantidad_insuficiente}
    end
  end

  @doc """
  Agregar cantidad adicional a las existencias totales y disponibles de un recurso.
  """
  @spec agregar(Recurso.t(), pos_integer(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}}
  def agregar(%Recurso{} = recurso, cantidad, id_movimiento, origen, usuario, fecha)
      when is_integer(cantidad) and cantidad > 0 do
    nuevo_recurso = %{
      recurso
      | cantidad_disponible: recurso.cantidad_disponible + cantidad,
        cantidad_total: recurso.cantidad_total + cantidad
    }

    {:ok, movimiento} =
      MovimientoInventario.construir(%{
        id: id_movimiento,
        codigo_recurso: recurso.id,
        tipo_movimiento: :entrada,
        cantidad: cantidad,
        origen: origen,
        destino: recurso.codigo_zona,
        fecha: fecha,
        usuario_responsable: usuario
      })

    {:ok, {nuevo_recurso, movimiento}}
  end

  @doc """
  Transferir existencias entre un recurso de origen y un recurso de destino.
  Garantiza atomicidad pura: si el origen no tiene saldo, ambos quedan intactos.
  """
  @spec transferir(
          Recurso.t(),
          Recurso.t(),
          pos_integer(),
          {String.t(), String.t()},
          String.t(),
          String.t()
        ) ::
          {:ok, {Recurso.t(), Recurso.t(), MovimientoInventario.t(), MovimientoInventario.t()}}
          | {:error, :cantidad_insuficiente | :tipos_incompatibles}
  def transferir(origen, destino, cantidad, ids_movimiento, usuario, fecha)

  def transferir(%Recurso{tipo: t1}, %Recurso{tipo: t2}, _cant, _ids, _u, _f) when t1 != t2 do
    {:error, :tipos_incompatibles}
  end

  def transferir(%Recurso{} = origen, %Recurso{} = destino, cantidad, {id_m1, id_m2}, usuario, fecha)
      when is_integer(cantidad) and cantidad > 0 do
    if origen.cantidad_disponible >= cantidad do
      nuevo_origen = %{
        origen
        | cantidad_disponible: origen.cantidad_disponible - cantidad,
          cantidad_total: origen.cantidad_total - cantidad
      }

      nuevo_destino = %{
        destino
        | cantidad_disponible: destino.cantidad_disponible + cantidad,
          cantidad_total: destino.cantidad_total + cantidad
      }

      {:ok, mov_origen} =
        MovimientoInventario.construir(%{
          id: id_m1,
          codigo_recurso: origen.id,
          tipo_movimiento: :transferencia_origen,
          cantidad: cantidad,
          origen: origen.codigo_zona,
          destino: destino.codigo_zona,
          fecha: fecha,
          usuario_responsable: usuario
        })

      {:ok, mov_destino} =
        MovimientoInventario.construir(%{
          id: id_m2,
          codigo_recurso: destino.id,
          tipo_movimiento: :transferencia_destino,
          cantidad: cantidad,
          origen: origen.codigo_zona,
          destino: destino.codigo_zona,
          fecha: fecha,
          usuario_responsable: usuario
        })

      {:ok, {nuevo_origen, nuevo_destino, mov_origen, mov_destino}}
    else
      {:error, :cantidad_insuficiente}
    end
  end
end
