# Verificación en el juego

Haz cada paso en un druida con Healsilus enlazado (`tools/link-addon.ps1`) y HealBot desactivado. Si algo falla, copia la salida de `/hs diag` y el error de Lua.

## 1. Diagnóstico
- [ ] `/reload` sin errores de Lua.
- [ ] `/hs diag`: la cabecera muestra `Interface 16001`.
- [ ] Todas las APIs salen `OK`. Anota las que salgan `FALTA`.
- [ ] `Contenedores nativos de auras: OK`.
- [ ] `SetAlphaFromBoolean: OK`. Si sale `FALTA`, el rango con secretos usa alfa fija (diseño §11).
- [ ] Fuera de combate, `Auras legibles ahora: sí · buffs vigilados: 2 · barras sin algún buff: N`. Si sale `no`, el cliente devuelve las auras como secretos y no se puede avisar de buffs.
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

## 7. Estilos
- [ ] Al entrar, tu configuración anterior aparece como estilo "Mi estilo" y se ve igual que antes.
- [ ] Pestaña Estilos: crea uno desde "Clásico", renómbralo, duplícalo y bórralo. Al borrar el que está en uso, se pasa a Healsilus.
- [ ] Reglas: pon "Compacto banda" para "Banda de 21 a 40"; al entrar en una banda grande cambia solo (si estás en combate, al salir).
- [ ] Pestaña Aspecto: cambia fuente, tamaño y posición del nombre, color del fondo y colores de vida (con "Color de la barra: según la vida").
- [ ] Exporta un estilo e impórtalo: aparece como "Estilo importado".

## 8. Debuffs
- [ ] En cada tipo salen tus hechizos que lo quitan; elige uno y un clic y pulsa Asignar. La pestaña Clics muestra la asignación.
- [ ] "Teñir la barra entera" y "Ambos" colorean la barra con el color del tipo cuando alguien tiene un debuff que puedes quitar.

## 9. Buffs
- [ ] Fuera de combate, la barra de quien no tiene Marca se pinta del color elegido; al entrar en combate vuelve a su color.
- [ ] Asigna "Poner el buff que falta" a un clic: sobre esa barra lanza el buff que le falta.
- [ ] "Fuera de combate, cualquier clic pone el buff que le falta a la barra" viene marcada (pestaña Buffs o Clics): cualquier clic sobre una barra sin Marca lanza Marca de lo Salvaje; cuando ya la tiene, cada clic vuelve a hacer lo suyo.
- [ ] En combate esa barra vuelve a su color de vida, sin marca naranja ni aviso en el tooltip, y los clics hacen lo normal (no pone buffs). Al salir de combate vuelve el aviso.
- [ ] Con los dos overrides marcados, una barra con maldición y sin Marca: el clic quita primero la maldición.
- [ ] Con "Avisar si quedan menos de 5 minutos", un buff a punto de acabar cuenta como que falta.

## 10. Bloques
- [ ] Desbloquea, arrastra un bloque cerca de otro: se pega a su borde o se alinea.
- [ ] Con "Mover todos los bloques juntos", arrastrar uno mueve todos.
- [ ] Desmarca "Bloque principal": desaparece el bloque de grupo/banda.

## 11. Override de dispel
- [ ] Marca "Fuera de combate, cualquier clic quita el debuff que puedas quitar" (pestaña Clics o Debuffs).
- [ ] Fuera de combate, a un compañero con una maldición: clic izquierdo (o cualquier otro) lanza Quitar maldición. Sin debuff, cada clic vuelve a hacer lo suyo.
- [ ] En combate los clics hacen lo normal (Toque de sanación con el izquierdo), aunque tenga una maldición.

## 12. Texto de vida, rol, aggro y posición de auras
- [ ] Aspecto → "Texto de vida": prueba Vida actual (7,5 mil), Actual / máxima (7,5 mil / 10 mil) y Actual y porcentaje. En combate siguen cambiando sin errores (si no, `/hs diag` anota `UnitButton:HealthNumberText` y esa barra pasa a porcentaje).
- [ ] Aspecto → "Mostrar icono de tanque / sanador / DPS": en grupo con roles elegidos sale el icono; sin "Incluir el de DPS" solo tanques y sanadores. Cambia de rol y el icono se actualiza.
- [ ] Aggro: contra un muñeco o un mob, quien tiene el aggro lleva borde rojo y 3 puntos rojos; con mucha amenaza sin tanquear, 1 punto. Desmarca "Borde rojo" o "Puntos rojos" y comprueba que cada uno se quita por separado.
- [ ] `/hs diag` en combate: `Amenaza legible ahora: sí`. Si sale `no`, el juego oculta la amenaza en esa zona y no se puede mostrar (HealBot tampoco).
- [ ] Auras y Debuffs → "Posición de los iconos": Encima, Debajo, A la izquierda y A la derecha de la barra colocan los iconos fuera de la barra; las esquinas, dentro.
