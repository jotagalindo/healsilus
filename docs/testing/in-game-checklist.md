# Verificación en el juego

Haz cada paso en un druida con Healsilus enlazado (`tools/link-addon.ps1`) y HealBot desactivado. Si algo falla, copia la salida de `/hs diag` y el error de Lua.

## 1. Diagnóstico
- [ ] `/reload` sin errores de Lua.
- [ ] `/hs diag`: la cabecera muestra `Interface 16001`.
- [ ] Todas las APIs salen `OK`. Anota las que salgan `FALTA`.
- [ ] `Contenedores nativos de auras: OK`.
- [ ] `SetAlphaFromBoolean: OK`. Si sale `FALTA`, el rango con secretos usa alfa fija (diseño §11).
- [ ] `Todos los IDs de hechizo del perfil existen.` Si no, corrige los IDs en `Data/Druid.lua`.
- [ ] `Cabecera party: 40 botones`, `tanks: 8`, `pets: 20`. Si sale menos, la precreación no funciona (diseño §11) y los botones nuevos recibirán auras al salir de combate.

## 2. Valores secretos forzados (fuera de combate)
- [ ] `/console secretCombatRestrictionsForced 1`, `/console secretEncounterRestrictionsForced 1` y `/console secretMapRestrictionsForced 1`.
- [ ] Las barras, la curación entrante, los HoTs y los debuffs siguen funcionando sin errores de Lua.
- [ ] El texto de vida en déficit funciona o cambia solo a porcentaje (queda anotado en `/hs diag`).
- [ ] Vuelve a poner los tres CVars a `0`.

## 3. Muñeco de entrenamiento
- [ ] Cada clic de la tabla lanza su hechizo sobre la barra (izquierdo Toque de sanación, derecho Rejuvenecer, Shift+izquierdo Recrecimiento...).
- [ ] Un rango fijo elegido en la pestaña Clics lanza ese rango.
- [ ] En combate, cambia una casilla: aparece "Pendiente" y se aplica al salir.
- [ ] `/hs preview 20` muestra 20 marcos falsos; al entrar en combate se cierran solos.

## 4. Grupo de mazmorra
- [ ] Las barras atenúan a quien está fuera de rango.
- [ ] Aparece borde rojo con aggro.
- [ ] Maldiciones y venenos pintan el anillo y el icono; Quitar maldición y Anular veneno funcionan con sus clics.
- [ ] Renacer funciona sobre un muerto.
- [ ] La esquina naranja marca a quien no tiene Marca; los tanques también sin Espinas. Fuera de combate se actualiza.

## 5. Banda (10/20/40)
- [ ] Alguien entra en combate y su barra tiene clics.
- [ ] Los tanques aparecen en su bloque (rol de tanque o Main Tank). Si no, revisa `roleFilter` (diseño §11).
- [ ] Mascotas visibles si están activadas.
- [ ] Los marcos de banda de Blizzard están ocultos.

## 6. Perfiles
- [ ] Activa "Perfil distinto por especialización", cambia de especialización y comprueba que el perfil cambia al salir de combate.
- [ ] Exporta el perfil en un PJ e impórtalo en otro.
- [ ] Copiar desde y Restablecer piden confirmación y funcionan.
