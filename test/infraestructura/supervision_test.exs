defmodule Emergencias.Infraestructura.SupervisionTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Modelos.Albergue, as: ModeloAlbergue
  alias Emergencias.Infraestructura.Procesos.{
    Albergue,
    BitacoraActividad,
    GestorRecursos,
    SupervisorAlbergues
  }

  alias Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo

  @dir_prueba "datos_prueba_supervision"

  setup do
    File.rm_rf!(@dir_prueba)
    File.mkdir_p!(@dir_prueba)
    Application.put_env(:emergencias, :directorio_datos, @dir_prueba)

    # Limpiar estado en memoria
    GestorRecursos.recargar_datos()

    on_exit(fn ->
      File.rm_rf!(@dir_prueba)
      Application.put_env(:emergencias, :directorio_datos, "datos")
    end)

    :ok
  end

  test "tolerancia a fallos: matar GestorRecursos y verificar recuperacion desde disco" do
    # Registrar recurso
    params = %{tipo: "frazadas", unidad_medida: "unidades", cantidad_total: 80, codigo_zona: "Z001"}
    assert {:ok, r} = GestorRecursos.registrar_recurso(params, "Laura")
    id_recurso = r.id

    pid_antiguo = Process.whereis(GestorRecursos)
    assert is_pid(pid_antiguo)

    # Matar el proceso abruptamente
    Process.exit(pid_antiguo, :kill)
    :timer.sleep(150)

    # El supervisor debe haberlo reiniciado con un nuevo PID
    pid_nuevo = Process.whereis(GestorRecursos)
    assert is_pid(pid_nuevo)
    assert pid_nuevo != pid_antiguo

    # El nuevo proceso debio recargar los datos desde el archivo .txt
    assert {:ok, recuperado} = GestorRecursos.consultar_recurso(id_recurso)
    assert recuperado.id == id_recurso
    assert recuperado.cantidad_disponible == 80
  end

  test "proceso puro BitacoraActividad acumula eventos y responde consultas" do
    BitacoraActividad.registrar_actividad("Laura", "LOGIN", "Acceso al sistema", "2026-03-01T10:00:00Z")
    BitacoraActividad.registrar_actividad("Carlos", "REGISTRO", "Nuevo voluntario", "2026-03-01T10:05:00Z")

    :timer.sleep(50)
    eventos = BitacoraActividad.consultar_actividad()
    assert length(eventos) >= 2
    assert Enum.any?(eventos, fn e -> e.usuario == "Laura" and e.accion == "LOGIN" end)
  end

  test "proceso puro Albergue bajo DynamicSupervisor atiende mensajes sincronicos" do
    {:ok, alb} =
      ModeloAlbergue.construir(%{
        id: "ALB_SUP_01",
        nombre: "Refugio Sur",
        codigo_zona: "Z001",
        capacidad_maxima: 2,
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    # Guardar en persistencia e iniciar en el DynamicSupervisor
    AlmacenArchivo.guardar(:albergues, alb)
    {:ok, _pid} = SupervisorAlbergues.iniciar_albergue(alb)

    # Enviar mensajes sincrónicos al proceso puro del albergue
    assert {:ok, alb_ocupado} = Albergue.ingresar_persona(alb.id, "10949001")
    assert MapSet.member?(alb_ocupado.personas_alojadas, "10949001")

    # Consultar estado en memoria del proceso
    assert {:ok, alb_consultado} = Albergue.consultar(alb.id)
    assert MapSet.member?(alb_consultado.personas_alojadas, "10949001")

    # Salida
    assert {:ok, alb_salida} = Albergue.retirar_persona(alb.id, "10949001")
    assert MapSet.size(alb_salida.personas_alojadas) == 0
  end
end
