defmodule Emergencias.Aplicacion.CasosUso.GestionarRecursos do
  @moduledoc """
  Caso de uso para inventario, asignación atómica a necesidades y transferencias entre zonas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoRecursos

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Recurso, Usuario}
  alias Emergencias.Dominio.Reglas.{Inventario, Permisos, Validaciones}
  alias Emergencias.Infraestructura.Procesos.GestorRecursos

  @impl true
  @doc """
  Registrar un nuevo lote de recursos en inventario.
  """
  @spec registrar_recurso(map(), Usuario.t(), keyword()) :: {:ok, Recurso.t()} | {:error, atom()}
  def registrar_recurso(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_recurso) do
      gestor = Keyword.get(opciones, :gestor_recursos, GestorRecursos)
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if is_atom(gestor) and Process.whereis(gestor) != nil and is_nil(repo_personalizado) do
        gestor.registrar_recurso(params, usuario.nombre)
      else
        ejecutar_registro_directo(params, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Listar recursos con filtros opcionales de zona y tipo.
  """
  @spec listar_recursos(keyword(), Usuario.t(), keyword()) ::
          {:ok, list(Recurso.t())} | {:error, atom()}
  def listar_recursos(filtros, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :listar_recursos) do
      gestor = Keyword.get(opciones, :gestor_recursos, GestorRecursos)
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if is_atom(gestor) and Process.whereis(gestor) != nil and is_nil(repo_personalizado) do
        gestor.listar_recursos(filtros)
      else
        repositorio = obtener_repositorio(opciones)
        {:ok, lista} = cargar_recursos(repositorio)
        {:ok, filtrar_recursos(lista, filtros)}
      end
    end
  end

  @impl true
  @doc """
  Asignar recursos de manera atómica para atender una necesidad.
  """
  @spec asignar_recurso(String.t(), String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}
  def asignar_recurso(id_recurso, id_necesidad, cantidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :asignar_recurso),
         {:ok, cant_valida} <- Validaciones.validar_cantidad_positiva(cantidad) do
      gestor = Keyword.get(opciones, :gestor_recursos, GestorRecursos)
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if is_atom(gestor) and Process.whereis(gestor) != nil and is_nil(repo_personalizado) do
        gestor.asignar_recurso(id_recurso, id_necesidad, cant_valida, usuario.nombre)
      else
        ejecutar_asignacion_directa(id_recurso, id_necesidad, cant_valida, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Transferir existencias entre dos recursos de diferentes zonas.
  """
  @spec transferir_recurso(String.t(), String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}
  def transferir_recurso(id_origen, id_destino, cantidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :transferir_recurso),
         {:ok, cant_valida} <- Validaciones.validar_cantidad_positiva(cantidad) do
      gestor = Keyword.get(opciones, :gestor_recursos, GestorRecursos)
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if is_atom(gestor) and Process.whereis(gestor) != nil and is_nil(repo_personalizado) do
        gestor.transferir_recurso(id_origen, id_destino, cant_valida, usuario.nombre)
      else
        ejecutar_transferencia_directa(id_origen, id_destino, cant_valida, usuario, opciones)
      end
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos} <- Validaciones.validar_entrada_recurso(params) do
      repositorio = obtener_repositorio(opciones)
      bitacora = obtener_bitacora(opciones)
      reloj = obtener_reloj(opciones)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_recursos(repositorio)
      nuevo_id = GeneradorId.formatear_id(:recurso, length(existentes) + 1)

      {:ok, nuevo_recurso} =
        Recurso.construir(%{
          id: nuevo_id,
          tipo: datos.tipo,
          unidad_medida: datos.unidad_medida,
          cantidad_total: datos.cantidad_total,
          cantidad_disponible: datos.cantidad_total,
          codigo_zona: datos.codigo_zona,
          fecha_registro: fecha
        })

      {:ok, existentes_movs} = cargar_movimientos(repositorio)
      id_mov = GeneradorId.formatear_id(:movimiento, length(existentes_movs) + 1)

      {:ok, mov_inicial} =
        MovimientoInventario.construir(%{
          id: id_mov,
          codigo_recurso: nuevo_id,
          tipo_movimiento: :entrada,
          cantidad: datos.cantidad_total,
          origen: "Ingreso Inicial",
          destino: datos.codigo_zona,
          fecha: fecha,
          usuario_responsable: usuario.nombre
        })

      guardar_recurso(repositorio, nuevo_recurso)
      guardar_movimiento(repositorio, mov_inicial)
      notificar_bitacora(bitacora, usuario.nombre, "registrar_recurso", "Recurso #{nuevo_id} ingresado", fecha)
      {:ok, nuevo_recurso}
    end
  end

  defp ejecutar_asignacion_directa(id_recurso, id_necesidad, cantidad, usuario, opciones) do
    repositorio = obtener_repositorio(opciones)
    bitacora = obtener_bitacora(opciones)
    reloj = obtener_reloj(opciones)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, recurso} <- buscar_recurso(repositorio, id_recurso) do
      {:ok, movs} = cargar_movimientos(repositorio)
      id_mov = GeneradorId.formatear_id(:movimiento, length(movs) + 1)

      with {:ok, {rec_act, mov}} <-
             Inventario.asignar(recurso, cantidad, id_mov, id_necesidad, usuario.nombre, fecha) do
        guardar_recurso(repositorio, rec_act)
        guardar_movimiento(repositorio, mov)
        notificar_bitacora(bitacora, usuario.nombre, "asignar_recurso", "#{cantidad} de #{id_recurso} a #{id_necesidad}", fecha)
        {:ok, {rec_act, mov}}
      end
    end
  end

  defp ejecutar_transferencia_directa(id_origen, id_destino, cantidad, usuario, opciones) do
    repositorio = obtener_repositorio(opciones)
    bitacora = obtener_bitacora(opciones)
    reloj = obtener_reloj(opciones)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, origen} <- buscar_recurso(repositorio, id_origen),
         {:ok, destino} <- buscar_recurso(repositorio, id_destino) do
      {:ok, movs} = cargar_movimientos(repositorio)
      id_m1 = GeneradorId.formatear_id(:movimiento, length(movs) + 1)
      id_m2 = GeneradorId.formatear_id(:movimiento, length(movs) + 2)

      with {:ok, {o_act, d_act, m1, m2}} <-
             Inventario.transferir(origen, destino, cantidad, {id_m1, id_m2}, usuario.nombre, fecha) do
        guardar_recurso(repositorio, o_act)
        guardar_recurso(repositorio, d_act)
        guardar_movimiento(repositorio, m1)
        guardar_movimiento(repositorio, m2)
        notificar_bitacora(bitacora, usuario.nombre, "transferir_recurso", "#{cantidad} de #{id_origen} a #{id_destino}", fecha)
        {:ok, {o_act, d_act}}
      end
    end
  end

  defp filtrar_recursos(lista, []), do: lista

  defp filtrar_recursos(lista, [{:zona, valor} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.codigo_zona) == String.downcase(to_string(valor)) end)
    |> filtrar_recursos(resto)
  end

  defp filtrar_recursos(lista, [{:tipo, valor} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.tipo) == String.downcase(to_string(valor)) end)
    |> filtrar_recursos(resto)
  end

  defp filtrar_recursos(lista, [_ | resto]), do: filtrar_recursos(lista, resto)

  defp buscar_recurso(repo, id) do
    {:ok, lista} = cargar_recursos(repo)
    encontrado = Enum.find(lista, fn r -> String.upcase(r.id) == String.upcase(id) end)
    if encontrado, do: {:ok, encontrado}, else: {:error, :recurso_no_encontrado}
  end

  defp obtener_repositorio(opts),
    do: Keyword.get(opts, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)

  defp obtener_bitacora(opts),
    do: Keyword.get(opts, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)

  defp obtener_reloj(opts), do: Keyword.get(opts, :reloj, Reloj)

  defp cargar_recursos(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:recursos), else: {:ok, []}
  end

  defp guardar_recurso(repo, r) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:recursos, r), else: :ok
  end

  defp cargar_movimientos(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:movimientos), else: {:ok, []}
  end

  defp guardar_movimiento(repo, m) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:movimientos, m), else: :ok
  end

  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
