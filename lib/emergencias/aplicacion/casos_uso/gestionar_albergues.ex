defmodule Emergencias.Aplicacion.CasosUso.GestionarAlbergues do
  @moduledoc "Casos de uso para albergues, control de aforo y vinculacion de suministros."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{Ordenamiento, Permisos, Validaciones}

  @doc "Registrar un nuevo albergue supervisado."
  def registrar_albergue(nom, zona, cap_val, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_albergue),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, z} <- Validaciones.validar_no_vacio(zona),
         {:ok, cap} <- Validaciones.validar_positivo(cap_val) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      puerto.registrar(%{nombre: n, codigo_zona: z, capacidad_maxima: cap})
    end
  end

  @doc "Consultar estado y aforo de un albergue."
  def consultar_albergue(id, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :consultar_albergue) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      puerto.consultar(id)
    end
  end

  @doc "Registrar ingreso de una persona al albergue validando cupo maximo."
  def registrar_entrada(id, doc, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_entrada_albergue),
         {:ok, d} <- Validaciones.validar_no_vacio(doc) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      case puerto.ingresar(id, d) do
        {:ok, alb} ->
          puerto_p = resolver_puerto(opts, :puerto_personas)
          fecha = DateTime.utc_now() |> DateTime.to_iso8601()
          _ = puerto_p.actualizar_estado(d, :en_albergue, u.nombre, fecha, id)
          {:ok, alb}
        error -> error
      end
    end
  end

  @doc "Registrar salida de una persona del albergue."
  def registrar_salida(id, doc, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_salida_albergue),
         {:ok, d} <- Validaciones.validar_no_vacio(doc) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      puerto.salir(id, d)
    end
  end

  @doc "Vincular un recurso o suministro al albergue."
  def vincular_recurso(id, r_id, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :vincular_albergue) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      puerto.vincular_recurso(id, r_id)
    end
  end

  @doc "Vincular una necesidad humanitaria al albergue."
  def vincular_necesidad(id, n_id, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :vincular_albergue) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      puerto.vincular_necesidad(id, n_id)
    end
  end

  @doc "Listar albergues registrados."
  def listar_albergues(%Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :consultar_albergue) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      {:ok, puerto.listar()}
    end
  end

  @doc "Generar reporte de albergues ordenados por ocupacion descendente mediante Merge Sort."
  def generar_reporte_albergues(%Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :reporte_albergues) do
      puerto = resolver_puerto(opts, :puerto_albergues)
      ordenados = Ordenamiento.ordenar(puerto.listar(), &Ordenamiento.comparar_albergues/2)
      {:ok, ordenados}
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
