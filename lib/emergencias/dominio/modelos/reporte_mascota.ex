defmodule Emergencias.Dominio.Modelos.ReporteMascota do
  @moduledoc """
  Representa el reporte de una mascota extraviada o encontrada tras la emergencia.
  """

  @enforce_keys [
    :id,
    :tipo_reporte,
    :especie,
    :color,
    :tamano,
    :codigo_zona,
    :estado,
    :usuario_reporta,
    :fecha_registro
  ]

  defstruct [
    :id,
    :tipo_reporte,
    :especie,
    :color,
    :tamano,
    :codigo_zona,
    :estado,
    :usuario_reporta,
    :fecha_registro,
    nombre: "",
    caracteristicas: [],
    historial: []
  ]

  @type tipo_reporte :: :perdida | :encontrada
  @type tamano :: :pequeno | :mediano | :grande
  @type estado :: :activa | :posible_coincidencia | :resuelta

  @type evento_historial :: %{
          fecha: String.t(),
          estado_anterior: estado(),
          estado_nuevo: estado(),
          usuario: String.t(),
          detalles: String.t()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          tipo_reporte: tipo_reporte(),
          especie: String.t(),
          nombre: String.t(),
          color: String.t(),
          tamano: tamano(),
          codigo_zona: String.t(),
          caracteristicas: [String.t()],
          estado: estado(),
          usuario_reporta: String.t(),
          fecha_registro: String.t(),
          historial: [evento_historial()]
        }

  @doc """
  Construir un reporte de mascota a partir de un mapa de atributos.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       tipo_reporte: Map.fetch!(atributos, :tipo_reporte),
       especie: Map.fetch!(atributos, :especie),
       nombre: Map.get(atributos, :nombre, ""),
       color: Map.fetch!(atributos, :color),
       tamano: Map.fetch!(atributos, :tamano),
       codigo_zona: Map.fetch!(atributos, :codigo_zona),
       caracteristicas: Map.get(atributos, :caracteristicas, []),
       estado: Map.fetch!(atributos, :estado),
       usuario_reporta: Map.fetch!(atributos, :usuario_reporta),
       fecha_registro: Map.fetch!(atributos, :fecha_registro),
       historial: Map.get(atributos, :historial, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
