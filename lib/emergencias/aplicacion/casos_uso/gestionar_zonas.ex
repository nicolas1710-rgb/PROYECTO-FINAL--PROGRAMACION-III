defmodule Emergencias.Aplicacion.CasosUso.GestionarZonas do
  @moduledoc "Casos de uso para registro de zonas territoriales, sectores y puntos."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{JerarquiaZona, Permisos, Validaciones}

  @doc "Registrar una nueva zona en el sistema."
  def registrar_zona(cod, nom, nivel_str, personas, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_zona),
         {:ok, c} <- Validaciones.validar_no_vacio(cod),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, nivel} <- Validaciones.validar_nivel_gravedad(nivel_str),
         {:ok, p} <- Validaciones.validar_no_negativo(personas) do
      puerto = resolver_puerto(opts, :puerto_zonas)
      puerto.registrar_zona(%{id: c, nombre: n, nivel_gravedad: nivel, personas_afectadas: p})
    end
  end

  @doc "Registrar un sector barrial dentro de una zona."
  def registrar_sector(z_id, s_cod, nom, personas, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_sector),
         {:ok, c} <- Validaciones.validar_no_vacio(s_cod),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, p} <- Validaciones.validar_no_negativo(personas) do
      puerto = resolver_puerto(opts, :puerto_zonas)
      puerto.registrar_sector(z_id, %{id: c, nombre: n, personas_afectadas: p})
    end
  end

  @doc "Registrar un punto de atencion dentro de un sector."
  def registrar_punto(z_id, s_id, p_cod, nom, personas, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :registrar_punto),
         {:ok, c} <- Validaciones.validar_no_vacio(p_cod),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, p} <- Validaciones.validar_no_negativo(personas) do
      puerto = resolver_puerto(opts, :puerto_zonas)
      puerto.registrar_punto(z_id, s_id, %{id: c, nombre: n, personas_afectadas: p})
    end
  end

  @doc "Consultar los datos de una zona especifica."
  def consultar_zona(id, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :consultar_zona) do
      puerto = resolver_puerto(opts, :puerto_zonas)
      puerto.consultar(id)
    end
  end

  @doc "Listar todas las zonas registradas."
  def listar_zonas(%Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :listar_zonas) do
      puerto = resolver_puerto(opts, :puerto_zonas)
      {:ok, puerto.listar()}
    end
  end

  @doc "Calcular estado territorial recursivo: total de sectores, puntos y personas afectadas."
  def consultar_estado_zona(id, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :consultar_zona),
         {:ok, zona} <- consultar_zona(id, u, opts) do
      puntos_total = JerarquiaZona.contar_puntos_atencion(zona)
      personas_total = JerarquiaZona.sumar_personas_afectadas(zona)
      {:ok, %{zona: zona, total_sectores: length(zona.sectores), total_puntos: puntos_total, total_personas: personas_total}}
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
