defmodule Emergencias.Aplicacion.CasosUso.GestionarMascotas do
  @moduledoc "Casos de uso para reporte, emparejamiento y resolucion de mascotas."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{Permisos, SimilitudMascotas, Validaciones}

  @doc "Reportar una mascota perdida o encontrada."
  def reportar_mascota(tipo_val, esp, col, tam_val, zona, nom, caracs, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :reportar_mascota),
         {:ok, tipo} <- Validaciones.validar_tipo_mascota(tipo_val),
         {:ok, e} <- Validaciones.validar_no_vacio(esp),
         {:ok, c} <- Validaciones.validar_no_vacio(col),
         {:ok, tam} <- Validaciones.validar_tamano_mascota(tam_val),
         {:ok, z} <- Validaciones.validar_no_vacio(zona) do
      p = %{tipo_reporte: tipo, especie: e, color: c, tamano: tam, codigo_zona: z, nombre: nom || "", usuario: u.nombre, caracteristicas: caracs || []}
      puerto = resolver_puerto(opts, :puerto_mascotas)
      puerto.reportar(p)
    end
  end

  @doc "Listar mascotas registradas con filtros opcionales de especie, zona o estado."
  def listar_mascotas(filtros, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :listar_mascotas) do
      puerto = resolver_puerto(opts, :puerto_mascotas)
      lista = puerto.listar()
      filtrados = Enum.filter(lista, fn m ->
        (is_nil(filtros[:especie]) or String.downcase(m.especie) == String.downcase(filtros[:especie])) and
        (is_nil(filtros[:zona]) or m.codigo_zona == filtros[:zona]) and
        (is_nil(filtros[:estado]) or to_string(m.estado) == to_string(filtros[:estado]))
      end)
      {:ok, filtrados}
    end
  end

  @doc "Emparejar mascotas perdidas y encontradas que superen el umbral de similitud."
  def emparejar_mascotas(umbral, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :emparejar_mascotas),
         {:ok, u_num} <- Validaciones.validar_positivo(umbral) do
      puerto = resolver_puerto(opts, :puerto_mascotas)
      coincidencias = SimilitudMascotas.emparejar(puerto.listar(), u_num)
      {:ok, coincidencias}
    end
  end

  @doc "Confirmar una coincidencia cerrando ambos reportes como resueltos."
  def confirmar_coincidencia(id_p, id_e, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :confirmar_coincidencia) do
      puerto = resolver_puerto(opts, :puerto_mascotas)
      fecha = DateTime.utc_now() |> DateTime.to_iso8601()
      puerto.confirmar_coincidencia(id_p, id_e, u.nombre, fecha)
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
