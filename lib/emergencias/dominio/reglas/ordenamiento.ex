defmodule Emergencias.Dominio.Reglas.Ordenamiento do
  @moduledoc "Algoritmo Merge Sort recursivo para ordenamiento de entidades."

  @doc "Ordenar una lista usando Merge Sort y un comparador booleano (a precede a b)."
  # Casos base: lista de 0 o 1 elemento ya esta ordenada
  def ordenar([], _comparador), do: []
  def ordenar([x], _comparador), do: [x]

  # Caso recursivo: divide en mitades, ordena recursivamente y mezcla
  def ordenar(lista, comparador) when is_list(lista) and is_function(comparador, 2) do
    {izq, der} = dividir(lista, [], [])
    mezclar(ordenar(izq, comparador), ordenar(der, comparador), comparador)
  end

  defp dividir([], izq, der), do: {izq, der}
  defp dividir([x | resto], izq, der), do: dividir(resto, der, [x | izq])

  # Casos base de mezcla
  defp mezclar([], der, _comp), do: der
  defp mezclar(izq, [], _comp), do: izq
  # Caso recursivo de mezcla
  defp mezclar([c_izq | r_izq] = izq, [c_der | r_der] = der, comp) do
    if comp.(c_izq, c_der) do
      [c_izq | mezclar(r_izq, der, comp)]
    else
      [c_der | mezclar(izq, r_der, comp)]
    end
  end

  @pesos_prioridad %{critica: 4, alta: 3, media: 2, baja: 1}

  @doc "Comparador para necesidades: prioridad descendente, desempata por fecha ascendente."
  def comparar_necesidades(a, b) do
    peso_a = Map.get(@pesos_prioridad, a.prioridad, 0)
    peso_b = Map.get(@pesos_prioridad, b.prioridad, 0)

    cond do
      peso_a > peso_b -> true
      peso_a < peso_b -> false
      true -> a.fecha_registro <= b.fecha_registro
    end
  end

  @doc "Comparador para albergues: porcentaje de ocupacion descendente."
  def comparar_albergues(a, b) do
    porc_a = MapSet.size(a.personas_alojadas) / max(a.capacidad_maxima, 1)
    porc_b = MapSet.size(b.personas_alojadas) / max(b.capacidad_maxima, 1)
    porc_a >= porc_b
  end
end
