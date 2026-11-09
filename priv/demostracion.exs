# Demostración Automatizada del Sistema de Emergencias (Flujo Completo)
# Reproduce paso a paso el caso de estudio sin definir funciones.

# Reiniciar datos previos en disco y árbol de supervisión para que la demostración sea 100% reproducible
File.mkdir_p!("datos")
Enum.each(Path.wildcard("datos/*.txt"), fn archivo -> File.write!(archivo, "") end)
if Process.whereis(Emergencias.SupervisorRaiz) do
  Supervisor.stop(Emergencias.SupervisorRaiz)
  Process.sleep(100)
end
{:ok, _} = Emergencias.Application.iniciar_supervision()

alias Emergencias.Infraestructura.Entrada.DespachadorComandos

IO.puts("\n=== 1. CONEXIÓN DE LAURA (COORDINADORA) ===")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:connect, ["Laura", "coord123", "coordinador"], nil)
IO.puts(out)

IO.puts("\n=== 2. REGISTRO DE ZONAS Y ALBERGUE ===")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_zone, ["Centro", "critico"], laura)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_zone, ["Norte", "medio"], laura)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_shelter, ["Estadio San Jose", "Z001", "2"], laura)
IO.puts(out)

IO.puts("\n=== 3. INGRESO DE RECURSOS A INVENTARIO ===")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_resource, ["agua", "litros", "50", "Z001"], laura)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_resource, ["agua", "litros", "20", "Z002"], laura)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:list_resources, [], laura)
IO.puts(out)

IO.puts("\n=== 4. REPORTES DE NECESIDADES POR CIUDADANOS ===")
{:ok, out, pedro} = DespachadorComandos.despachar_comando(:connect, ["Pedro", "pass123", "ciudadano"], nil)
IO.puts(out)
{:ok, out, _} = DespachadorComandos.despachar_comando(:register_need, ["Z001", "agua", "30", "critica"], pedro)
IO.puts(out)

{:ok, out, maria} = DespachadorComandos.despachar_comando(:connect, ["Maria", "pass456", "ciudadano"], nil)
IO.puts(out)
{:ok, out, _} = DespachadorComandos.despachar_comando(:register_need, ["Z001", "agua", "25", "alta"], maria)
IO.puts(out)

IO.puts("\n=== 5. ASIGNACIÓN ATÓMICA Y CONFLICTO CONCURRENTE EN VIVO ===")
IO.puts("Stock inicial R001: 50 litros de agua.")
IO.puts("Lanzando 2 tareas simultáneas (Task.async_stream) intentando asignar 30 L (N001) y 25 L (N002)...")
IO.puts("Total requerido (55 L) supera el stock disponible (50 L).\n")

resultados_concurrencia =
  [{"N001", "30"}, {"N002", "25"}]
  |> Task.async_stream(fn {id_nec, cant} ->
    DespachadorComandos.despachar_comando(:assign_resource, ["R001", id_nec, cant], laura)
  end)
  |> Enum.map(fn {:ok, res} -> res end)

Enum.each(resultados_concurrencia, fn
  {:ok, msg, _} ->
    IO.puts("[CARRERA GANADA - PROCESADO]: " <> msg)

  {:error, err, _} ->
    IO.puts("[CARRERA RECHAZADA - STOCK INSUFICIENTE]: " <> err)
end)

{id_fallida, cant_fallida} =
  case resultados_concurrencia do
    [{:ok, _, _}, {:error, _, _}] -> {"N002", "25"}
    [{:error, _, _}, {:ok, _, _}] -> {"N001", "30"}
  end

IO.puts("\n--- Transferencia atómica de 10 L desde R002 a R001 para solventar el déficit ---")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:transfer_resource, ["R002", "R001", "10"], laura)
IO.puts(out)

IO.puts("\n--- Reintento de asignación para la necesidad #{id_fallida} (#{cant_fallida} L) ---")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:assign_resource, ["R001", id_fallida, cant_fallida], laura)
IO.puts(out)

IO.puts("\n=== 6. FAMILIARES Y MENSAJERÍA ===")
{:ok, _, pedro_sesion} = DespachadorComandos.despachar_comando(:connect, ["Pedro", "pass123", "ciudadano"], nil)
{:ok, out, _} = DespachadorComandos.despachar_comando(:report_person, ["10949001", "Carlos Lopez"], pedro_sesion)
IO.puts(out)

{:ok, _, maria_sesion} = DespachadorComandos.despachar_comando(:connect, ["Maria", "pass456", "ciudadano"], nil)
{:ok, out, _} = DespachadorComandos.despachar_comando(:send_family_message, ["10949001", "Estamos todos bien en el refugio"], maria_sesion)
IO.puts(out)

{:ok, out, _} = DespachadorComandos.despachar_comando(:list_family_messages, ["10949001"], pedro_sesion)
IO.puts(out)

IO.puts("\n=== 7. CONTROL DE AFORO EN ALBERGUES ===")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_entry, ["ALB001", "10949001"], laura)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:register_entry, ["ALB001", "10949002"], laura)
IO.puts(out)

{:error, err, laura} = DespachadorComandos.despachar_comando(:register_entry, ["ALB001", "10949003"], laura)
IO.puts(err)

{:ok, out, laura} = DespachadorComandos.despachar_comando(:check_shelter, ["ALB001"], laura)
IO.puts(out)

IO.puts("\n=== 8. REPORTE Y SIMILITUD DE MASCOTAS (MATCH_PETS) ===")
{:ok, out, _} = DespachadorComandos.despachar_comando(:report_pet, ["perdida", "perro", "dorado", "mediano", "Z001", "Rocky"], pedro_sesion)
IO.puts(out)
{:ok, out, _} = DespachadorComandos.despachar_comando(:report_pet, ["encontrada", "perro", "dorado", "mediano", "Z001", "Rocky"], maria_sesion)
IO.puts(out)
{:ok, out, laura} = DespachadorComandos.despachar_comando(:match_pets, ["60"], laura)
IO.puts(out)

IO.puts("\n=== 9. RESUMEN EJECUTIVO Y RECURSOS CRÍTICOS ===")
{:ok, out, laura} = DespachadorComandos.despachar_comando(:summary, [], laura)
IO.puts(out)
{:ok, out, _} = DespachadorComandos.despachar_comando(:critical_resources, ["15"], laura)
IO.puts(out)

IO.puts("\nDemostración finalizada con éxito total.")
