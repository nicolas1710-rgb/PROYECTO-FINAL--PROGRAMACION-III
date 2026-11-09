defmodule Emergencias.Dominio.Reglas.Ocupacion do
  @moduledoc """
  Reglas puras de administración de capacidad, aforo y ocupación de albergues.
  Utiliza MapSet para asegurar que una persona no ingrese por duplicado y validar cupo.
  """

  alias Emergencias.Dominio.Modelos.Albergue

  @doc """
  Verificar si el albergue cuenta con cupos disponibles para recibir más personas.
  """
  @spec tener_cupo?(Albergue.t()) :: boolean()
  def tener_cupo?(%Albergue{} = albergue) do
    MapSet.size(albergue.personas_alojadas) < albergue.capacidad_maxima
  end

  @doc """
  Ingresar una persona al albergue mediante su documento de identificación.
  Retorna error si no hay cupo o si la persona ya se encuentra registrada en él.
  """
  @spec ingresar_persona(Albergue.t(), String.t()) ::
          {:ok, Albergue.t()} | {:error, :sin_cupo | :persona_ya_alojada}
  def ingresar_persona(%Albergue{} = albergue, documento) when is_binary(documento) do
    cond do
      MapSet.member?(albergue.personas_alojadas, documento) ->
        {:error, :persona_ya_alojada}

      not tener_cupo?(albergue) ->
        {:error, :sin_cupo}

      true ->
        alojadas = MapSet.put(albergue.personas_alojadas, documento)
        {:ok, %{albergue | personas_alojadas: alojadas}}
    end
  end

  @doc """
  Retirar a una persona del albergue cuando egresa o es reunificada.
  """
  @spec retirar_persona(Albergue.t(), String.t()) ::
          {:ok, Albergue.t()} | {:error, :persona_no_encontrada}
  def retirar_persona(%Albergue{} = albergue, documento) when is_binary(documento) do
    if MapSet.member?(albergue.personas_alojadas, documento) do
      alojadas = MapSet.delete(albergue.personas_alojadas, documento)
      {:ok, %{albergue | personas_alojadas: alojadas}}
    else
      {:error, :persona_no_encontrada}
    end
  end

  @doc """
  Calcular el porcentaje de ocupación actual de un albergue (de 0.0 a 100.0).
  """
  @spec calcular_porcentaje_ocupacion(Albergue.t()) :: float()
  def calcular_porcentaje_ocupacion(%Albergue{capacidad_maxima: 0}), do: 100.0

  def calcular_porcentaje_ocupacion(%Albergue{} = albergue) do
    ocupados = MapSet.size(albergue.personas_alojadas)
    Float.round(ocupados / albergue.capacidad_maxima * 100, 2)
  end

  @doc """
  Ordenar una lista de albergues de mayor a menor porcentaje de ocupación.
  """
  @spec ordenar_por_ocupacion(list(Albergue.t())) :: list(Albergue.t())
  def ordenar_por_ocupacion(albergues) when is_list(albergues) do
    Enum.sort_by(albergues, &calcular_porcentaje_ocupacion/1, :desc)
  end
end
