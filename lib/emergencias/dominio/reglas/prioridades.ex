defmodule Emergencias.Dominio.Reglas.Prioridades do
  @moduledoc """
  Define la escala numérica de prioridades para la asignación y atención de emergencias.
  """

  @pesos %{
    critica: 4,
    alta: 3,
    media: 2,
    baja: 1
  }

  @doc """
  Obtener el peso numérico asociado a una prioridad.
  """
  @spec obtener_peso(atom()) :: non_neg_integer()
  def obtener_peso(prioridad) when is_atom(prioridad) do
    Map.get(@pesos, prioridad, 0)
  end

  def obtener_peso(_), do: 0

  @doc """
  Comparar dos prioridades; retorna :mayor, :menor o :igual.
  """
  @spec comparar_prioridades(atom(), atom()) :: :mayor | :menor | :igual
  def comparar_prioridades(p1, p2) do
    peso1 = obtener_peso(p1)
    peso2 = obtener_peso(p2)

    cond do
      peso1 > peso2 -> :mayor
      peso1 < peso2 -> :menor
      true -> :igual
    end
  end
end
