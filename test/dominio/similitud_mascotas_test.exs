defmodule Emergencias.Dominio.SimilitudMascotasTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.ReporteMascota
  alias Emergencias.Dominio.Reglas.SimilitudMascotas

  setup do
    {:ok, r_perdido} =
      ReporteMascota.construir(%{
        id: "MC001",
        tipo_reporte: :perdida,
        especie: "perro",
        nombre: "Rocky",
        color: "dorado",
        tamano: :mediano,
        codigo_zona: "Z001",
        caracteristicas: ["collar rojo", "mancha blanca en pecho"],
        estado: :activa,
        usuario_reporta: "U001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, r_encontrado_exacto} =
      ReporteMascota.construir(%{
        id: "MC002",
        tipo_reporte: :encontrada,
        especie: "perro",
        nombre: "Rocky",
        color: "dorado",
        tamano: :mediano,
        codigo_zona: "Z001",
        caracteristicas: ["collar rojo", "mancha blanca en pecho"],
        estado: :activa,
        usuario_reporta: "U002",
        fecha_registro: "2026-03-01T11:00:00Z"
      })

    {:ok, r_encontrado_parcial} =
      ReporteMascota.construir(%{
        id: "MC003",
        tipo_reporte: :encontrada,
        especie: "perro",
        nombre: "",
        color: "dorado",
        tamano: :mediano,
        codigo_zona: "Z001",
        caracteristicas: ["mancha blanca en pecho", "cola corta"],
        estado: :activa,
        usuario_reporta: "U003",
        fecha_registro: "2026-03-01T12:00:00Z"
      })

    {:ok, r_gato} =
      ReporteMascota.construir(%{
        id: "MC004",
        tipo_reporte: :encontrada,
        especie: "gato",
        nombre: "Felix",
        color: "dorado",
        tamano: :pequeno,
        codigo_zona: "Z001",
        estado: :activa,
        usuario_reporta: "U004",
        fecha_registro: "2026-03-01T13:00:00Z"
      })

    %{
      perdido: r_perdido,
      exacto: r_encontrado_exacto,
      parcial: r_encontrado_parcial,
      gato: r_gato
    }
  end

  test "similitud maxima con coincidencia total", %{perdido: p, exacto: e} do
    # 25 (especie) + 20 (color) + 15 (tamano) + 20 (zona) + 5 (nombre) + 15 (caracteristicas identicas) = 100
    assert SimilitudMascotas.calcular_similitud(p, e) == 100
  end

  test "especie distinta produce puntaje cero inmediato", %{perdido: p, gato: g} do
    assert SimilitudMascotas.calcular_similitud(p, g) == 0
  end

  test "similitud parcial supera el umbral de 60", %{perdido: p, parcial: parc} do
    puntaje = SimilitudMascotas.calcular_similitud(p, parc)
    # 25 (especie) + 20 (color) + 15 (tamano) + 20 (zona) = 80 puntos base + similitud caracteristicas
    assert puntaje >= 80
  end

  test "emparejar listas de reportes filtradas por umbral y ordenadas", %{
    perdido: p,
    exacto: e,
    parcial: parc,
    gato: g
  } do
    perdidas = [p]
    encontradas = [parc, e, g]

    coincidencias = SimilitudMascotas.emparejar_reportes(perdidas, encontradas, 60)
    assert length(coincidencias) == 2

    # El de 100 puntos debe aparecer antes que el parcial
    [{_p1, e1, puntaje1}, {_p2, e2, puntaje2}] = coincidencias
    assert e1.id == "MC002"
    assert puntaje1 == 100
    assert e2.id == "MC003"
    assert puntaje2 < 100
  end
end
