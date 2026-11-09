defmodule Emergencias.Aplicacion.CasosUso.GestionarFamiliares do
  @moduledoc "Casos de uso para censo de personas afectadas y mensajeria familiar."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{Permisos, Validaciones}

  @doc "Reportar a una persona damnificada con todos los datos del censo."
  def reportar_persona(doc, nom, edad_val, zona, est_val, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :reportar_persona),
         {:ok, d} <- Validaciones.validar_no_vacio(doc),
         {:ok, n} <- Validaciones.validar_no_vacio(nom),
         {:ok, e} <- Validaciones.validar_no_negativo(edad_val),
         {:ok, z} <- Validaciones.validar_no_vacio(zona) do
      est = if est_val, do: String.to_atom(to_string(est_val)), else: :reportada
      puerto = resolver_puerto(opts, :puerto_personas)
      puerto.reportar(%{documento: d, nombre: n, edad: e, zona: z, estado: est})
    end
  end

  @doc "Buscar personas por documento o por mapa de criterios multiples."
  def buscar_persona(criterio, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :buscar_persona) do
      puerto = resolver_puerto(opts, :puerto_personas)
      puerto.buscar(criterio)
    end
  end

  @doc "Actualizar estado de una persona en el censo con transicion valida."
  def actualizar_persona(doc, nuevo_estado_str, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :actualizar_persona),
         {:ok, d} <- Validaciones.validar_no_vacio(doc) do
      nuevo_estado = String.to_atom(to_string(nuevo_estado_str))
      puerto = resolver_puerto(opts, :puerto_personas)
      fecha = DateTime.utc_now() |> DateTime.to_iso8601()
      puerto.actualizar_estado(d, nuevo_estado, u.nombre, fecha, nil)
    end
  end

  @doc "Enviar un mensaje familiar vinculado a una persona."
  def enviar_mensaje(doc, remitente, contenido, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :enviar_mensaje),
         {:ok, d} <- Validaciones.validar_no_vacio(doc),
         {:ok, c} <- Validaciones.validar_no_vacio(contenido) do
      rem = if remitente, do: remitente, else: u.nombre
      puerto = resolver_puerto(opts, :puerto_personas)
      puerto.enviar_mensaje(%{documento_persona: d, remitente: rem, contenido: c})
    end
  end

  @doc "Listar los mensajes familiares dirigidos a un documento."
  def listar_mensajes(doc, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :listar_mensajes) do
      puerto = resolver_puerto(opts, :puerto_personas)
      {:ok, puerto.listar_mensajes(doc)}
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
