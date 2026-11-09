defmodule Emergencias.Aplicacion.CasosUso.GestionarUsuarios do
  @moduledoc """
  Caso de uso para autenticación, registro automático y gestión de sesiones de usuario.
  Implementa hashing seguro SHA-256 con sal criptográfica para contraseñas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoUsuarios

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.Validaciones

  @sal_segura "emergencias_uq_2026_"

  @impl true
  @doc """
  Conectar un usuario al sistema. Si no existe, lo registra automáticamente con las credenciales dadas.
  """
  @spec conectar(String.t(), String.t(), atom(), keyword()) ::
          {:ok, Usuario.t()} | {:error, atom()}
  def conectar(nombre, clave, rol \\ :ciudadano, opciones \\ []) do
    with {:ok, nombre_valido} <- Validaciones.validar_texto_no_vacio(nombre),
         {:ok, clave_valida} <- Validaciones.validar_texto_no_vacio(clave),
         {:ok, rol_valido} <- Validaciones.validar_rol(rol) do
      puerto_usuarios = resolver_puerto(opciones, :puerto_usuarios, :puerto_usuarios)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_usuarios != nil and function_exported?(puerto_usuarios, :conectar, 3) ->
          case puerto_usuarios.conectar(nombre_valido, clave_valida, rol_valido) do
            {:ok, %Usuario{} = usuario} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "login", "Conexión exitosa", fecha)
              {:ok, usuario}

            {:error, razon} ->
              notificar_bitacora(puerto_bitacora, nombre_valido, "login_fallido", "Fallo: #{razon}", fecha)
              {:error, razon}
          end

        true ->
          # Soporte para repositorio inyectado en pruebas unitarias puras
          hash_ingresado = calcular_hash_clave(clave_valida)
          repositorio = Keyword.get(opciones, :repositorio)

          case buscar_por_nombre(repositorio, nombre_valido) do
            {:ok, %Usuario{} = existente} ->
              verificar_credencial(existente, hash_ingresado, puerto_bitacora, fecha)

            {:error, :no_encontrado} ->
              crear_nuevo_usuario(repositorio, puerto_bitacora, nombre_valido, hash_ingresado, rol_valido, fecha)
          end
      end
    end
  end

  @impl true
  @doc """
  Desconectar una sesión activa de usuario.
  """
  @spec desconectar(String.t(), keyword()) :: :ok | {:error, atom()}
  def desconectar(nombre_usuario, opciones \\ []) do
    puerto_usuarios = resolver_puerto(opciones, :puerto_usuarios, :puerto_usuarios)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    if puerto_usuarios != nil and function_exported?(puerto_usuarios, :desconectar, 1) do
      puerto_usuarios.desconectar(nombre_usuario)
    end

    notificar_bitacora(puerto_bitacora, nombre_usuario, "logout", "Cierre de sesión", fecha)
    :ok
  end

  @doc """
  Calcular el hash SHA-256 en hexadecimal con sal criptográfica de una clave dada.
  """
  @spec calcular_hash_clave(String.t()) :: String.t()
  def calcular_hash_clave(clave) when is_binary(clave) do
    :crypto.hash(:sha256, @sal_segura <> clave) |> Base.encode16(case: :lower)
  end

  defp resolver_puerto(opciones, clave, config_key) do
    cond do
      Keyword.has_key?(opciones, clave) -> Keyword.get(opciones, clave)
      Keyword.has_key?(opciones, :repositorio) -> nil
      true -> Application.get_env(:emergencias, config_key)
    end
  end

  defp verificar_credencial(%Usuario{} = usuario, hash_ingresado, bitacora, fecha) do
    if usuario.clave_hash == hash_ingresado do
      notificar_bitacora(bitacora, usuario.nombre, "login", "Inicio de sesión exitoso", fecha)
      {:ok, usuario}
    else
      notificar_bitacora(bitacora, usuario.nombre, "login_fallido", "Clave incorrecta", fecha)
      {:error, :clave_incorrecta}
    end
  end

  defp crear_nuevo_usuario(repositorio, bitacora, nombre, hash, rol, fecha) do
    {:ok, usuarios} = cargar_usuarios(repositorio)
    nuevo_id = GeneradorId.formatear_id(:usuario, length(usuarios) + 1)

    {:ok, nuevo_usuario} =
      Usuario.construir(%{
        id: nuevo_id,
        nombre: nombre,
        rol: rol,
        clave_hash: hash,
        fecha_registro: fecha
      })

    guardar_usuario(repositorio, nuevo_usuario)
    notificar_bitacora(bitacora, nombre, "registro", "Usuario creado con rol #{rol}", fecha)
    {:ok, nuevo_usuario}
  end

  defp buscar_por_nombre(repositorio, nombre) do
    case cargar_usuarios(repositorio) do
      {:ok, lista} ->
        encontrado = Enum.find(lista, fn u -> String.downcase(u.nombre) == String.downcase(nombre) end)
        if encontrado, do: {:ok, encontrado}, else: {:error, :no_encontrado}

      _ ->
        {:error, :no_encontrado}
    end
  end

  defp cargar_usuarios(nil), do: {:ok, []}
  defp cargar_usuarios(repositorio) do
    if function_exported?(repositorio, :cargar, 1) do
      repositorio.cargar(:usuarios)
    else
      {:ok, []}
    end
  end

  defp guardar_usuario(nil, _usuario), do: :ok
  defp guardar_usuario(repositorio, usuario) do
    if function_exported?(repositorio, :guardar, 2) do
      repositorio.guardar(:usuarios, usuario)
    else
      :ok
    end
  end

  defp notificar_bitacora(nil, _usuario, _accion, _detalles, _fecha), do: :ok
  defp notificar_bitacora(bitacora, usuario, accion, detalles, fecha) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(usuario, accion, detalles, fecha)
    else
      :ok
    end
  end
end
