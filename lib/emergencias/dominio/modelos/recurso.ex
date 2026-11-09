defmodule Emergencias.Dominio.Modelos.Recurso do
  @moduledoc """
  Representa un lote de suministros o recursos disponibles en un centro de apoyo o zona.
  Incluye identificación propia, nombre, categoría, unidad y centro de ubicación.
  """

  @enforce_keys [
    :id,
    :nombre,
    :tipo,
    :unidad_medida,
    :cantidad_total,
    :cantidad_disponible,
    :codigo_zona,
    :fecha_registro
  ]

  defstruct [
    :id,
    :nombre,
    :tipo,
    :unidad_medida,
    :cantidad_total,
    :cantidad_disponible,
    :codigo_zona,
    :fecha_registro,
    cantidad_reservada: 0
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          tipo: String.t(),
          unidad_medida: String.t(),
          cantidad_total: non_neg_integer(),
          cantidad_disponible: non_neg_integer(),
          cantidad_reservada: non_neg_integer(),
          codigo_zona: String.t(),
          fecha_registro: String.t()
        }

  @doc """
  Construir una instancia de recurso a partir de un mapa de atributos.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    total = Map.fetch!(atributos, :cantidad_total)
    disponible = Map.get(atributos, :cantidad_disponible, total)
    reservada = Map.get(atributos, :cantidad_reservada, 0)
    tipo = Map.fetch!(atributos, :tipo)
    nombre = Map.get(atributos, :nombre, tipo)

    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: nombre,
       tipo: tipo,
       unidad_medida: Map.fetch!(atributos, :unidad_medida),
       cantidad_total: total,
       cantidad_disponible: disponible,
       cantidad_reservada: reservada,
       codigo_zona: Map.fetch!(atributos, :codigo_zona),
       fecha_registro: Map.fetch!(atributos, :fecha_registro)
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
