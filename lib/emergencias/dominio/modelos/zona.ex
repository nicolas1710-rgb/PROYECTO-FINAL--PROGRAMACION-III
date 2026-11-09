defmodule Emergencias.Dominio.Modelos.Zona do
  @moduledoc """
  Representa una zona geográfica afectada por la emergencia.
  Contiene una jerarquía de sectores y puntos de atención.
  """

  alias Emergencias.Dominio.Modelos.Sector

  @enforce_keys [:id, :nombre, :nivel_gravedad, :fecha_registro]
  defstruct [:id, :nombre, :nivel_gravedad, :fecha_registro, sectores: []]

  @type nivel_gravedad :: :critico | :alto | :medio | :bajo

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          nivel_gravedad: nivel_gravedad(),
          fecha_registro: String.t(),
          sectores: [Sector.t()]
        }

  @doc """
  Construir una zona con su jerarquía de sectores.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: Map.fetch!(atributos, :nombre),
       nivel_gravedad: Map.fetch!(atributos, :nivel_gravedad),
       fecha_registro: Map.fetch!(atributos, :fecha_registro),
       sectores: Map.get(atributos, :sectores, [])
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
