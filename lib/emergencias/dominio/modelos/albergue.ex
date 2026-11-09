defmodule Emergencias.Dominio.Modelos.Albergue do
  @moduledoc """
  Representa un albergue temporal para personas damnificadas.
  Asocia ocupantes únicos mediante MapSet, así como suministros asignados y necesidades vinculadas.
  """

  @enforce_keys [:id, :nombre, :codigo_zona, :capacidad_maxima, :fecha_registro]
  defstruct [
    :id,
    :nombre,
    :codigo_zona,
    :capacidad_maxima,
    :fecha_registro,
    personas_alojadas: MapSet.new(),
    recursos_asignados: %{},
    necesidades_asociadas: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          codigo_zona: String.t(),
          capacidad_maxima: pos_integer(),
          fecha_registro: String.t(),
          personas_alojadas: MapSet.t(String.t()),
          recursos_asignados: map(),
          necesidades_asociadas: list(String.t())
        }

  @doc """
  Construir un albergue con capacidad, ocupantes y suministros asociados.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    personas =
      case Map.get(atributos, :personas_alojadas, MapSet.new()) do
        %MapSet{} = conjunto -> conjunto
        lista when is_list(lista) -> MapSet.new(lista)
      end

    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: Map.fetch!(atributos, :nombre),
       codigo_zona: Map.fetch!(atributos, :codigo_zona),
       capacidad_maxima: Map.fetch!(atributos, :capacidad_maxima),
       fecha_registro: Map.fetch!(atributos, :fecha_registro),
       personas_alojadas: personas,
       recursos_asignados: Map.get(atributos, :recursos_asignados, %{}),
       necesidades_asociadas: Map.get(atributos, :necesidades_asociadas, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
