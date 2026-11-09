defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoRecursos do
  @moduledoc """
  Contrato del caso de uso de administración de suministros e inventario.
  """

  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Recurso}

  @callback registrar_recurso(map(), struct(), keyword()) :: {:ok, Recurso.t()} | {:error, atom()}
  @callback listar_recursos(keyword(), struct()) :: {:ok, list(Recurso.t())} | {:error, atom()}
  @callback asignar_recurso(String.t(), String.t(), pos_integer(), struct(), keyword()) ::
              {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}
  @callback transferir_recurso(String.t(), String.t(), pos_integer(), struct(), keyword()) ::
              {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}
end
