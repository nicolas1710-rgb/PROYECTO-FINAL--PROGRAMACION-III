defmodule Emergencias.Dominio.Modelos.PuntoAtencion do
  @moduledoc """
  Representa la unidad básica de atención en un sector de emergencia.
  """

  @enforce_keys [:id, :nombre, :personas_afectadas]
  defstruct [:id, :nombre, :personas_afectadas, recursos_disponibles: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          personas_afectadas: non_neg_integer(),
          recursos_disponibles: map()
        }

  @doc """
  Construir un punto de atención con sus atributos básicos.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: Map.fetch!(atributos, :nombre),
       personas_afectadas: Map.get(atributos, :personas_afectadas, 0),
       recursos_disponibles: Map.get(atributos, :recursos_disponibles, %{})
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
