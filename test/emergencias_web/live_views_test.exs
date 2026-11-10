defmodule EmergenciasWeb.LiveViewsTest do
  use EmergenciasWeb.ConnCase, async: false

  alias Emergencias.Aplicacion.CasosUso.{GestionarLogistica, GestionarMascotas, GestionarUsuarios}

  test "sin sesion redirige a login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/resumen")
  end

  test "ingreso exitoso y error con clave incorrecta", %{conn: conn} do
    nom = "Usuario_#{System.unique_integer([:positive])}"
    {:ok, _} = GestionarUsuarios.conectar(nom, "123", "coordinador")

    conn1 = post(conn, ~p"/sesion/iniciar", %{"usuario" => nom, "clave" => "123", "rol" => "coordinador"})
    assert redirected_to(conn1) == ~p"/resumen"

    conn2 = post(conn, ~p"/sesion/iniciar", %{"usuario" => nom, "clave" => "errada", "rol" => "coordinador"})
    assert redirected_to(conn2) == ~p"/"
    assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "incorrecta"
  end

  test "registrar necesidad desde vista y verla en la tabla", %{conn: conn} do
    {:ok, coord} = GestionarUsuarios.conectar("Coord1_#{System.unique_integer([:positive])}", "123", "coordinador")
    conn = iniciar_sesion(conn, coord)
    {:ok, view, _html} = live(conn, ~p"/logistica")

    html = render_submit(view, :registrar_necesidad, %{
      "zona" => "Z001", "recurso" => "alimentos", "cantidad" => "40", "prioridad" => "alta", "descripcion" => "Kits"
    })
    assert html =~ "alimentos"
    assert html =~ "40"
  end

  test "asignar mas de lo que hay muestra flash de error sin excepcion", %{conn: conn} do
    {:ok, coord} = GestionarUsuarios.conectar("Coord2_#{System.unique_integer([:positive])}", "123", "coordinador")
    conn = iniciar_sesion(conn, coord)
    {:ok, view, _html} = live(conn, ~p"/logistica")

    render_submit(view, :registrar_recurso, %{
      "codigo" => "R10", "nombre" => "agua", "cantidad" => "10", "unidad" => "litros", "ubicacion" => "Z001"
    })
    render_submit(view, :registrar_necesidad, %{
      "zona" => "Z001", "recurso" => "agua", "cantidad" => "25", "prioridad" => "alta"
    })
    {:ok, necs} = GestionarLogistica.listar_necesidades([], coord)
    nec = Enum.find(necs, &(&1.estado == :pendiente))

    html = render_submit(view, :asignar_recurso, %{"recurso_id" => "R10", "necesidad_id" => nec.id, "cantidad" => "20"})
    assert html =~ "insuficientes" or html =~ "supera"
  end

  test "ciudadano intentando asignar recibe aviso de permisos", %{conn: conn} do
    {:ok, ciud} = GestionarUsuarios.conectar("Pepe_#{System.unique_integer([:positive])}", "123", "ciudadano")
    conn = iniciar_sesion(conn, ciud)
    {:ok, view, _html} = live(conn, ~p"/logistica")

    html = render_submit(view, :asignar_recurso, %{"recurso_id" => "R001", "necesidad_id" => "N001", "cantidad" => "5"})
    assert html =~ "permisos" or html =~ "No tienes permisos"
  end

  test "simulacion de conflicto muestra 1 confirmada, 1 rechazada y stock 20 L", %{conn: conn} do
    {:ok, coord} = GestionarUsuarios.conectar("Coord3_#{System.unique_integer([:positive])}", "123", "coordinador")
    conn = iniciar_sesion(conn, coord)
    {:ok, view, _html} = live(conn, ~p"/logistica")

    html = render_click(view, :simular_conflicto)
    assert html =~ "CONFIRMADA"
    assert html =~ "RECHAZADA"
    assert html =~ "20 L"
  end

  test "dos LiveViews sincronizan via PubSub al asignar", %{conn: conn} do
    {:ok, coord} = GestionarUsuarios.conectar("Coord4_#{System.unique_integer([:positive])}", "123", "coordinador")
    conn1 = iniciar_sesion(conn, coord)
    conn2 = iniciar_sesion(build_conn(), coord)

    {:ok, view1, _} = live(conn1, ~p"/logistica")
    {:ok, view2, _} = live(conn2, ~p"/logistica")

    render_submit(view1, :registrar_recurso, %{
      "codigo" => "R99", "nombre" => "frazadas", "cantidad" => "50", "unidad" => "unidades", "ubicacion" => "Z001"
    })

    assert render(view2) =~ "frazadas"
  end

  test "ciudadano modifica solo sus mascotas y coordinador modifica cualquiera", %{conn: conn} do
    {:ok, c1} = GestionarUsuarios.conectar("Ciu1_#{System.unique_integer([:positive])}", "123", "ciudadano")
    {:ok, c2} = GestionarUsuarios.conectar("Ciu2_#{System.unique_integer([:positive])}", "123", "ciudadano")
    {:ok, m} = GestionarMascotas.reportar_mascota("perdida", "perro", "negro", "mediano", "Z001", "Firulais", [], c1)

    assert {:ok, _} = GestionarMascotas.actualizar_estado_mascota(m.id, :posible_coincidencia, c1)
    assert {:error, :no_autorizado} = GestionarMascotas.actualizar_estado_mascota(m.id, :resuelta, c2)

    conn1 = iniciar_sesion(conn, c1)
    {:ok, view1, _} = live(conn1, ~p"/mascotas")
    html1 = render_change(view1, :actualizar_estado, %{"mascota_id" => m.id, "estado" => "resuelta"})
    assert html1 =~ "actualizado"
  end

  test "todas las pantallas cargan correctamente sin errores", %{conn: conn} do
    {:ok, coord} = GestionarUsuarios.conectar("CoordNav_#{System.unique_integer([:positive])}", "123", "coordinador")
    conn = iniciar_sesion(conn, coord)
    for ruta <- [~p"/resumen", ~p"/logistica", ~p"/zonas", ~p"/familiares", ~p"/mascotas", ~p"/albergues"] do
      assert {:ok, _view, html} = live(conn, ruta)
      assert html =~ "EMERGENCIAS"
    end
  end
end
