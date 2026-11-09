defmodule Emergencias.Dominio.Modelos.Sector do
  @moduledoc """
  Representa una subdivisión territorial de una zona que agrupa puntos de atención.
  """

  alias Emergencias.Dominio.Modelos.PuntoAtencion

  @enforce_keys [:id, :nombre]
  defstruct [:id, :nombre, puntos_atencion: []]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          puntos_atencion: [PuntoAtencion.t()]
        }

  @doc """
  Construir un sector con sus puntos de atención.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: Map.fetch!(atributos, :nombre),
       puntos_atencion: Map.get(atributos, :puntos_atencion, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
