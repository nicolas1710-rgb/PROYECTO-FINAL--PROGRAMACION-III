defmodule Emergencias.Dominio.Reglas.SimilitudMascotas do
  @moduledoc "Algoritmo ponderado de similitud entre mascotas con coeficiente Jaccard."

  alias Emergencias.Dominio.Modelos.Mascota

  @doc "Calcular puntaje de similitud (0-100) entre dos reportes de mascotas."
  def calcular_similitud(%Mascota{} = a, %Mascota{} = b) do
    if normalizar(a.especie) != normalizar(b.especie) do
      0
    else
      25 + puntaje_color(a, b) + puntaje_tamano(a, b) + puntaje_zona(a, b) + puntaje_nombre(a, b) + puntaje_jaccard(a, b)
    end
  end

  defp puntaje_color(a, b), do: if(normalizar(a.color) == normalizar(b.color), do: 20, else: 0)
  defp puntaje_tamano(a, b), do: if(a.tamano == b.tamano, do: 15, else: 0)
  defp puntaje_zona(a, b), do: if(a.codigo_zona == b.codigo_zona, do: 20, else: 0)

  defp puntaje_nombre(a, b) do
    nom_a = normalizar(a.nombre || "")
    nom_b = normalizar(b.nombre || "")
    if nom_a != "" and nom_a == nom_b, do: 5, else: 0
  end

  defp puntaje_jaccard(a, b) do
    set_a = MapSet.new(a.caracteristicas || [])
    set_b = MapSet.new(b.caracteristicas || [])
    union = MapSet.union(set_a, set_b)

    if MapSet.size(union) == 0 do
      15
    else
      inter = MapSet.intersection(set_a, set_b)
      round(15 * MapSet.size(inter) / MapSet.size(union))
    end
  end

  @doc "Emparejar mascotas perdidas y encontradas activas que superen el umbral."
  def emparejar(mascotas, umbral \\ 60) do
    perdidas = Enum.filter(mascotas, &(&1.tipo_reporte == :perdida and &1.estado == :activa))
    encontradas = Enum.filter(mascotas, &(&1.tipo_reporte == :encontrada and &1.estado == :activa))

    for p <- perdidas, e <- encontradas, puntaje = calcular_similitud(p, e), puntaje >= umbral do
      %{perdida: p, encontrada: e, puntaje: puntaje}
    end
    |> Enum.sort_by(& &1.puntaje, :desc)
  end

  defp normalizar(str), do: str |> to_string() |> String.downcase() |> String.trim()
end
