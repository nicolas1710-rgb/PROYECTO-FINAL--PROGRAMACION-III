defmodule Emergencias.Aplicacion.CasosUso.GestionarLogistica do
  @moduledoc "Casos de uso unificados para gestion de recursos, necesidades y asignacion atomica."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{Permisos, Validaciones}

  @doc "Registrar un lote de suministros en el inventario de una ubicacion."
  def registrar_recurso(cod, nom, cant_val, unidad, ubi, cat, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_recurso),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, cant} <- Validaciones.validar_positivo(cant_val),
         {:ok, uni} <- Validaciones.validar_no_vacio(unidad),
         {:ok, ub} <- Validaciones.validar_no_vacio(ubi) do
      p = %{id: cod, nombre: n, cantidad_total: cant, unidad_medida: uni, ubicacion: ub, categoria: cat || "general"}
      puerto = resolver_puerto(opts, :puerto_logistica)
      puerto.registrar_recurso(p)
    end
  end

  @doc "Listar recursos en inventario aplicando filtros opcionales."
  def listar_recursos(filtros, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :listar_recursos) do
      puerto = resolver_puerto(opts, :puerto_logistica)
      lista = puerto.listar_recursos()
      filtrados = Enum.filter(lista, fn r ->
        (is_nil(filtros[:zona]) or r.ubicacion == filtros[:zona]) and
        (is_nil(filtros[:tipo]) or String.downcase(r.nombre) == String.downcase(filtros[:tipo]))
      end)
      {:ok, filtrados}
    end
  end

  @doc "Transferir stock entre recursos o ubicaciones de forma atomica."
  def transferir_recurso(cod, o_ub, d_ub, cant_val, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :transferir_recurso),
         {:ok, cant} <- Validaciones.validar_positivo(cant_val) do
      puerto = resolver_puerto(opts, :puerto_logistica)
      fecha = DateTime.utc_now() |> DateTime.to_iso8601()
      puerto.transferir(cod, o_ub, d_ub, cant, u.nombre, fecha)
    end
  end

  @doc "Reportar una necesidad humanitaria en una zona afectada."
  def registrar_necesidad(zona, recurso, cant_val, prio_val, desc, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_necesidad),
         {:ok, z} <- Validaciones.validar_no_vacio(zona),
         {:ok, r} <- Validaciones.validar_no_vacio(recurso),
         {:ok, cant} <- Validaciones.validar_positivo(cant_val),
         {:ok, prio} <- Validaciones.validar_prioridad(prio_val) do
      p = %{codigo_zona: z, tipo_recurso: r, cantidad_solicitada: cant, prioridad: prio, descripcion: desc || "", responsable: u.nombre}
      puerto = resolver_puerto(opts, :puerto_logistica)
      puerto.registrar_necesidad(p)
    end
  end

  @doc "Listar necesidades reportadas aplicando filtros opcionales."
  def listar_necesidades(filtros, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :listar_necesidades) do
      puerto = resolver_puerto(opts, :puerto_logistica)
      lista = puerto.listar_necesidades()
      filtrados = Enum.filter(lista, fn n ->
        (is_nil(filtros[:zona]) or n.codigo_zona == filtros[:zona]) and
        (is_nil(filtros[:prioridad]) or to_string(n.prioridad) == to_string(filtros[:prioridad])) and
        (is_nil(filtros[:estado]) or to_string(n.estado) == to_string(filtros[:estado]))
      end)
      {:ok, filtrados}
    end
  end

  @doc "Asignar recurso a necesidad de forma atomica e indivisible en GestorLogistica."
  def asignar_recurso(r_id, n_id, cant_val, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :asignar_recurso),
         {:ok, cant} <- Validaciones.validar_positivo(cant_val) do
      puerto = resolver_puerto(opts, :puerto_logistica)
      fecha = DateTime.utc_now() |> DateTime.to_iso8601()
      puerto.asignar(r_id, n_id, cant, u.nombre, fecha)
    end
  end

  @doc "Actualizar estado de una necesidad validando la maquina de estados."
  def actualizar_necesidad(id, nuevo_estado, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :actualizar_necesidad) do
      puerto = resolver_puerto(opts, :puerto_logistica)
      fecha = DateTime.utc_now() |> DateTime.to_iso8601()
      puerto.actualizar_necesidad(id, nuevo_estado, u.nombre, fecha)
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
