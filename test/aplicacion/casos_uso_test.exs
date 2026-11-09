defmodule Emergencias.Aplicacion.CasosUsoTest do
  use ExUnit.Case, async: false

  alias Emergencias.Aplicacion.CasosUso.{
    GenerarResumenes,
    GestionarAlbergues,
    GestionarFamiliares,
    GestionarMascotas,
    GestionarNecesidades,
    GestionarRecursos,
    GestionarUsuarios,
    GestionarZonas
  }

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Soporte.RepositorioMemoria

  setup do
    RepositorioMemoria.limpiar()

    on_exit(fn ->
      RepositorioMemoria.limpiar()
    end)

    {:ok, admin} =
      Usuario.construir(%{
        id: "U001",
        nombre: "Admin",
        rol: :administrador,
        clave_hash: GestionarUsuarios.calcular_hash_clave("secreto"),
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, coord} =
      Usuario.construir(%{
        id: "U002",
        nombre: "Laura",
        rol: :coordinador,
        clave_hash: GestionarUsuarios.calcular_hash_clave("coord123"),
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, voluntario} =
      Usuario.construir(%{
        id: "U003",
        nombre: "Carlos",
        rol: :voluntario,
        clave_hash: GestionarUsuarios.calcular_hash_clave("vol123"),
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, ciudadano} =
      Usuario.construir(%{
        id: "U004",
        nombre: "Pedro",
        rol: :ciudadano,
        clave_hash: GestionarUsuarios.calcular_hash_clave("ciu123"),
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    RepositorioMemoria.guardar(:usuarios, [admin, coord, voluntario, ciudadano])

    %{
      admin: admin,
      coord: coord,
      voluntario: voluntario,
      ciudadano: ciudadano,
      opts: [repositorio: RepositorioMemoria]
    }
  end

  test "gestionar_usuarios: conectar existente y registrar nuevo", %{opts: opts} do
    # Login exitoso
    assert {:ok, %Usuario{} = u} = GestionarUsuarios.conectar("Laura", "coord123", :coordinador, opts)
    assert u.nombre == "Laura"

    # Clave incorrecta
    assert {:error, :clave_incorrecta} = GestionarUsuarios.conectar("Laura", "erronea", :coordinador, opts)

    # Nuevo usuario se registra automaticamente con hash sha256
    assert {:ok, %Usuario{} = nuevo} = GestionarUsuarios.conectar("NuevoVoluntario", "claveSegura", :voluntario, opts)
    assert nuevo.rol == :voluntario
    assert nuevo.clave_hash != "claveSegura"
    assert byte_size(nuevo.clave_hash) == 64

    # Desconectar
    assert :ok == GestionarUsuarios.desconectar("Laura", opts)
  end

  test "gestionar_zonas: autorizacion y registro", %{coord: coord, ciudadano: ciudadano, opts: opts} do
    # Ciudadano no tiene permiso para crear zona
    assert {:error, :sin_permiso} =
             GestionarZonas.registrar_zona(%{nombre: "Zona Sur", nivel_gravedad: :alto}, ciudadano, opts)

    # Coordinador si tiene permiso
    assert {:ok, zona} =
             GestionarZonas.registrar_zona(%{nombre: "Zona Sur", nivel_gravedad: :alto}, coord, opts)

    assert zona.id == "Z001"

    # Consultar y listar
    assert {:ok, consultada} = GestionarZonas.consultar_zona("Z001", coord, opts)
    assert consultada.nombre == "Zona Sur"

    assert {:ok, lista} = GestionarZonas.listar_zonas(coord, opts)
    assert length(lista) == 1
  end

  test "gestionar_necesidades: reporte, filtros y transicion de estados", %{
    ciudadano: ciu,
    coord: coord,
    opts: opts
  } do
    # Ciudadano registra necesidad
    params = %{
      codigo_zona: "Z001",
      tipo_recurso: "agua",
      cantidad_solicitada: 100,
      prioridad: :critica
    }

    assert {:ok, nec} = GestionarNecesidades.registrar_necesidad(params, ciu, opts)
    assert nec.id == "N001"
    assert nec.estado == :pendiente

    # Listar con filtro de zona y prioridad
    assert {:ok, [n_filtrada]} =
             GestionarNecesidades.listar_necesidades([zona: "Z001", prioridad: :critica], ciu, opts)

    assert n_filtrada.id == "N001"

    # Actualizar estado a :asignada
    assert {:ok, nec_asig} =
             GestionarNecesidades.actualizar_necesidad("N001", :asignada, coord, opts)

    assert nec_asig.estado == :asignada
  end

  test "gestionar_recursos: inventario, asignacion y transferencia", %{
    voluntario: vol,
    coord: coord,
    opts: opts
  } do
    # Voluntario registra recursos
    params1 = %{tipo: "agua", unidad_medida: "litros", cantidad_total: 50, codigo_zona: "Z001"}
    params2 = %{tipo: "agua", unidad_medida: "litros", cantidad_total: 20, codigo_zona: "Z002"}

    assert {:ok, r1} = GestionarRecursos.registrar_recurso(params1, vol, opts)
    assert {:ok, r2} = GestionarRecursos.registrar_recurso(params2, vol, opts)

    assert r1.id == "R001"
    assert r2.id == "R002"

    # Asignar 30 litros de R001 a N001
    assert {:ok, {r1_act, mov}} =
             GestionarRecursos.asignar_recurso("R001", "N001", 30, coord, opts)

    assert r1_act.cantidad_disponible == 20
    assert mov.tipo_movimiento == :asignacion

    # Transferir 10 litros de R001 a R002
    assert {:ok, {origen, destino}} =
             GestionarRecursos.transferir_recurso("R001", "R002", 10, coord, opts)

    assert origen.cantidad_disponible == 10
    assert destino.cantidad_disponible == 30
  end

  test "gestionar_familiares: reporte de persona y mensajeria", %{ciudadano: ciu, coord: coord, opts: opts} do
    params = %{documento: "10949001", nombre_completo: "Carlos Lopez"}
    assert {:ok, p} = GestionarFamiliares.reportar_persona(params, ciu, opts)
    assert p.id == "P001"

    # Buscar persona
    assert {:ok, encontrada} = GestionarFamiliares.buscar_persona("10949001", ciu, opts)
    assert encontrada.nombre_completo == "Carlos Lopez"

    # Enviar mensaje familiar
    assert {:ok, msg} =
             GestionarFamiliares.enviar_mensaje("10949001", "Estamos a salvo en el parque", ciu, opts)

    assert msg.documento_persona == "10949001"

    # Listar mensajes
    assert {:ok, [m]} = GestionarFamiliares.listar_mensajes("10949001", ciu, opts)
    assert m.contenido == "Estamos a salvo en el parque"

    # Actualizar estado de persona
    assert {:ok, p_loc} =
             GestionarFamiliares.actualizar_persona("10949001", :localizada, %{ubicacion_actual: "Hospital"}, coord, opts)

    assert p_loc.estado == :localizada
  end

  test "gestionar_mascotas: reportes, emparejamiento y resolucion", %{
    ciudadano: ciu,
    coord: coord,
    opts: opts
  } do
    p_perdida = %{
      tipo_reporte: :perdida,
      especie: "perro",
      nombre: "Max",
      color: "negro",
      tamano: :grande,
      codigo_zona: "Z001",
      caracteristicas: ["mancha blanca"]
    }

    p_encontrada = %{
      tipo_reporte: :encontrada,
      especie: "perro",
      nombre: "Max",
      color: "negro",
      tamano: :grande,
      codigo_zona: "Z001",
      caracteristicas: ["mancha blanca"]
    }

    assert {:ok, m1} = GestionarMascotas.reportar_mascota(p_perdida, ciu, opts)
    assert {:ok, m2} = GestionarMascotas.reportar_mascota(p_encontrada, ciu, opts)

    # Emparejar con similitud
    assert {:ok, [{rep_perdida, rep_hallada, puntaje}]} =
             GestionarMascotas.emparejar_mascotas(coord, opts)

    assert rep_perdida.id == m1.id
    assert rep_hallada.id == m2.id
    assert puntaje == 100

    # Resolver caso de mascota
    assert {:ok, resuelta} = GestionarMascotas.resolver_mascota(m1.id, coord, opts)
    assert resuelta.estado == :resuelta
  end

  test "gestionar_albergues: control de ocupacion y aforo", %{
    coord: coord,
    voluntario: vol,
    opts: opts
  } do
    params = %{nombre: "Coliseo del Cafe", codigo_zona: "Z001", capacidad_maxima: 1}
    assert {:ok, alb} = GestionarAlbergues.registrar_albergue(params, coord, opts)

    # Ingreso de persona
    assert {:ok, alb_ingresado} =
             GestionarAlbergues.registrar_entrada(alb.id, "10949001", vol, opts)

    assert MapSet.member?(alb_ingresado.personas_alojadas, "10949001")

    # Intentar sobrepasar cupo
    assert {:error, :sin_cupo} =
             GestionarAlbergues.registrar_entrada(alb.id, "10949002", vol, opts)

    # Salida de persona
    assert {:ok, alb_egreso} =
             GestionarAlbergues.registrar_salida(alb.id, "10949001", vol, opts)

    assert MapSet.size(alb_egreso.personas_alojadas) == 0
  end

  test "generar_resumenes: resumen, recursos criticos y merge sort de necesidades", %{
    admin: admin,
    opts: opts
  } do
    # Sembrar recursos
    r_critico = %Emergencias.Dominio.Modelos.Recurso{
      id: "R001",
      tipo: "gasas",
      unidad_medida: "paquetes",
      cantidad_total: 5,
      cantidad_disponible: 5,
      cantidad_reservada: 0,
      codigo_zona: "Z001",
      fecha_registro: "2026-03-01T10:00:00Z"
    }

    r_abundante = %Emergencias.Dominio.Modelos.Recurso{
      id: "R002",
      tipo: "agua",
      unidad_medida: "litros",
      cantidad_total: 500,
      cantidad_disponible: 500,
      cantidad_reservada: 0,
      codigo_zona: "Z001",
      fecha_registro: "2026-03-01T10:00:00Z"
    }

    # Sembrar necesidades con distintas prioridades para merge sort
    n_media = %Emergencias.Dominio.Modelos.Necesidad{
      id: "N001",
      codigo_zona: "Z001",
      tipo_recurso: "agua",
      cantidad_solicitada: 10,
      cantidad_asignada: 0,
      prioridad: :media,
      estado: :pendiente,
      fecha_registro: "2026-03-01T10:00:00Z",
      usuario_reporta: "Pedro",
      historial: []
    }

    n_critica = %Emergencias.Dominio.Modelos.Necesidad{
      id: "N002",
      codigo_zona: "Z001",
      tipo_recurso: "suero",
      cantidad_solicitada: 20,
      cantidad_asignada: 0,
      prioridad: :critica,
      estado: :pendiente,
      fecha_registro: "2026-03-01T10:05:00Z",
      usuario_reporta: "Pedro",
      historial: []
    }

    RepositorioMemoria.guardar(:recursos, [r_critico, r_abundante])
    RepositorioMemoria.guardar(:necesidades, [n_media, n_critica])

    # 1. Resumen consolidado
    assert {:ok, summary} = GenerarResumenes.generar_resumen(admin, opts)
    assert summary.total_recursos_disponibles == 505
    assert summary.necesidades_pendientes == 2

    # 2. Recursos criticos (umbral <= 20)
    assert {:ok, [critico]} = GenerarResumenes.listar_recursos_criticos(20, admin, opts)
    assert critico.id == "R001"

    # 3. Necesidades pendientes ordenadas por prioridad desc (Merge Sort)
    assert {:ok, [primera, segunda]} = GenerarResumenes.listar_necesidades_pendientes(admin, opts)
    assert primera.id == "N002"
    assert primera.prioridad == :critica
    assert segunda.id == "N001"
    assert segunda.prioridad == :media
  end
end
