defmodule Emergencias.Infraestructura.ConsolaComandosTest do
  use ExUnit.Case, async: false

  alias Emergencias.Infraestructura.Entrada.Consola.Despachador

  setup do
    dir = Path.join(System.tmp_dir!(), "emergencias_consola_#{System.unique_integer([:positive])}")
    Application.put_env(:emergencias, :directorio_datos, dir)
    File.mkdir_p!(dir)

    if Process.whereis(Emergencias.SupervisorRaiz) do
      Supervisor.stop(Emergencias.SupervisorRaiz)
      Process.sleep(30)
    end
    {:ok, _} = Emergencias.Application.iniciar_supervision()

    {:ok, _, coord} = Despachador.despachar(:connect, ["Admin", "123", "coordinador"], %{}, nil)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, admin: coord}
  end

  test "entrada invalida 'abc' devuelve error controlado sin lanzar excepcion", %{admin: a} do
    assert {:error, msg, _} = Despachador.despachar(:register_resource, ["R1", "agua", "abc", "litros", "Z1"], %{}, a)
    assert String.contains?(msg, "Se esperaba un valor numerico") or String.contains?(msg, "entero")
  end

  test "comandos territoriales: zona, sector, punto, list_zones y zone_status", %{admin: a} do
    assert {:ok, _, _} = Despachador.despachar(:register_zone, ["Z001", "Centro", "critico"], %{personas: 50}, a)
    assert {:ok, _, _} = Despachador.despachar(:register_sector, ["Z001", "S001", "Comuna 1", "20"], %{}, a)
    assert {:ok, _, _} = Despachador.despachar(:register_point, ["Z001", "S001", "P001", "Carpa Roja", "10"], %{}, a)
    assert {:ok, tabla, _} = Despachador.despachar(:list_zones, [], %{}, a)
    assert String.contains?(tabla, "Centro")

    assert {:ok, st_msg, _} = Despachador.despachar(:zone_status, ["Z001"], %{}, a)
    assert String.contains?(st_msg, "Total Personas Afectadas: 80")
  end

  test "recursos con ubicacion y transfer_resource entre centros de apoyo", %{admin: a} do
    assert {:ok, _, _} = Despachador.despachar(:register_resource, ["R001", "agua", "50", "litros", "Z001"], %{categoria: "hidratacion"}, a)
    assert {:ok, _, _} = Despachador.despachar(:transfer_resource, ["R001", "Z001", "Z002", "15"], %{}, a)
    assert {:ok, tabla, _} = Despachador.despachar(:list_resources, [], %{}, a)
    assert String.contains?(tabla, "Z001")
    assert String.contains?(tabla, "Z002")
  end

  test "personas censo flexible y actualizacion de estado", %{admin: a} do
    assert {:ok, _, _} = Despachador.despachar(:report_person, ["10949001", "Carlos Lopez", "30", "Z001", "reportada"], %{}, a)
    assert {:ok, msg, _} = Despachador.despachar(:find_person, ["10949001"], %{}, a)
    assert String.contains?(msg, "Carlos Lopez")

    assert {:ok, _, _} = Despachador.despachar(:update_person, ["10949001", "localizada"], %{}, a)
    assert {:ok, msg_act, _} = Despachador.despachar(:find_person, [], %{estado: "localizada"}, a)
    assert String.contains?(msg_act, "Carlos Lopez")
  end

  test "albergues vinculacion de recursos necesidades y reporte ordenado", %{admin: a} do
    assert {:ok, _, _} = Despachador.despachar(:register_shelter, ["Albergue 1", "Z001", "10"], %{}, a)
    assert {:ok, _, _} = Despachador.despachar(:link_shelter_resource, ["ALB001", "R001"], %{}, a)
    assert {:ok, _, _} = Despachador.despachar(:link_shelter_need, ["ALB001", "N001"], %{}, a)
    assert {:ok, rep, _} = Despachador.despachar(:shelter_report, [], %{}, a)
    assert String.contains?(rep, "Albergue 1")
  end

  test "confirm_match cierra ambos reportes de mascota", %{admin: a} do
    assert {:ok, _, _} = Despachador.despachar(:report_pet, ["perdida", "perro", "cafe", "mediano", "Z001", "Boby"], %{}, a)
    assert {:ok, _, _} = Despachador.despachar(:report_pet, ["encontrada", "perro", "cafe", "mediano", "Z001", "Boby"], %{}, a)
    assert {:ok, msg, _} = Despachador.despachar(:confirm_match, ["MC001", "MC002"], %{}, a)
    assert String.contains?(msg, "resueltos")
    assert {:error, _, _} = Despachador.despachar(:confirm_match, ["MC001", "MC002"], %{}, a)
  end
end
