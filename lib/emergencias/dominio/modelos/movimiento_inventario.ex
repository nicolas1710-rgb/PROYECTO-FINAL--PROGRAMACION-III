defmodule Emergencias.Dominio.Modelos.MovimientoInventario do
  @moduledoc """
  Registra un movimiento histórico de entrada, salida, asignación o transferencia.
  """

  @enforce_keys [
    :id,
    :codigo_recurso,
    :tipo_movimiento,
    :cantidad,
    :origen,
    :destino,
    :fecha,
    :usuario_responsable
  ]

  defstruct [
    :id,
    :codigo_recurso,
    :tipo_movimiento,
    :cantidad,
    :origen,
    :destino,
    :fecha,
    :usuario_responsable
  ]

  @type tipo_movimiento ::
          :entrada
          | :salida
          | :asignacion
          | :transferencia_origen
          | :transferencia_destino

  @type t :: %__MODULE__{
          id: String.t(),
          codigo_recurso: String.t(),
          tipo_movimiento: tipo_movimiento(),
          cantidad: pos_integer(),
          origen: String.t(),
          destino: String.t(),
          fecha: String.t(),
          usuario_responsable: String.t()
        }

  @doc """
  Construir un registro inmutable de movimiento de inventario.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       codigo_recurso: Map.fetch!(atributos, :codigo_recurso),
       tipo_movimiento: Map.fetch!(atributos, :tipo_movimiento),
       cantidad: Map.fetch!(atributos, :cantidad),
       origen: Map.fetch!(atributos, :origen),
       destino: Map.fetch!(atributos, :destino),
       fecha: Map.fetch!(atributos, :fecha),
       usuario_responsable: Map.fetch!(atributos, :usuario_responsable)
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
