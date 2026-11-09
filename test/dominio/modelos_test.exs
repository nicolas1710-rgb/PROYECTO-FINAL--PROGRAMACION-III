defmodule Emergencias.Dominio.ModelosTest do
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

  test "construir usuario correctamente" do
    params = %{
      id: "U001",
      nombre: "Laura Coordinadora",
      rol: :coordinador,
      clave_hash: "hash_secreto",
      fecha_registro: "2026-03-01T10:00:00Z"
    }

    assert {:ok, %Usuario{} = u} = Usuario.construir(params)
    assert u.id == "U001"
    assert u.rol == :coordinador
  end

  test "construir jerarquia de zona, sector y punto de atencion" do
    assert {:ok, %PuntoAtencion{} = p} =
             PuntoAtencion.construir(%{
               id: "PT001",
               nombre: "Hospital de Campaña",
               personas_afectadas: 15
             })

    assert {:ok, %Sector{} = s} =
             Sector.construir(%{
               id: "S001",
               nombre: "Sector Norte",
               puntos_atencion: [p]
             })

    assert {:ok, %Zona{} = z} =
             Zona.construir(%{
               id: "Z001",
               nombre: "Centro",
               nivel_gravedad: :critico,
               fecha_registro: "2026-03-01T10:00:00Z",
               sectores: [s]
             })

    assert z.nivel_gravedad == :critico
    assert length(z.sectores) == 1
  end

  test "construir necesidad con valores por defecto" do
    params = %{
      id: "N001",
      codigo_zona: "Z001",
      tipo_recurso: "agua",
      cantidad_solicitada: 100,
      prioridad: :critica,
      estado: :pendiente,
      fecha_registro: "2026-03-01T10:00:00Z",
      usuario_reporta: "U001"
    }

    assert {:ok, %Necesidad{} = n} = Necesidad.construir(params)
    assert n.cantidad_asignada == 0
    assert n.historial == []
  end

  test "construir recurso y movimiento de inventario" do
    assert {:ok, %Recurso{} = r} =
             Recurso.construir(%{
               id: "R001",
               tipo: "agua",
               unidad_medida: "litros",
               cantidad_total: 500,
               codigo_zona: "Z001",
               fecha_registro: "2026-03-01T10:00:00Z"
             })

    assert r.cantidad_disponible == 500
    assert r.cantidad_reservada == 0

    assert {:ok, %MovimientoInventario{} = m} =
             MovimientoInventario.construir(%{
               id: "MOV001",
               codigo_recurso: "R001",
               tipo_movimiento: :entrada,
               cantidad: 500,
               origen: "Donacion Central",
               destino: "Z001",
               fecha: "2026-03-01T10:00:00Z",
               usuario_responsable: "U001"
             })

    assert m.tipo_movimiento == :entrada
  end

  test "construir persona, mensaje, mascota, albergue y actividad" do
    assert {:ok, %Persona{} = per} =
             Persona.construir(%{
               id: "P001",
               documento: "10949001",
               nombre_completo: "Carlos Gomez",
               estado: :reportada,
               fecha_reporte: "2026-03-01T10:00:00Z"
             })

    assert per.ubicacion_actual == "desconocida"

    assert {:ok, %Mensaje{} = msg} =
             Mensaje.construir(%{
               id: "M001",
               documento_persona: "10949001",
               remitente: "Hermana Maria",
               contenido: "Estamos en el albergue Central",
               fecha_envio: "2026-03-01T10:05:00Z"
             })

    assert msg.remitente == "Hermana Maria"

    assert {:ok, %ReporteMascota{} = pet} =
             ReporteMascota.construir(%{
               id: "MC001",
               tipo_reporte: :perdida,
               especie: "perro",
               color: "dorado",
               tamano: :mediano,
               codigo_zona: "Z001",
               estado: :activa,
               usuario_reporta: "U001",
               fecha_registro: "2026-03-01T10:10:00Z"
             })

    assert pet.estado == :activa

    assert {:ok, %Albergue{} = alb} =
             Albergue.construir(%{
               id: "ALB001",
               nombre: "Estadio San Jose",
               codigo_zona: "Z001",
               capacidad_maxima: 200,
               fecha_registro: "2026-03-01T10:00:00Z"
             })

    assert MapSet.size(alb.personas_alojadas) == 0

    assert {:ok, %RegistroActividad{} = act} =
             RegistroActividad.construir(%{
               id: "ACT001",
               usuario: "U001",
               accion: "login",
               detalles: "Inicio de sesion exitoso",
               fecha: "2026-03-01T10:00:00Z"
             })

    assert act.usuario == "U001"
  end
end
