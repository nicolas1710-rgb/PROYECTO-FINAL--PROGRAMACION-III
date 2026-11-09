defmodule Emergencias.Dominio.Modelos.Mascota do
  @moduledoc "Reporte de mascota extraviada o hallada durante la emergencia."
  defstruct [
    :id,
    :tipo_reporte,
    :especie,
    :nombre,
    :color,
    :tamano,
    :codigo_zona,
    :usuario,
    estado: :activa,
    caracteristicas: [],
    fecha_registro: nil,
    historial: []
  ]

  @doc "Construir un reporte de mascota en estado inicial activo."
  def construir(attrs) when is_map(attrs) do
    base = %{estado: :activa, caracteristicas: [], historial: []}
    {:ok, struct(__MODULE__, Map.merge(base, attrs))}
  end
end
