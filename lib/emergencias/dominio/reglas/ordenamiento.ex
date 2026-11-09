defmodule Emergencias.Dominio.Reglas.Ordenamiento do
  @moduledoc """
  Implementación pura de algoritmo de ordenamiento Merge Sort recursivo.
  Incluye criterio de ordenación para necesidades por prioridad descendente y fecha ascendente.
  """

  alias Emergencias.Dominio.Modelos.Necesidad
  alias Emergencias.Dominio.Reglas.Prioridades

  @doc """
  Ordenar una lista de necesidades priorizando el mayor nivel de urgencia (descendente)
  y desempatando por la fecha de registro más antigua (ascendente).

  - **Caso Base**: Una lista vacía o de un solo elemento ya se encuentra ordenada.
  - **Caso Recursivo**: Se divide la lista en mitades izquierda y derecha, se ordenan recursivamente
    y se combinan con la función de mezcla.
  """
  @spec ordenar_por_prioridad(list(Necesidad.t())) :: list(Necesidad.t())
  def ordenar_por_prioridad(necesidades) when is_list(necesidades) do
    ordenar_merge_sort(necesidades, &anteceder_necesidad?/2)
  end

  @doc """
  Merge Sort genérico parametrizado por una función comparadora `(a, b -> boolean)`.

  - **Caso Base**: `[]` retorna `[]`; `[x]` retorna `[x]`.
  - **Caso Recursivo**: Para listas con 2 o más elementos, divide la lista en dos mitades,
    ordena recursivamente cada mitad y luego las mezcla.
  """
  @spec ordenar_merge_sort(list(), (any(), any() -> boolean())) :: list()
  def ordenar_merge_sort([], _comparador), do: []
  def ordenar_merge_sort([elemento], _comparador), do: [elemento]

  def ordenar_merge_sort(lista, comparador) when is_list(lista) and is_function(comparador, 2) do
    {izquierda, derecha} = dividir_lista(lista)
    izq_ordenada = ordenar_merge_sort(izquierda, comparador)
    der_ordenada = ordenar_merge_sort(derecha, comparador)
    mezclar_listas(izq_ordenada, der_ordenada, comparador)
  end

  @doc """
  Dividir una lista en dos mitades aproximadamente iguales.

  - **Caso Base**: Lista vacía o unitaria.
  - **Caso Recursivo**: Distribuye los elementos alternadamente o usando longitud dividida.
  """
  @spec dividir_lista(list()) :: {list(), list()}
  def dividir_lista(lista) when is_list(lista) do
    mitad = div(length(lista), 2)
    dividir_en_indice(lista, mitad, [])
  end

  defp dividir_en_indice(restante, 0, acumulador) do
    {revertir_lista(acumulador, []), restante}
  end

  defp dividir_en_indice([cabeza | cola], contador, acumulador) do
    dividir_en_indice(cola, contador - 1, [cabeza | acumulador])
  end

  @doc """
  Mezclar dos listas ordenadas en una sola respetando el predicado comparador.

  - **Caso Base 1**: Mezclar `[]` con `der` retorna `der`.
  - **Caso Base 2**: Mezclar `izq` con `[]` retorna `izq`.
  - **Caso Recursivo**: Compara las cabezas de ambas listas; coloca la menor primero y mezcla
    recursivamente el resto.
  """
  @spec mezclar_listas(list(), list(), (any(), any() -> boolean())) :: list()
  def mezclar_listas([], derecha, _comparador), do: derecha
  def mezclar_listas(izquierda, [], _comparador), do: izquierda

  def mezclar_listas([cabeza_izq | cola_izq] = izq, [cabeza_der | cola_der] = der, comparador) do
    if comparador.(cabeza_izq, cabeza_der) do
      [cabeza_izq | mezclar_listas(cola_izq, der, comparador)]
    else
      [cabeza_der | mezclar_listas(izq, cola_der, comparador)]
    end
  end

  @doc """
  Determinar si una necesidad antecede a otra según prioridad (desc) y fecha (asc).
  """
  @spec anteceder_necesidad?(Necesidad.t(), Necesidad.t()) :: boolean()
  def anteceder_necesidad?(%Necesidad{} = n1, %Necesidad{} = n2) do
    peso1 = Prioridades.obtener_peso(n1.prioridad)
    peso2 = Prioridades.obtener_peso(n2.prioridad)

    cond do
      peso1 > peso2 -> true
      peso1 < peso2 -> false
      true -> n1.fecha_registro <= n2.fecha_registro
    end
  end

  defp revertir_lista([], acumulador), do: acumulador
  defp revertir_lista([cabeza | cola], acumulador), do: revertir_lista(cola, [cabeza | acumulador])
end
