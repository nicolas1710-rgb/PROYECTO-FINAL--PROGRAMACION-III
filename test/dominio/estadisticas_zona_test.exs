defmodule Emergencias.Dominio.EstadisticasZonaTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.{MovimientoInventario, PuntoAtencion, Sector, Zona}
  alias Emergencias.Dominio.Reglas.EstadisticasZona

  setup do
    {:ok, p1} = PuntoAtencion.construir(%{id: "PT001", nombre: "Punto 1", personas_afectadas: 10})
    {:ok, p2} = PuntoAtencion.construir(%{id: "PT002", nombre: "Punto 2", personas_afectadas: 25})
    {:ok, p3} = PuntoAtencion.construir(%{id: "PT003", nombre: "Punto 3", personas_afectadas: 15})

    {:ok, sec1} = Sector.construir(%{id: "S001", nombre: "Norte", puntos_atencion: [p1, p2]})
    {:ok, sec2} = Sector.construir(%{id: "S002", nombre: "Sur", puntos_atencion: [p3]})

    {:ok, zona_llena} =
      Zona.construir(%{
        id: "Z001",
        nombre: "Centro",
        nivel_gravedad: :critico,
        fecha_registro: "2026-03-01T10:00:00Z",
        sectores: [sec1, sec2]
      })

    {:ok, zona_vacia} =
      Zona.construir(%{
        id: "Z002",
        nombre: "Periferia",
        nivel_gravedad: :bajo,
        fecha_registro: "2026-03-01T10:00:00Z",
        sectores: []
      })

    %{zona_llena: zona_llena, zona_vacia: zona_vacia, p2: p2}
  end

  test "contar_puntos_atencion caso base y recursivo", %{
    zona_vacia: vacia,
    zona_llena: llena
  } do
    # Caso base: zona sin sectores ni puntos
    assert EstadisticasZona.contar_puntos_atencion(vacia) == 0

    # Caso recursivo: zona con 2 sectores y 3 puntos en total
    assert EstadisticasZona.contar_puntos_atencion(llena) == 3
  end

  test "sumar_personas_afectadas caso base y recursivo", %{
    zona_vacia: vacia,
    zona_llena: llena
  } do
    # Caso base
    assert EstadisticasZona.sumar_personas_afectadas(vacia) == 0

    # Caso recursivo: 10 + 25 + 15 = 50 personas afectadas
    assert EstadisticasZona.sumar_personas_afectadas(llena) == 50
  end

  test "buscar_punto_atencion en jerarquia recursiva", %{zona_llena: llena, p2: esperado} do
    # Caso recursivo con exito
    assert {:ok, punto} = EstadisticasZona.buscar_punto_atencion(llena, "PT002")
    assert punto.id == esperado.id
    assert punto.personas_afectadas == 25

    # Caso base / no encontrado
    assert {:error, :no_encontrado} =
             EstadisticasZona.buscar_punto_atencion(llena, "INEXISTENTE")
  end

  test "aplanar_jerarquia convierte arbol en lista plana", %{
    zona_vacia: vacia,
    zona_llena: llena
  } do
    # Caso base
    assert EstadisticasZona.aplanar_jerarquia(vacia) == []

    # Caso recursivo
    puntos = EstadisticasZona.aplanar_jerarquia(llena)
    assert length(puntos) == 3
    assert Enum.map(puntos, & &1.id) == ["PT001", "PT002", "PT003"]
  end

  test "sumar_cantidades con recursion de cola y acumulador" do
    {:ok, m1} =
      MovimientoInventario.construir(%{
        id: "M1",
        codigo_recurso: "R1",
        tipo_movimiento: :salida,
        cantidad: 30,
        origen: "Z1",
        destino: "P1",
        fecha: "2026-03-01T10:00:00Z",
        usuario_responsable: "U1"
      })

    {:ok, m2} =
      MovimientoInventario.construir(%{
        id: "M2",
        codigo_recurso: "R1",
        tipo_movimiento: :salida,
        cantidad: 20,
        origen: "Z1",
        destino: "P2",
        fecha: "2026-03-01T10:05:00Z",
        usuario_responsable: "U1"
      })

    # Caso base
    assert EstadisticasZona.sumar_cantidades([]) == 0

    # Caso recursivo
    assert EstadisticasZona.sumar_cantidades([m1, m2]) == 50
  end
end
