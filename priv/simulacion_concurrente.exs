# Simulación Concurrente Multiusuario del Sistema de Emergencias
# Ejecuta sesiones en paralelo con Task.async_stream demostrando concurrencia real.

alias Emergencias.Infraestructura.Entrada.DespachadorComandos

IO.puts("==================================================================")
IO.puts("  INICIANDO SIMULACIÓN CONCURRENTE MULTIUSUARIO (10 USUARIOS)    ")
IO.puts("==================================================================")

# 1. Sesión preparatoria de la Coordinadora
{:ok, _, laura} = DespachadorComandos.despachar_comando(:connect, ["LauraCoordinadora", "admin123", "coordinador"], nil)
{:ok, _, laura} = DespachadorComandos.despachar_comando(:register_zone, ["ZonaOccidente", "alto"], laura)
{:ok, _, _} = DespachadorComandos.despachar_comando(:register_resource, ["kit_primeros_auxilios", "cajas", "50", "Z001"], laura)

IO.puts("[OK] Entorno preparado: ZonaOccidente y 50 kits de primeros auxilios registrados.\n")

# 2. 10 usuarios conectándose y reportando necesidades en paralelo simultáneo
IO.puts(">> Lanzando 10 ciudadanos concurrentes reportando necesidades con Task.async_stream...")

1..10
|> Task.async_stream(
  fn i ->
    nombre = "Ciudadano_#{i}"
    doc = "CC_1094900#{i}"
    # Conectar
    {:ok, _, usr} = DespachadorComandos.despachar_comando(:connect, [nombre, "clave_#{i}", "ciudadano"], nil)
    # Reportar persona
    {:ok, resp_p, _} = DespachadorComandos.despachar_comando(:report_person, [doc, "Persona #{i}"], usr)
    # Reportar necesidad
    {:ok, resp_n, _} = DespachadorComandos.despachar_comando(:register_need, ["Z001", "kit_primeros_auxilios", "5", "alta"], usr)
    {nombre, resp_p, resp_n}
  end,
  max_concurrency: 10,
  timeout: 10000
)
|> Enum.each(fn {:ok, {nom, p_out, n_out}} ->
  IO.puts("  * [Proceso Paralelo] #{nom}:")
  IO.puts("      #{p_out}")
  IO.puts("      #{n_out}")
end)

# 3. 5 voluntarios asignando recursos concurrentemente compitiendo por stock
IO.puts("\n>> Lanzando 5 coordinadores concurrentes intentando asignar recursos...")

1..5
|> Task.async_stream(
  fn i ->
    nombre = "Coordinador_Auxiliar_#{i}"
    {:ok, _, coord_aux} = DespachadorComandos.despachar_comando(:connect, [nombre, "coord_pass", "coordinador"], nil)
    # Intentar asignar 15 kits a necesidades
    case DespachadorComandos.despachar_comando(:assign_resource, ["R001", "N001", "15"], coord_aux) do
      {:ok, salida, _} -> {nombre, :exito, salida}
      {:error, err, _} -> {nombre, :rechazado, err}
    end
  end,
  max_concurrency: 5,
  timeout: 10000
)
|> Enum.each(fn {:ok, {nom, estado_tx, detalle}} ->
  IO.puts("  * [Asignación Concurrente] #{nom} -> #{estado_tx}: #{detalle}")
end)

# 4. Resumen consolidado final
IO.puts("\n>> Resumen consolidado post-concurrencia:")
{:ok, _, laura_final} = DespachadorComandos.despachar_comando(:connect, ["LauraCoordinadora", "admin123", "coordinador"], nil)
{:ok, resumen_texto, _} = DespachadorComandos.despachar_comando(:summary, [], laura_final)
IO.puts(resumen_texto)

IO.puts("==================================================================")
IO.puts("        SIMULACIÓN CONCURRENTE FINALIZADA CON ÉXITO               ")
IO.puts("==================================================================")
