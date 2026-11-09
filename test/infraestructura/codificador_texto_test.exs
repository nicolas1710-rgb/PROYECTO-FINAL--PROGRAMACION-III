defmodule Emergencias.Infraestructura.CodificadorTextoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.{
    Albergue,
    Mensaje,
    MovimientoInventario,
    Necesidad,
    Persona,
    PuntoAtencion,
    Recurso,
    RegistroActividad,
    ReporteMascota,
    Sector,
    Usuario,
    Zona
  }

  alias Emergencias.Infraestructura.Salida.Persistencia.CodificadorTexto

  test "codificar y decodificar usuario con caracteres normales y pipes" do
    {:ok, u} =
      Usuario.construir(%{
        id: "U001",
        nombre: "Laura|Coordinadora",
        rol: :coordinador,
        clave_hash: "abcd1234efgh5678",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    assert {:ok, linea} = CodificadorTexto.codificar(u)
    assert {:ok, dec} = CodificadorTexto.decodificar(linea, :usuarios)
    assert dec.id == u.id
    assert dec.nombre == "Laura|Coordinadora"
    assert dec.rol == :coordinador
  end

  test "codificar y decodificar jerarquia de zona con sectores y puntos" do
    {:ok, p} = PuntoAtencion.construir(%{id: "PT001", nombre: "Puesto Cruz Roja", personas_afectadas: 12})
    {:ok, s} = Sector.construir(%{id: "S001", nombre: "Centro Norte", puntos_atencion: [p]})

    {:ok, z} =
      Zona.construir(%{
        id: "Z001",
        nombre: "Sector Comercial",
        nivel_gravedad: :critico,
        fecha_registro: "2026-03-01T10:00:00Z",
        sectores: [s]
      })

    assert {:ok, linea} = CodificadorTexto.codificar(z)
    assert {:ok, dec} = CodificadorTexto.decodificar(linea, :zonas)
    assert dec.id == z.id
    assert dec.nivel_gravedad == :critico
    assert length(dec.sectores) == 1

    [sec_dec] = dec.sectores
    assert sec_dec.id == "S001"
    assert length(sec_dec.puntos_atencion) == 1
    [pt_dec] = sec_dec.puntos_atencion
    assert pt_dec.id == "PT001"
    assert pt_dec.personas_afectadas == 12
  end

  test "codificar y decodificar necesidad con historial" do
    {:ok, n} =
      Necesidad.construir(%{
        id: "N001",
        codigo_zona: "Z001",
        tipo_recurso: "agua potable",
        cantidad_solicitada: 100,
        cantidad_asignada: 20,
        prioridad: :critica,
        estado: :asignada,
        fecha_registro: "2026-03-01T10:00:00Z",
        usuario_reporta: "Pedro",
        historial: [
          %{
            fecha: "2026-03-01T10:05:00Z",
            estado_anterior: :pendiente,
            estado_nuevo: :asignada,
            usuario: "Laura"
          }
        ]
      })

    assert {:ok, linea} = CodificadorTexto.codificar(n)
    assert {:ok, dec} = CodificadorTexto.decodificar(linea, :necesidades)
    assert dec.id == "N001"
    assert dec.cantidad_asignada == 20
    assert length(dec.historial) == 1
  end

  test "codificar y decodificar recurso y movimiento" do
    {:ok, r} =
      Recurso.construir(%{
        id: "R001",
        tipo: "alimentos",
        unidad_medida: "kits",
        cantidad_total: 50,
        cantidad_disponible: 30,
        cantidad_reservada: 20,
        codigo_zona: "Z001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    assert {:ok, linea_r} = CodificadorTexto.codificar(r)
    assert {:ok, dec_r} = CodificadorTexto.decodificar(linea_r, :recursos)
    assert dec_r.cantidad_reservada == 20

    {:ok, m} =
      MovimientoInventario.construir(%{
        id: "MOV001",
        codigo_recurso: "R001",
        tipo_movimiento: :asignacion,
        cantidad: 20,
        origen: "Z001",
        destino: "N001",
        fecha: "2026-03-01T10:10:00Z",
        usuario_responsable: "Laura"
      })

    assert {:ok, linea_m} = CodificadorTexto.codificar(m)
    assert {:ok, dec_m} = CodificadorTexto.decodificar(linea_m, :movimientos)
    assert dec_m.tipo_movimiento == :asignacion
  end

  test "codificar y decodificar persona, mensaje, mascota, albergue y actividad" do
    {:ok, p} =
      Persona.construir(%{
        id: "P001",
        documento: "10949001",
        nombre_completo: "Carlos Gomez",
        estado: :localizada,
        fecha_reporte: "2026-03-01T10:00:00Z",
        ubicacion_actual: "Hospital Central",
        codigo_albergue: "ALB001"
      })

    assert {:ok, linea_p} = CodificadorTexto.codificar(p)
    assert {:ok, dec_p} = CodificadorTexto.decodificar(linea_p, :personas)
    assert dec_p.codigo_albergue == "ALB001"

    {:ok, msg} =
      Mensaje.construir(%{
        id: "M001",
        documento_persona: "10949001",
        remitente: "Hermano",
        contenido: "Mensaje con | barra y \n salto de linea",
        fecha_envio: "2026-03-01T10:00:00Z"
      })

    assert {:ok, linea_msg} = CodificadorTexto.codificar(msg)
    assert {:ok, dec_msg} = CodificadorTexto.decodificar(linea_msg, :mensajes)
    assert dec_msg.contenido == "Mensaje con | barra y \n salto de linea"

    {:ok, pet} =
      ReporteMascota.construir(%{
        id: "MC001",
        tipo_reporte: :perdida,
        especie: "perro",
        nombre: "Toby",
        color: "marron",
        tamano: :pequeno,
        codigo_zona: "Z001",
        caracteristicas: ["cola corta", "collar azul"],
        estado: :activa,
        usuario_reporta: "Pedro",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    assert {:ok, linea_pet} = CodificadorTexto.codificar(pet)
    assert {:ok, dec_pet} = CodificadorTexto.decodificar(linea_pet, :mascotas)
    assert dec_pet.caracteristicas == ["cola corta", "collar azul"]

    {:ok, alb} =
      Albergue.construir(%{
        id: "ALB001",
        nombre: "Refugio Norte",
        codigo_zona: "Z001",
        capacidad_maxima: 50,
        fecha_registro: "2026-03-01T10:00:00Z",
        personas_alojadas: MapSet.new(["10949001", "10949002"])
      })

    assert {:ok, linea_alb} = CodificadorTexto.codificar(alb)
    assert {:ok, dec_alb} = CodificadorTexto.decodificar(linea_alb, :albergues)
    assert MapSet.member?(dec_alb.personas_alojadas, "10949001")
    assert MapSet.member?(dec_alb.personas_alojadas, "10949002")

    {:ok, act} =
      RegistroActividad.construir(%{
        id: "ACT001",
        usuario: "Laura",
        accion: "asignar_recurso",
        detalles: "Asigno 20 litros",
        fecha: "2026-03-01T10:00:00Z"
      })

    assert {:ok, linea_act} = CodificadorTexto.codificar(act)
    assert {:ok, dec_act} = CodificadorTexto.decodificar(linea_act, :actividad)
    assert dec_act.accion == "asignar_recurso"
  end
end
