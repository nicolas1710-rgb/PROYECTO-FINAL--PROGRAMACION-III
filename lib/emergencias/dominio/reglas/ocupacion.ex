defmodule Emergencias.Dominio.Reglas.Ocupacion do
  @moduledoc "Reglas de ocupacion, control de cupo y entradas/salidas en albergues."

  alias Emergencias.Dominio.Modelos.Albergue

  @doc "Registrar el ingreso de una persona al albergue validando capacidad y duplicados."
  def ingresar_persona(%Albergue{} = alb, documento) do
    cond do
      MapSet.member?(alb.personas_alojadas, documento) ->
        {:error, :persona_ya_alojada}

      MapSet.size(alb.personas_alojadas) >= alb.capacidad_maxima ->
        {:error, :capacidad_excedida}

      true ->
        {:ok, %{alb | personas_alojadas: MapSet.put(alb.personas_alojadas, documento)}}
    end
  end

  @doc "Registrar la salida de una persona del albergue liberando cupo."
  def retirar_persona(%Albergue{} = alb, documento) do
    if MapSet.member?(alb.personas_alojadas, documento) do
      {:ok, %{alb | personas_alojadas: MapSet.delete(alb.personas_alojadas, documento)}}
    else
      {:error, :persona_no_alojada}
    end
  end

  @doc "Verificar si el albergue tiene cupo disponible."
  def tener_cupo?(%Albergue{} = alb) do
    MapSet.size(alb.personas_alojadas) < alb.capacidad_maxima
  end

  @doc "Calcular la ocupacion actual y capacidad maxima del albergue."
  def calcular_ocupacion(%Albergue{} = alb) do
    {MapSet.size(alb.personas_alojadas), alb.capacidad_maxima}
  end
end
