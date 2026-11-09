defmodule Emergencias.Dominio.Modelos.Persona do
  @moduledoc "Representa a una persona damnificada, reportada o localizada."
  defstruct [
    :documento,
    :nombre,
    :edad,
    :zona,
    estado: :reportada,
    codigo_albergue: nil,
    fecha_registro: nil,
    historial: []
  ]

  @doc "Construir una persona con estado inicial reportada."
  def construir(attrs) when is_map(attrs) do
    base = %{estado: :reportada, codigo_albergue: nil, historial: []}
    {:ok, struct(__MODULE__, Map.merge(base, attrs))}
  end
end
