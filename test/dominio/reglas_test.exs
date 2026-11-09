defmodule Emergencias.Dominio.ReglasTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.{Albergue, Mascota, Necesidad, PuntoAtencion, Recurso, Sector, Zona}
  alias Emergencias.Dominio.Reglas.{Estados, Inventario, JerarquiaZona, Ocupacion, Ordenamiento, Permisos, SimilitudMascotas, Validaciones}

  test "validaciones basicas y manejo de enteros sin excepciones" do
    assert {:ok, 42} = Validaciones.validar_entero("42")
    assert {:error, :numero_invalido} = Validaciones.validar_entero("abc")
    assert {:ok, 10} = Validaciones.validar_positivo("10")
    assert {:error, :cantidad_invalida} = Validaciones.validar_positivo("-5")
    assert {:ok, "Zona 1"} = Validaciones.validar_no_vacio("  Zona 1  ")
    assert {:error, :campo_vacio} = Validaciones.validar_no_vacio("   ")
  end

  test "permisos por rol" do
    assert :ok = Permisos.autorizar(:coordinador, :asignar_recurso)
    assert {:error, :no_autorizado} = Permisos.autorizar(:ciudadano, :asignar_recurso)
  end

  test "transiciones de estado validas y terminales" do
    nec = %Necesidad{id: "N1", estado: :pendiente, historial: []}
    assert {:ok, nec_asig} = Estados.transitar(nec, :asignada, "Laura", "2026-11-09T00:00:00Z")
    assert nec_asig.estado == :asignada
    assert {:error, :transicion_invalida} = Estados.transitar(nec_asig, :pendiente, "Laura", "2026-11-09T00:00:00Z")
  end

  test "inventario agrega, descuenta y transfiere" do
    r1 = %Recurso{id: "R1", cantidad_total: 50, cantidad_disponible: 50, ubicacion: "Z1"}
    r2 = %Recurso{id: "R2", cantidad_total: 10, cantidad_disponible: 10, ubicacion: "Z2"}
    assert {:ok, r1_desc, _} = Inventario.descontar(r1, 20, "Laura", "hoy")
    assert r1_desc.cantidad_disponible == 30
    assert {:ok, o_act, d_act, _} = Inventario.transferir(r1, r2, 15, "Laura", "hoy")
    assert o_act.cantidad_disponible == 35
    assert d_act.cantidad_disponible == 25
  end

  test "jerarquia territorial recursiva casos base y recursivos" do
    assert JerarquiaZona.contar_puntos_atencion([]) == 0
    assert JerarquiaZona.sumar_personas_afectadas([]) == 0
    assert {:error, :punto_no_encontrado} = JerarquiaZona.buscar_punto_atencion([], "P1")

    p1 = %PuntoAtencion{id: "P1", nombre: "Carpa 1", personas_afectadas: 15}
    p2 = %PuntoAtencion{id: "P2", nombre: "Carpa 2", personas_afectadas: 25}
    s1 = %Sector{id: "S1", nombre: "Norte", personas_afectadas: 10, puntos_atencion: [p1, p2]}
    z1 = %Zona{id: "Z1", nombre: "Centro", personas_afectadas: 5, sectores: [s1]}

    assert JerarquiaZona.contar_puntos_atencion(z1) == 2
    assert JerarquiaZona.sumar_personas_afectadas(z1) == 55
    assert {:ok, %PuntoAtencion{id: "P1"}} = JerarquiaZona.buscar_punto_atencion(z1, "P1")
    assert JerarquiaZona.sumar_cantidades([%{cantidad: 10}, %{cantidad: 20}]) == 30
  end

  test "ordenamiento merge sort de necesidades y albergues" do
    n1 = %Necesidad{id: "N1", prioridad: :baja, fecha_registro: "2026-11-09T01:00:00Z"}
    n2 = %Necesidad{id: "N2", prioridad: :critica, fecha_registro: "2026-11-09T02:00:00Z"}
    n3 = %Necesidad{id: "N3", prioridad: :alta, fecha_registro: "2026-11-09T03:00:00Z"}
    ordenadas = Ordenamiento.ordenar([n1, n2, n3], &Ordenamiento.comparar_necesidades/2)
    assert Enum.map(ordenadas, & &1.id) == ["N2", "N3", "N1"]
  end

  test "similitud de mascotas y emparejamiento ponderado" do
    m1 = %Mascota{id: "M1", tipo_reporte: :perdida, especie: "perro", color: "dorado", tamano: :mediano, codigo_zona: "Z1", nombre: "Rocky", caracteristicas: ["collar"], estado: :activa}
    m2 = %Mascota{id: "M2", tipo_reporte: :encontrada, especie: "perro", color: "dorado", tamano: :mediano, codigo_zona: "Z1", nombre: "Rocky", caracteristicas: ["collar"], estado: :activa}
    m3 = %Mascota{id: "M3", tipo_reporte: :encontrada, especie: "gato", color: "negro", tamano: :pequeno, codigo_zona: "Z2", estado: :activa}

    assert SimilitudMascotas.calcular_similitud(m1, m2) >= 80
    assert SimilitudMascotas.calcular_similitud(m1, m3) == 0
    coincidencias = SimilitudMascotas.emparejar([m1, m2, m3], 60)
    assert length(coincidencias) == 1
  end

  test "ocupacion de albergues con aforo y duplicados" do
    alb = %Albergue{id: "A1", capacidad_maxima: 2, personas_alojadas: MapSet.new()}
    assert {:ok, alb1} = Ocupacion.ingresar_persona(alb, "10949001")
    assert {:error, :persona_ya_alojada} = Ocupacion.ingresar_persona(alb1, "10949001")
    assert {:ok, alb2} = Ocupacion.ingresar_persona(alb1, "10949002")
    assert {:error, :capacidad_excedida} = Ocupacion.ingresar_persona(alb2, "10949003")
    assert {:ok, alb_salida} = Ocupacion.retirar_persona(alb2, "10949001")
    assert Ocupacion.tener_cupo?(alb_salida)
  end
end
