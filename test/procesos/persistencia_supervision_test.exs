defmodule Emergencias.Procesos.PersistenciaSupervisionTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Modelos.Persona
  alias Emergencias.Infraestructura.Procesos.GestorPersonas
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  setup do
    dir = Path.join(System.tmp_dir!(), "emergencias_persist_#{System.unique_integer([:positive])}")
    Application.put_env(:emergencias, :directorio_datos, dir)
    File.mkdir_p!(dir)

    if Process.whereis(Emergencias.SupervisorRaiz) do
      Supervisor.stop(Emergencias.SupervisorRaiz)
      Process.sleep(30)
    end
    {:ok, _} = Emergencias.Application.iniciar_supervision()

    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "persistencia ida y vuelta con tildes y eñes" do
    persona = %Persona{documento: "10949001", nombre: "José Peña", edad: 40, zona: "Cañón del Combeima", estado: :reportada}
    assert :ok = AlmacenArchivo.guardar(:prueba_tildes, [persona])
    assert [cargado] = AlmacenArchivo.cargar(:prueba_tildes)
    assert cargado.nombre == "José Peña"
    assert cargado.zona == "Cañón del Combeima"
  end

  test "tolerancia a archivo corrupto devuelve lista vacia sin lanzar excepcion", %{dir: dir} do
    ruta = Path.join(dir, "corrupto.txt")
    File.write!(ruta, "%%% ESTO NO ES UN TERMINO ERLANG VALIDO {[[[")
    assert AlmacenArchivo.cargar(:corrupto) == []
  end

  test "supervision reinicia gestor al matarlo y recupera estado persistido" do
    {:ok, p} = GestorPersonas.reportar(%{documento: "10949002", nombre: "Maria Gómez", edad: 30, zona: "Z1"})
    pid_original = Process.whereis(GestorPersonas)
    assert is_pid(pid_original)

    # Matar el proceso abruptamente
    Process.exit(pid_original, :kill)
    Process.sleep(50)

    pid_nuevo = Process.whereis(GestorPersonas)
    assert is_pid(pid_nuevo)
    assert pid_nuevo != pid_original

    # Recupera su estado desde disco
    assert {:ok, recuperada} = GestorPersonas.buscar("10949002")
    assert recuperada.nombre == p.nombre
  end
end
