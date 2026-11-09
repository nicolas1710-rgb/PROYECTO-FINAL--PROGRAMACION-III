defmodule Emergencias.Dominio.Modelos.Necesidad do
  @moduledoc """
  Representa una necesidad humanitaria reportada en una zona afectada.
  Rastrea cantidad solicitada, cantidad asignada y descripción de la urgencia.
  """

  @enforce_keys [
    :id,
    :codigo_zona,
    :tipo_recurso,
    :cantidad_solicitada,
    :prioridad,
    :estado,
    :fecha_registro,
    :usuario_reporta
  ]

  defstruct [
    :id,
    :codigo_zona,
    :tipo_recurso,
    :cantidad_solicitada,
    :prioridad,
    :estado,
    :fecha_registro,
    :usuario_reporta,
    descripcion: "",
    cantidad_asignada: 0,
    historial: []
  ]

  @type estado :: :pendiente | :asignada | :en_atencion | :atendida | :cancelada
  @type prioridad :: :critica | :alta | :media | :baja

  @type evento_historial :: %{
          fecha: String.t(),
          estado_anterior: estado(),
          estado_nuevo: estado(),
          usuario: String.t()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          codigo_zona: String.t(),
          tipo_recurso: String.t(),
          cantidad_solicitada: pos_integer(),
          cantidad_asignada: non_neg_integer(),
          prioridad: prioridad(),
          estado: estado(),
          fecha_registro: String.t(),
          usuario_reporta: String.t(),
          descripcion: String.t(),
          historial: [evento_historial()]
        }

  @doc """
  Construir una necesidad a partir de un mapa de atributos.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       codigo_zona: Map.fetch!(atributos, :codigo_zona),
       tipo_recurso: Map.fetch!(atributos, :tipo_recurso),
       cantidad_solicitada: Map.fetch!(atributos, :cantidad_solicitada),
       cantidad_asignada: Map.get(atributos, :cantidad_asignada, 0),
       prioridad: Map.fetch!(atributos, :prioridad),
       estado: Map.fetch!(atributos, :estado),
       fecha_registro: Map.fetch!(atributos, :fecha_registro),
       usuario_reporta: Map.fetch!(atributos, :usuario_reporta),
       descripcion: Map.get(atributos, :descripcion, ""),
       historial: Map.get(atributos, :historial, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
