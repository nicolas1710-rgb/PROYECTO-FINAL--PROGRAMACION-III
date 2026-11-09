defmodule Emergencias.Dominio.Modelos.Albergue do
  @moduledoc "Albergue temporal para damnificados con control estricto de cupo."
  defstruct [
    :id,
    :nombre,
    :codigo_zona,
    :capacidad_maxima,
    personas_alojadas: MapSet.new(),
    recursos_asignados: %{},
    necesidades_asociadas: [],
    fecha_registro: nil
  ]

  @doc "Construir un albergue inicializando ocupantes como MapSet."
  def construir(attrs) when is_map(attrs) do
    alojadas =
      case Map.get(attrs, :personas_alojadas, MapSet.new()) do
        %MapSet{} = set -> set
        list when is_list(list) -> MapSet.new(list)
        _ -> MapSet.new()
      end

    base = %{
      personas_alojadas: alojadas,
      recursos_asignados: Map.get(attrs, :recursos_asignados, %{}),
      necesidades_asociadas: Map.get(attrs, :necesidades_asociadas, [])
    }

    {:ok, struct(__MODULE__, Map.merge(attrs, base))}
  end
end
