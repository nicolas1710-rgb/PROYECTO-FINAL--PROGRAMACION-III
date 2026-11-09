defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaRecursos do
  @moduledoc """
  Puerto de salida para el inventario de recursos, movimientos y transferencias entre centros.
  """

  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Recurso}

  @doc "Registrar un nuevo lote de recursos en inventario."
  @callback registrar(map(), String.t()) :: {:ok, Recurso.t()} | {:error, atom()}

  @doc "Consultar un recurso por su identificador único."
  @callback consultar(String.t()) :: {:ok, Recurso.t()} | {:error, atom()}

  @doc "Descontar existencias y generar movimiento de asignación hacia una necesidad."
  @callback asignar(String.t(), String.t(), pos_integer(), String.t()) ::
              {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}

  @doc "Transferir cantidades entre recursos o centros de apoyo territorial."
  @callback transferir(String.t(), String.t(), pos_integer(), String.t()) ::
              {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}

  @doc "Listar recursos en inventario aplicando filtros opcionales."
  @callback listar(keyword()) :: {:ok, list(Recurso.t())}

  @doc "Listar el histórico de movimientos de inventario."
  @callback listar_movimientos() :: {:ok, list(MovimientoInventario.t())}
end
