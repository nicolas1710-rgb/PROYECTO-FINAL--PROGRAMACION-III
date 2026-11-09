defmodule Emergencias.Infraestructura.ConcurrenciaTest do
  use ExUnit.Case, async: false

  alias Emergencias.Infraestructura.Procesos.{
    GestorMascotas,
    GestorNecesidades,
    GestorRecursos
  }

  alias Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo

  @dir_prueba "datos_prueba_concurrencia"

  setup do
    File.rm_rf!(@dir_prueba)
    File.mkdir_p!(@dir_prueba)
    Application.put_env(:emergencias, :directorio_datos, @dir_prueba)

    # Reiniciar estado limpio en disco
    AlmacenArchivo.guardar(:recursos, [])
    AlmacenArchivo.guardar(:movimientos, [])
    AlmacenArchivo.guardar(:necesidades, [])
    AlmacenArchivo.guardar(:mascotas, [])

    # Recargar datos en los gestores
    GestorRecursos.recargar_datos()
    GestorNecesidades.recargar_datos()
    GestorMascotas.recargar_datos()

    on_exit(fn ->
      File.rm_rf!(@dir_prueba)
      Application.put_env(:emergencias, :directorio_datos, "datos")
    end)

    :ok
  end

  test "escenario clave: 30 y 25 litros simultaneos sobre 50 disponibles" do
    # 1. Registrar recurso con 50 litros disponibles
    params = %{tipo: "agua", unidad_medida: "litros", cantidad_total: 50, codigo_zona: "Z001"}
    assert {:ok, r} = GestorRecursos.registrar_recurso(params, "Laura")
    id_recurso = r.id

    # 2. Dos tareas concurrentes intentando tomar 30 y 25 litros al mismo tiempo
    tarea1 = Task.async(fn -> GestorRecursos.asignar_recurso(id_recurso, "N001", 30, "Laura") end)
    tarea2 = Task.async(fn -> GestorRecursos.asignar_recurso(id_recurso, "N002", 25, "Carlos") end)

    res1 = Task.await(tarea1)
    res2 = Task.await(tarea2)

    # Uno debe haber tenido exito y el otro debe fallar por cantidad insuficiente
    assert (match?({:ok, _}, res1) and res2 == {:error, :cantidad_insuficiente}) or
             (match?({:ok, _}, res2) and res1 == {:error, :cantidad_insuficiente})

    # El saldo final debe ser consistente (20 si gano el de 30, o 25 si gano el de 25) y NUNCA negativo
    {:ok, r_final} = GestorRecursos.consultar_recurso(id_recurso)
    assert r_final.cantidad_disponible in [20, 25]
    assert r_final.cantidad_disponible >= 0
  end

  test "prueba de estres concurrente: 100 tareas asignando sobre 50 unidades disponibles" do
    params = %{tipo: "suero", unidad_medida: "unidades", cantidad_total: 50, codigo_zona: "Z001"}
    {:ok, r} = GestorRecursos.registrar_recurso(params, "Laura")
    id_recurso = r.id

    # 100 tareas compitiendo en paralelo intentando tomar 1 unidad cada una
    resultados =
      1..100
      |> Task.async_stream(
        fn i ->
          GestorRecursos.asignar_recurso(id_recurso, "N_TEST_#{i}", 1, "Usuario_#{i}")
        end,
        max_concurrency: 50,
        timeout: 10000
      )
      |> Enum.map(fn {:ok, res} -> res end)

    exitosos = Enum.count(resultados, fn res -> match?({:ok, _}, res) end)
    fallidos = Enum.count(resultados, fn res -> res == {:error, :cantidad_insuficiente} end)

    # Exactamente 50 deben tener exito y 50 deben fallar
    assert exitosos == 50
    assert fallidos == 50

    # Stock final en 0 exacto, sin saldos negativos
    {:ok, r_final} = GestorRecursos.consultar_recurso(id_recurso)
    assert r_final.cantidad_disponible == 0
    assert r_final.cantidad_reservada == 50
  end

  test "doble cierre concurrente sobre la misma necesidad" do
    params = %{
      codigo_zona: "Z001",
      tipo_recurso: "agua",
      cantidad_solicitada: 10,
      prioridad: :alta
    }

    assert {:ok, nec} = GestorNecesidades.registrar_necesidad(params, "Laura")
    {:ok, _} = GestorNecesidades.actualizar_estado(nec.id, :asignada, "Laura")
    {:ok, _} = GestorNecesidades.actualizar_estado(nec.id, :en_atencion, "Laura")

    t1 = Task.async(fn -> GestorNecesidades.actualizar_estado(nec.id, :atendida, "Laura") end)
    t2 = Task.async(fn -> GestorNecesidades.actualizar_estado(nec.id, :atendida, "Carlos") end)

    r1 = Task.await(t1)
    r2 = Task.await(t2)

    assert (match?({:ok, _}, r1) and r2 == {:error, :ya_cerrada}) or
             (match?({:ok, _}, r2) and r1 == {:error, :ya_cerrada})
  end

  test "doble cierre concurrente sobre el mismo reporte de mascota" do
    params = %{
      tipo_reporte: :perdida,
      especie: "perro",
      color: "negro",
      tamano: :mediano,
      codigo_zona: "Z001"
    }

    assert {:ok, pet} = GestorMascotas.reportar_mascota(params, "Laura")

    t1 = Task.async(fn -> GestorMascotas.resolver_mascota(pet.id, "Laura") end)
    t2 = Task.async(fn -> GestorMascotas.resolver_mascota(pet.id, "Carlos") end)

    r1 = Task.await(t1)
    r2 = Task.await(t2)

    assert (match?({:ok, _}, r1) and r2 == {:error, :ya_cerrada}) or
             (match?({:ok, _}, r2) and r1 == {:error, :ya_cerrada})
  end
end
