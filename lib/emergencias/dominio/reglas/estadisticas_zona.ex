defmodule Emergencias.Dominio.Reglas.EstadisticasZona do
  @moduledoc """
  Cálculo de estadísticas e inspección sobre la jerarquía Zona -> Sector -> PuntoAtencion.
  Implementado con algoritmos recursivos explícitos (sin `Enum.reduce`).
  """

  alias Emergencias.Dominio.Modelos.{MovimientoInventario, PuntoAtencion, Sector, Zona}

  @doc """
  Contar recursivamente el número total de puntos de atención dentro de una zona.

  - **Caso Base**: Una lista vacía de sectores no contiene puntos de atención (retorna acumulador).
  - **Caso Recursivo**: Para cada sector, cuenta recursivamente sus puntos de atención, los suma
    al acumulador y continúa con los sectores restantes.
  """
  @spec contar_puntos_atencion(Zona.t()) :: non_neg_integer()
  def contar_puntos_atencion(%Zona{sectores: sectores}) do
    contar_puntos_en_sectores(sectores, 0)
  end

  defp contar_puntos_en_sectores([], acumulador), do: acumulador

  defp contar_puntos_en_sectores([%Sector{puntos_atencion: puntos} | resto], acumulador) do
    total_sector = contar_elementos_lista(puntos, 0)
    contar_puntos_en_sectores(resto, acumulador + total_sector)
  end

  defp contar_elementos_lista([], acumulador), do: acumulador
  defp contar_elementos_lista([_cabeza | cola], acumulador), do: contar_elementos_lista(cola, acumulador + 1)

  @doc """
  Sumar recursivamente la cantidad de personas afectadas en todos los puntos de atención de la zona.

  - **Caso Base**: Lista de sectores vacía retorna el total acumulado.
  - **Caso Recursivo**: Suma recursivamente las personas afectadas en los puntos del sector actual
    al acumulador y avanza recursivamente sobre los demás sectores.
  """
  @spec sumar_personas_afectadas(Zona.t()) :: non_neg_integer()
  def sumar_personas_afectadas(%Zona{sectores: sectores}) do
    acumular_afectados_sectores(sectores, 0)
  end

  defp acumular_afectados_sectores([], acumulador), do: acumulador

  defp acumular_afectados_sectores([%Sector{puntos_atencion: puntos} | resto], acumulador) do
    subtotal_sector = acumular_afectados_puntos(puntos, 0)
    acumular_afectados_sectores(resto, acumulador + subtotal_sector)
  end

  defp acumular_afectados_puntos([], acumulador), do: acumulador

  defp acumular_afectados_puntos([%PuntoAtencion{personas_afectadas: cant} | resto], acumulador) do
    acumular_afectados_puntos(resto, acumulador + cant)
  end

  @doc """
  Buscar recursivamente un punto de atención por su código identificador en la jerarquía.

  - **Caso Base 1**: Si la lista de sectores está vacía, el punto no existe (`{:error, :no_encontrado}`).
  - **Caso Base 2**: Si la cabeza de la lista de puntos coincide con el código buscado, se retorna `{:ok, punto}`.
  - **Caso Recursivo**: Busca dentro de los puntos del sector actual; si no se halla, prosigue con los sectores restantes.
  """
  @spec buscar_punto_atencion(Zona.t(), String.t()) ::
          {:ok, PuntoAtencion.t()} | {:error, :no_encontrado}
  def buscar_punto_atencion(%Zona{sectores: sectores}, codigo_punto) when is_binary(codigo_punto) do
    buscar_en_sectores(sectores, codigo_punto)
  end

  defp buscar_en_sectores([], _codigo), do: {:error, :no_encontrado}

  defp buscar_en_sectores([%Sector{puntos_atencion: puntos} | resto_sectores], codigo) do
    case buscar_en_puntos(puntos, codigo) do
      {:ok, punto} -> {:ok, punto}
      {:error, :no_encontrado} -> buscar_en_sectores(resto_sectores, codigo)
    end
  end

  defp buscar_en_puntos([], _codigo), do: {:error, :no_encontrado}
  defp buscar_en_puntos([%PuntoAtencion{id: id} = p | _resto], id), do: {:ok, p}
  defp buscar_en_puntos([_cabeza | cola], codigo), do: buscar_en_puntos(cola, codigo)

  @doc """
  Aplanar recursivamente la jerarquía Zona -> Sectores -> Puntos de Atención en una lista plana de puntos.

  - **Caso Base**: Lista vacía de sectores produce una lista acumulada vacía.
  - **Caso Recursivo**: Extrae recursivamente los puntos del sector actual y los concatena con
    la lista aplanada de los sectores restantes.
  """
  @spec aplanar_jerarquia(Zona.t()) :: list(PuntoAtencion.t())
  def aplanar_jerarquia(%Zona{sectores: sectores}) do
    aplanar_sectores(sectores, [])
  end

  defp aplanar_sectores([], acumulador), do: revertir_lista(acumulador, [])

  defp aplanar_sectores([%Sector{puntos_atencion: puntos} | resto], acumulador) do
    nuevo_acumulador = agregar_puntos_a_acumulador(puntos, acumulador)
    aplanar_sectores(resto, nuevo_acumulador)
  end

  defp agregar_puntos_a_acumulador([], acumulador), do: acumulador
  defp agregar_puntos_a_acumulador([p | resto], acumulador) do
    agregar_puntos_a_acumulador(resto, [p | acumulador])
  end

  @doc """
  Sumar las cantidades numéricas de una lista de movimientos utilizando recursión de cola con acumulador.

  - **Caso Base**: `[]` retorna el acumulador.
  - **Caso Recursivo**: Suma la cantidad del movimiento en la cabeza al acumulador y procesa la cola.
  """
  @spec sumar_cantidades(list(MovimientoInventario.t())) :: non_neg_integer()
  def sumar_cantidades(movimientos) when is_list(movimientos) do
    sumar_cantidades_recursivo(movimientos, 0)
  end

  defp sumar_cantidades_recursivo([], acumulador), do: acumulador

  defp sumar_cantidades_recursivo([%MovimientoInventario{cantidad: cant} | resto], acumulador) do
    sumar_cantidades_recursivo(resto, acumulador + cant)
  end

  defp revertir_lista([], acumulador), do: acumulador
  defp revertir_lista([cabeza | cola], acumulador), do: revertir_lista(cola, [cabeza | acumulador])
end
