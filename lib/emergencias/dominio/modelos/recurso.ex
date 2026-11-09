defmodule Emergencias.Dominio.Modelos.Movimiento do
  @moduledoc "Registro historico inmutable de un movimiento de inventario."
  defstruct [:id, :codigo_recurso, :tipo, :cantidad, :origen, :destino, :usuario, :fecha]
end

defmodule Emergencias.Dominio.Modelos.Recurso do
  @moduledoc "Lote de suministros o recursos disponibles en una ubicacion."
  defstruct [
    :id,
    :nombre,
    :categoria,
    :unidad_medida,
    :cantidad_total,
    :cantidad_disponible,
    :ubicacion,
    cantidad_reservada: 0,
    fecha_registro: nil
  ]

  @doc "Construir un recurso asegurando que cantidad disponible inicia igual al total."
  def construir(attrs) when is_map(attrs) do
    total = Map.get(attrs, :cantidad_total, 0)
    base = %{cantidad_disponible: total, cantidad_reservada: 0, categoria: "general"}
    {:ok, struct(__MODULE__, Map.merge(base, attrs))}
  end
end
