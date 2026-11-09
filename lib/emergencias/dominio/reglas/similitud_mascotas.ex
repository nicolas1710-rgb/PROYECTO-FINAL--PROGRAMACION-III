defmodule Emergencias.Dominio.Reglas.SimilitudMascotas do
  @moduledoc """
  Algoritmo ponderado para calcular similitud y emparejar mascotas perdidas y encontradas.
  Puntaje de 0 a 100 basado en especie, color, tamaño, zona, nombre y características textuales.
  """

  alias Emergencias.Dominio.Modelos.ReporteMascota

  @peso_especie 25
  @peso_color 20
  @peso_tamano 15
  @peso_zona 20
  @peso_nombre 5
  @peso_caracteristicas 15
  @umbral_defecto 60

  @doc """
  Calcular el puntaje de similitud (0 a 100) entre dos reportes de mascotas.
  Solo evalúa entre un reporte de pérdida y uno de hallazgo con estado :activa.
  Si la especie no coincide, el puntaje es 0.
  """
  @spec calcular_similitud(ReporteMascota.t(), ReporteMascota.t()) :: non_neg_integer()
  def calcular_similitud(r1, r2)

  def calcular_similitud(
        %ReporteMascota{tipo_reporte: t1, estado: :activa} = rep1,
        %ReporteMascota{tipo_reporte: t2, estado: :activa} = rep2
      )
      when t1 != t2 do
    if normalizar_texto(rep1.especie) == normalizar_texto(rep2.especie) do
      puntaje_base = @peso_especie
      puntaje_color = evaluar_color(rep1.color, rep2.color)
      puntaje_tamano = evaluar_tamano(rep1.tamano, rep2.tamano)
      puntaje_zona = evaluar_zona(rep1.codigo_zona, rep2.codigo_zona)
      puntaje_nombre = evaluar_nombre(rep1.nombre, rep2.nombre)
      puntaje_caract = comparar_caracteristicas(rep1.caracteristicas, rep2.caracteristicas)

      puntaje_base + puntaje_color + puntaje_tamano + puntaje_zona + puntaje_nombre + puntaje_caract
    else
      0
    end
  end

  def calcular_similitud(_, _), do: 0

  @doc """
  Comparar dos listas de características utilizando el índice Jaccard (|intersección| / |unión| * 15).
  """
  @spec comparar_caracteristicas(list(String.t()), list(String.t())) :: non_neg_integer()
  def comparar_caracteristicas(caract1, caract2) when is_list(caract1) and is_list(caract2) do
    set1 = caract1 |> Enum.map(&normalizar_texto/1) |> MapSet.new()
    set2 = caract2 |> Enum.map(&normalizar_texto/1) |> MapSet.new()

    union = MapSet.union(set1, set2)
    tam_union = MapSet.size(union)

    if tam_union > 0 do
      interseccion = MapSet.intersection(set1, set2)
      tam_inter = MapSet.size(interseccion)
      round(tam_inter / tam_union * @peso_caracteristicas)
    else
      0
    end
  end

  @doc """
  Emparejar listas de reportes activos de mascotas perdidas y encontradas.
  Retorna una lista ordenada descendentemente por puntaje: `[{reporte_perdido, reporte_encontrado, puntaje}]`.
  """
  @spec emparejar_reportes(
          list(ReporteMascota.t()),
          list(ReporteMascota.t()),
          non_neg_integer()
        ) :: list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})
  def emparejar_reportes(perdidas, encontradas, umbral \\ @umbral_defecto) do
    coincidencias =
      for p <- perdidas,
          e <- encontradas,
          p.estado == :activa,
          e.estado == :activa,
          p.tipo_reporte == :perdida,
          e.tipo_reporte == :encontrada do
        puntaje = calcular_similitud(p, e)
        {p, e, puntaje}
      end

    coincidencias
    |> Enum.filter(fn {_p, _e, puntaje} -> puntaje >= umbral end)
    |> Enum.sort_by(fn {_p, _e, puntaje} -> puntaje end, :desc)
  end

  defp evaluar_color(c1, c2) do
    if normalizar_texto(c1) == normalizar_texto(c2), do: @peso_color, else: 0
  end

  defp evaluar_tamano(t1, t2) do
    if t1 == t2, do: @peso_tamano, else: 0
  end

  defp evaluar_zona(z1, z2) do
    if normalizar_texto(z1) == normalizar_texto(z2), do: @peso_zona, else: 0
  end

  defp evaluar_nombre(n1, n2) do
    norm1 = normalizar_texto(n1)
    norm2 = normalizar_texto(n2)

    if norm1 != "" and norm2 != "" and norm1 == norm2 do
      @peso_nombre
    else
      0
    end
  end

  defp normalizar_texto(nil), do: ""

  defp normalizar_texto(texto) when is_binary(texto) do
    texto |> String.trim() |> String.downcase()
  end

  defp normalizar_texto(otro), do: to_string(otro)
end
