defmodule Emergencias.Procesos.ConcurrenciaTest do
  use ExUnit.Case, async: false

  alias Emergencias.Infraestructura.Procesos.{GestorLogistica, GestorMascotas}

  setup do
    dir = Path.join(System.tmp_dir!(), "emergencias_test_#{System.unique_integer([:positive])}")
    Application.put_env(:emergencias, :directorio_datos, dir)
    File.mkdir_p!(dir)

    if Process.whereis(Emergencias.SupervisorRaiz) do
      Supervisor.stop(Emergencias.SupervisorRaiz)
      Process.sleep(30)
    end
    {:ok, _} = Emergencias.Application.iniciar_supervision()

    on_exit(fn ->
      File.rm_rf(dir)
    end)
    :ok
  end

  test "regresion del fallo grave: 10 tareas de 20L sobre necesidad de 30L con stock 100L" do
    {:ok, _} = GestorLogistica.registrar_recurso(%{id: "R_TEST", nombre: "agua", cantidad_total: 100, ubicacion: "Z1"})
    {:ok, _} = GestorLogistica.registrar_necesidad(%{id: "N_TEST", codigo_zona: "Z1", tipo_recurso: "agua", cantidad_solicitada: 30})

    resultados =
      1..10
      |> Task.async_stream(fn _ ->
        GestorLogistica.asignar("R_TEST", "N_TEST", 20, "Tester", "2026-11-09T00:00:00Z")
      end, max_concurrency: 10)
      |> Enum.map(fn {:ok, r} -> r end)

    exitos = Enum.filter(resultados, fn
      {:ok, _} -> true
      _ -> false
    end)

    assert length(exitos) == 1
    {:ok, rec} = GestorLogistica.consultar_recurso("R_TEST")
    assert rec.cantidad_disponible == 80
    {:ok, nec} = GestorLogistica.consultar_necesidad("N_TEST")
    assert nec.cantidad_asignada == 20
  end

  test "conflicto 30L y 25L simultaneos sobre 50L disponibles" do
    {:ok, _} = GestorLogistica.registrar_recurso(%{id: "R_50", nombre: "agua", cantidad_total: 50, ubicacion: "Z1"})
    {:ok, _} = GestorLogistica.registrar_necesidad(%{id: "N_30", codigo_zona: "Z1", tipo_recurso: "agua", cantidad_solicitada: 30})
    {:ok, _} = GestorLogistica.registrar_necesidad(%{id: "N_25", codigo_zona: "Z1", tipo_recurso: "agua", cantidad_solicitada: 25})

    resultados =
      [{"N_30", 30}, {"N_25", 25}]
      |> Task.async_stream(fn {n_id, cant} ->
        GestorLogistica.asignar("R_50", n_id, cant, "Tester", "2026-11-09T00:00:00Z")
      end)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, fn {:ok, _} -> true; _ -> false end) == 1
    assert Enum.count(resultados, fn {:error, :stock_insuficiente} -> true; _ -> false end) == 1
    {:ok, rec} = GestorLogistica.consultar_recurso("R_50")
    assert rec.cantidad_disponible in [20, 25]
  end

  test "100 tareas compitiendo sobre 50 unidades nunca dejan stock negativo" do
    {:ok, _} = GestorLogistica.registrar_recurso(%{id: "R_STRESS", nombre: "alimento", cantidad_total: 50, ubicacion: "Z1"})

    1..100
    |> Enum.each(fn i ->
      GestorLogistica.registrar_necesidad(%{id: "N_#{i}", codigo_zona: "Z1", tipo_recurso: "alimento", cantidad_solicitada: 1})
    end)

    resultados =
      1..100
      |> Task.async_stream(fn i ->
        GestorLogistica.asignar("R_STRESS", "N_#{i}", 1, "Tester", "2026-11-09T00:00:00Z")
      end, max_concurrency: 20)
      |> Enum.map(fn {:ok, r} -> r end)

    exitos = Enum.filter(resultados, fn {:ok, _} -> true; _ -> false end)
    assert length(exitos) == 50
    {:ok, rec} = GestorLogistica.consultar_recurso("R_STRESS")
    assert rec.cantidad_disponible == 0
  end

  test "doble cierre simultaneo de mascota solo permite un ok" do
    {:ok, _} = GestorMascotas.reportar(%{id: "M_P", tipo_reporte: :perdida, especie: "perro", color: "negro", tamano: :mediano, codigo_zona: "Z1"})
    {:ok, _} = GestorMascotas.reportar(%{id: "M_E", tipo_reporte: :encontrada, especie: "perro", color: "negro", tamano: :mediano, codigo_zona: "Z1"})

    resultados =
      1..2
      |> Task.async_stream(fn _ ->
        GestorMascotas.confirmar_coincidencia("M_P", "M_E", "Laura", "2026-11-09T00:00:00Z")
      end)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, fn {:ok, _} -> true; _ -> false end) == 1
    assert Enum.count(resultados, fn {:error, :ya_cerrada} -> true; _ -> false end) == 1
  end
end
