# Verificación de cuenta por correo (código de 6 dígitos)

La app crea la cuenta con nombre, correo, contraseña y país, y pide un código de
6 dígitos que llega al correo. Sin verificar no se puede entrar.

Esto se configura **una sola vez en Supabase** (proyecto QA primero, producción después).
Si "Confirm email" está apagado, la app rechaza el registro a propósito.

## 1. Activar la confirmación de correo
Authentication → Providers → Email → activar **Confirm email**.

## 2. Que el correo lleve el código
Authentication → Email Templates → **Confirm signup**. En el cuerpo usar el código,
no solo el enlace. Ejemplo:

```html
<h2>Tu código de MILTVPLUS</h2>
<p>Ingresá este código en la app para activar tu cuenta:</p>
<p style="font-size:28px;letter-spacing:6px"><strong>{{ .Token }}</strong></p>
```

## 3. Servicio de envío propio (SMTP)
El envío por defecto de Supabase es muy limitado y no sirve para usuarios reales.
Authentication → Emails → SMTP Settings → **Enable Custom SMTP** y cargar los datos
de un proveedor (por ejemplo Resend o Brevo, ambos con plan gratuito). Hace falta un
remitente verificado en ese proveedor.

## 4. Probar
1. Crear una cuenta con un correo propio.
2. Debe llegar el código; ingresarlo en la app.
3. Probar "Reenviar código" y un código incorrecto.
4. Iniciar sesión con una cuenta sin verificar: la app debe pedir el código otra vez.
