defmodule Emergencias.Infraestructura.Entrada.Consola.Demostracion do
  @moduledoc "Escenarios ejecutables automatizados para sustentacion y demostracion del sistema."

  alias Emergencias.Infraestructura.Entrada.Consola.Despachador

  @doc "Simular el conflicto concurrente de dos asignaciones compitiendo por stock en paralelo."
  def simular_conflicto_recursos do
    IO.puts("=== ESCENARIO CONCURRENTE: 2 ASIGNACIONES SIMULTANEAS (30 L y 25 L sobre 50 L) ===")
    reiniciar_entorno()
    {:ok, _, laura} = Despachador.despachar(:connect, ["Laura", "coord123", "coordinador"], %{}, nil)
    _ = Despachador.despachar(:register_zone, ["Z001", "Centro", "critico"], %{}, laura)
    _ = Despachador.despachar(:register_resource, ["R001", "agua", "50", "litros", "Z001"], %{}, laura)
    _ = Despachador.despachar(:register_need, ["Z001", "agua", "30", "critica", "Hospital"], %{}, laura)
    _ = Despachador.despachar(:register_need, ["Z001", "agua", "25", "alta", "Refugio"], %{}, laura)

    IO.puts("Stock inicial R001: 50 L. Solicitud 1: 30 L (N001). Solicitud 2: 25 L (N002).")
    IO.puts("Lanzando tareas simultaneas con Task.async_stream...")

    resultados =
      [{"R001", "N001", "30"}, {"R001", "N002", "25"}]
      |> Task.async_stream(fn {r, n, cant} ->
        Despachador.despachar(:assign_resource, [r, n, cant], %{}, laura)
      end)
      |> Enum.map(fn {:ok, res} -> res end)

    confirmadas = Enum.filter(resultados, fn {tipo, _, _} -> tipo == :ok end)
    rechazadas = Enum.filter(resultados, fn {tipo, _, _} -> tipo == :error end)

    Enum.each(confirmadas, fn {:ok, msg, _} -> IO.puts("  * CONFIRMADA: #{msg}") end)
    Enum.each(rechazadas, fn {:error, err, _} -> IO.puts("  * RECHAZADA: #{err}") end)

    {:ok, rec} = Emergencias.Infraestructura.Procesos.GestorLogistica.consultar_recurso("R001")
    IO.puts("Stock final disponible de R001: #{rec.cantidad_disponible} L (esperado: 20 L)")

    if length(confirmadas) == 1 and length(rechazadas) == 1 and rec.cantidad_disponible == 20 do
      IO.puts("\n[DEMOSTRACION EXITOSA]: Serializacion atomica confirmada sin sobreasignacion ni perdida de stock.")
    else
      IO.puts("\n[FALLO]: El resultado concurrente no fue el esperado.")
    end
  end

  @doc "Simular el flujo completo del caso de estudio de Laura y todas las capacidades del sistema."
  def simular_flujo_laura do
    IO.puts("=== SIMULACION DEL FLUJO COMPLETO DE EMERGENCIAS (LAURA) ===")
    reiniciar_entorno()

    IO.puts("\n1. Conexion de Laura:")
    {:ok, msg, laura} = Despachador.despachar(:connect, ["Laura", "coord123", "coordinador"], %{}, nil)
    IO.puts(msg)

    IO.puts("\n2. Registro territorial jerarquico (Zonas, Sectores y Puntos):")
    {:ok, msg, _} = Despachador.despachar(:register_zone, ["Z001", "Centro", "critico"], %{personas: 50}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_zone, ["Z002", "Norte", "medio"], %{personas: 20}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_sector, ["Z001", "S001", "Comercial", "30"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_point, ["Z001", "S001", "PT01", "Puesto Salud", "15"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:zone_status, ["Z001"], %{}, laura)
    IO.puts(msg)

    IO.puts("\n3. Registro de suministros y necesidades:")
    {:ok, msg, _} = Despachador.despachar(:register_resource, ["R001", "agua", "50", "litros", "Z001"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_resource, ["R002", "agua", "20", "litros", "Z002"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_need, ["Z001", "agua", "30", "critica", "Hospital San Juan"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_need, ["Z001", "agua", "25", "alta", "Albergue Estadio"], %{}, laura)
    IO.puts(msg)

    IO.puts("\n4. Asignacion atomica y transferencia:")
    {:ok, msg, _} = Despachador.despachar(:assign_resource, ["R001", "N001", "30"], %{}, laura)
    IO.puts(msg)
    {:error, err, _} = Despachador.despachar(:assign_resource, ["R001", "N002", "25"], %{}, laura)
    IO.puts(err)
    {:ok, msg, _} = Despachador.despachar(:transfer_resource, ["R002", "Z002", "R001", "10"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:assign_resource, ["R001", "N002", "25"], %{}, laura)
    IO.puts(msg)

    IO.puts("\n5. Personas, censo y mensajeria familiar:")
    {:ok, msg, _} = Despachador.despachar(:report_person, ["10949001", "Carlos Lopez", "35", "Z001", "reportada"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:send_family_message, ["10949001", "Estamos a salvo en el punto de encuentro."], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:list_family_messages, ["10949001"], %{}, laura)
    IO.puts(msg)

    IO.puts("\n6. Albergues y control de aforo:")
    {:ok, msg, _} = Despachador.despachar(:register_shelter, ["Estadio San Jose", "Z001", "2"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_entry, ["ALB001", "10949001"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:register_entry, ["ALB001", "10949002"], %{}, laura)
    IO.puts(msg)
    {:error, err, _} = Despachador.despachar(:register_entry, ["ALB001", "10949003"], %{}, laura)
    IO.puts(err)
    {:ok, msg, _} = Despachador.despachar(:shelter_report, [], %{}, laura)
    IO.puts(msg)

    IO.puts("\n7. Mascotas, coincidencia y resolucion:")
    {:ok, msg, _} = Despachador.despachar(:report_pet, ["perdida", "perro", "dorado", "mediano", "Z001", "Rocky"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:report_pet, ["encontrada", "perro", "dorado", "mediano", "Z001", "Rocky"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:match_pets, ["60"], %{}, laura)
    IO.puts(msg)
    {:ok, msg, _} = Despachador.despachar(:confirm_match, ["MC001", "MC002"], %{}, laura)
    IO.puts(msg)

    IO.puts("\n8. Resumen ejecutivo final:")
    {:ok, msg, _} = Despachador.despachar(:summary, [], %{}, laura)
    IO.puts(msg)
    IO.puts("\nDemostracion completa finalizada con exito.")
  end

  defp reiniciar_entorno do
    dir = Application.get_env(:emergencias, :directorio_datos, "datos")
    File.mkdir_p!(dir)
    Enum.each(Path.wildcard("#{dir}/*.txt"), &File.write!(&1, ""))
    if :erlang.whereis(Emergencias.SupervisorRaiz) do
      Supervisor.stop(Emergencias.SupervisorRaiz)
      Process.sleep(50)
    end
    {:ok, _} = Emergencias.Application.iniciar_supervision()
  end
end
