defmodule Emergencias.Dominio.Modelos.Persona do
  @moduledoc """
  Representa a una persona afectada por la emergencia, rastreando su estado y ubicación.
  """

  @enforce_keys [:id, :documento, :nombre_completo, :estado, :fecha_reporte]
  defstruct [
    :id,
    :documento,
    :nombre_completo,
    :estado,
    :fecha_reporte,
    ubicacion_actual: "desconocida",
    codigo_albergue: nil,
    historial: []
  ]

  @type estado ::
          :sin_informacion
          | :reportada
          | :localizada
          | :trasladada
          | :en_albergue
          | :reunificada

  @type evento_historial :: %{
          fecha: String.t(),
          estado_anterior: estado(),
          estado_nuevo: estado(),
          usuario: String.t(),
          detalles: String.t()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          documento: String.t(),
          nombre_completo: String.t(),
          estado: estado(),
          fecha_reporte: String.t(),
          ubicacion_actual: String.t(),
          codigo_albergue: String.t() | nil,
          historial: [evento_historial()]
        }

  @doc """
  Construir un registro de persona a partir de un mapa de atributos.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       documento: Map.fetch!(atributos, :documento),
       nombre_completo: Map.fetch!(atributos, :nombre_completo),
       estado: Map.fetch!(atributos, :estado),
       fecha_reporte: Map.fetch!(atributos, :fecha_reporte),
       ubicacion_actual: Map.get(atributos, :ubicacion_actual, "desconocida"),
       codigo_albergue: Map.get(atributos, :codigo_albergue, nil),
       historial: Map.get(atributos, :historial, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
