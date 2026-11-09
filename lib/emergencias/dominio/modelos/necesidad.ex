defmodule Emergencias.Dominio.Modelos.Necesidad do
  @moduledoc "Representa una necesidad humanitaria reportada en una zona."
  defstruct [
    :id,
    :codigo_zona,
    :tipo_recurso,
    :descripcion,
    :cantidad_solicitada,
    :responsable,
    prioridad: :media,
    estado: :pendiente,
    cantidad_asignada: 0,
    fecha_registro: nil,
    historial: []
  ]

  @doc "Construir una nueva necesidad en estado inicial pendiente."
  def construir(attrs) when is_map(attrs) do
    base = %{cantidad_asignada: 0, estado: :pendiente, historial: []}
    {:ok, struct(__MODULE__, Map.merge(base, attrs))}
  end
end
