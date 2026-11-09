defmodule Emergencias.Dominio.Reglas.JerarquiaZona do
  @moduledoc "Operaciones recursivas sobre el arbol Zona -> Sector -> PuntoAtencion."

  alias Emergencias.Dominio.Modelos.{PuntoAtencion, Sector, Zona}

  @doc "Contar el total de puntos de atencion a traves de los sectores de forma recursiva."
  def contar_puntos_atencion(%Zona{sectores: sectores}), do: contar_puntos_en_sectores(sectores)
  def contar_puntos_atencion(sectores) when is_list(sectores), do: contar_puntos_en_sectores(sectores)

  # Caso base: lista de sectores vacia
  defp contar_puntos_en_sectores([]), do: 0
  # Caso recursivo: suma puntos del sector cabeza con el resto de sectores
  defp contar_puntos_en_sectores([%Sector{puntos_atencion: puntos} | resto]) do
    contar_elementos(puntos) + contar_puntos_en_sectores(resto)
  end

  defp contar_elementos([]), do: 0
  defp contar_elementos([_ | resto]), do: 1 + contar_elementos(resto)

  @doc "Sumar recursivamente las personas afectadas en todos los sectores y puntos."
  def sumar_personas_afectadas(%Zona{personas_afectadas: p, sectores: s}) do
    p + sumar_personas_en_sectores(s)
  end
  def sumar_personas_afectadas(sectores) when is_list(sectores), do: sumar_personas_en_sectores(sectores)

  # Caso base: sectores agotados
  defp sumar_personas_en_sectores([]), do: 0
  # Caso recursivo: suma personas del sector, sus puntos y los sectores restantes
  defp sumar_personas_en_sectores([%Sector{personas_afectadas: p, puntos_atencion: puntos} | resto]) do
    p + sumar_personas_en_puntos(puntos) + sumar_personas_en_sectores(resto)
  end

  defp sumar_personas_en_puntos([]), do: 0
  defp sumar_personas_en_puntos([%PuntoAtencion{personas_afectadas: p} | resto]) do
    p + sumar_personas_en_puntos(resto)
  end

  @doc "Buscar recursivamente un punto de atencion dentro de la jerarquia territorial."
  def buscar_punto_atencion(%Zona{sectores: sectores}, id), do: buscar_punto_en_sectores(sectores, id)
  def buscar_punto_atencion(sectores, id) when is_list(sectores), do: buscar_punto_en_sectores(sectores, id)

  # Caso base: sectores agotados sin hallar el punto
  defp buscar_punto_en_sectores([], _id), do: {:error, :punto_no_encontrado}
  # Caso recursivo: busca en puntos del sector cabeza; si no esta, avanza al resto
  defp buscar_punto_en_sectores([%Sector{puntos_atencion: puntos} | resto], id) do
    case buscar_en_lista_puntos(puntos, id) do
      {:ok, punto} -> {:ok, punto}
      {:error, :no_encontrado} -> buscar_punto_en_sectores(resto, id)
    end
  end

  defp buscar_en_lista_puntos([], _id), do: {:error, :no_encontrado}
  defp buscar_en_lista_puntos([%PuntoAtencion{id: id} = p | _], id), do: {:ok, p}
  defp buscar_en_lista_puntos([_ | resto], id), do: buscar_en_lista_puntos(resto, id)

  @doc "Buscar un sector especifico dentro de una zona de forma recursiva."
  def buscar_sector([], _id), do: {:error, :sector_no_encontrado}
  def buscar_sector([%Sector{id: id} = s | _], id), do: {:ok, s}
  def buscar_sector([_ | resto], id), do: buscar_sector(resto, id)

  @doc "Agregar un punto de atencion al sector correspondiente navegando recursivamente."
  def agregar_punto_a_sectores([], _id_sec, _punto), do: {:error, :sector_no_encontrado}
  def agregar_punto_a_sectores([%Sector{id: id_sec, puntos_atencion: pts} = s | resto], id_sec, punto) do
    {:ok, [%{s | puntos_atencion: pts ++ [punto]} | resto]}
  end
  def agregar_punto_a_sectores([s | resto], id_sec, punto) do
    case agregar_punto_a_sectores(resto, id_sec, punto) do
      {:ok, nuevos_sectores} -> {:ok, [s | nuevos_sectores]}
      error -> error
    end
  end

  @doc "Sumar recursivamente con acumulador en cola las cantidades de una lista de movimientos."
  def sumar_cantidades(movimientos, acc \\ 0)
  # Caso base: lista de movimientos vacia
  def sumar_cantidades([], acc), do: acc
  # Caso recursivo de cola: acumula la cantidad y avanza en la lista
  def sumar_cantidades([%{cantidad: c} | resto], acc), do: sumar_cantidades(resto, acc + c)
end
