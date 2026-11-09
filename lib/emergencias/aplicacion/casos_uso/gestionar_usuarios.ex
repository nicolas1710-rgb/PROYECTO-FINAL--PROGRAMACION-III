defmodule Emergencias.Aplicacion.CasosUso.GestionarUsuarios do
  @moduledoc """
  Caso de uso para autenticación, registro automático y gestión de sesiones de usuario.
  Implementa hashing seguro SHA-256 para contraseñas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoUsuarios

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.Validaciones

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
      repositorio = Keyword.get(opciones, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)
      bitacora = Keyword.get(opciones, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)
      reloj = Keyword.get(opciones, :reloj, Reloj)

      fecha = reloj.obtener_fecha_actual()
      hash_ingresado = calcular_hash_clave(clave_valida)

      case buscar_por_nombre(repositorio, nombre_valido) do
        {:ok, %Usuario{} = existente} ->
          verificar_credencial(existente, hash_ingresado, bitacora, fecha)

        {:error, :no_encontrado} ->
          crear_nuevo_usuario(repositorio, bitacora, nombre_valido, hash_ingresado, rol_valido, fecha)
      end
    end
  end

  @impl true
  @doc """
  Desconectar una sesión activa de usuario.
  """
  @spec desconectar(String.t(), keyword()) :: :ok | {:error, atom()}
  def desconectar(nombre_usuario, opciones \\ []) do
    bitacora = Keyword.get(opciones, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    notificar_bitacora(bitacora, nombre_usuario, "logout", "Cierre de sesión", fecha)
    :ok
  end

  @doc """
  Calcular el hash SHA-256 en hexadecimal de una clave dada.
  """
  @spec calcular_hash_clave(String.t()) :: String.t()
  def calcular_hash_clave(clave) when is_binary(clave) do
    :crypto.hash(:sha256, clave) |> Base.encode16(case: :lower)
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

  defp cargar_usuarios(repositorio) do
    if function_exported?(repositorio, :cargar, 1) do
      repositorio.cargar(:usuarios)
    else
      {:ok, []}
    end
  end

  defp guardar_usuario(repositorio, usuario) do
    if function_exported?(repositorio, :guardar, 2) do
      repositorio.guardar(:usuarios, usuario)
    else
      :ok
    end
  end

  defp notificar_bitacora(bitacora, usuario, accion, detalles, fecha) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(usuario, accion, detalles, fecha)
    else
      :ok
    end
  end
end
