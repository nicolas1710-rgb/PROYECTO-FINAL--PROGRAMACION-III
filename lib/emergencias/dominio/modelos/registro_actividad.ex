defmodule Emergencias.Dominio.Modelos.RegistroActividad do
  @moduledoc """
  Representa una entrada inmutable en la bitácora de auditoría del sistema.
  """

  @enforce_keys [:id, :usuario, :accion, :detalles, :fecha]
  defstruct [:id, :usuario, :accion, :detalles, :fecha]

  @type t :: %__MODULE__{
          id: String.t(),
          usuario: String.t(),
          accion: String.t(),
          detalles: String.t(),
          fecha: String.t()
        }

  @doc """
  Construir un registro de actividad para la bitácora.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       usuario: Map.fetch!(atributos, :usuario),
       accion: Map.fetch!(atributos, :accion),
       detalles: Map.fetch!(atributos, :detalles),
       fecha: Map.fetch!(atributos, :fecha)
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
