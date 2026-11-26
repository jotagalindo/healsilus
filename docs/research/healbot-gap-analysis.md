# HealBot frente a Healsilus: qué falta

Fecha: 2026-11-27. Fuente: HealBot v26.11.20 instalado en `_forever_\Interface\AddOns\HealBot` (lectura de `Locale\HealBot_Localization.en.lua`, `HealBot_Options.xml/.lua`, `HealBot_Skins.lua`, `HealBot_Vars.lua`, `HealBot_Forever*.lua`, `HealBot_CombatAuras.lua`). "Loc:N" = línea del fichero de textos en inglés; "Opt:N" = `HealBot_Options.lua`; "XML:N" = `HealBot_Options.xml`. Lo marcado *(inferido)* no se leyó directamente.

## 1. Cómo está organizado HealBot

Pestañas (Opt:25800-25858): General · Overrides · Spells · Skins (General, Effects, Colours, Enemy, Chat, Frames → General, Heal Groups, Headers, Bars, Bar Text, Icons) · Debuffs · Buffs · Tips · Test · Import/Export · Plugins.

Cada **skin** tiene **10 marcos**, y cada marco lleva su propia configuración de barras, textos, iconos, indicadores y barras auxiliares (`HealBot_Skins.lua:1539-1542`, `HealBot_Vars.lua:699-868`). Las skins se eligen solas según el contexto: solo, grupo, banda 10/15/20/25/40, arena, campo de batalla, especialización o zona (Loc:917).

Bloques principales:
- **Skins → Bars:**
  - 30 texturas; columnas, alto, ancho y separaciones.
  - Color de vida: por vida, clase, rol, personalizado o mezclas.
  - Color y alfa del fondo y del borde. Colores de curación entrante y escudos.
  - Orden principal y secundario. Visibilidad por situación.
  - Aggro: borde parpadeante o brillo.
  - Hasta 9 barras auxiliares de 24 tipos.
- **Skins → Bar Text:**
  - Nombre, vida, estado y aggro, cada uno con su fuente, tamaño, contorno, posición (izquierda, centro, derecha, al lado o debajo), offsets y máximo de caracteres.
  - Formatos de número 1234 / 1K / 1.2K y corchetes.
  - Etiquetas de estado editables (DC, RIP, OOR...).
- **Skins → Icons:**
  - 3 sets de iconos de buff y de debuff por marco. Cada set con ancla en 12 posiciones, dentro/fuera/debajo de la barra, escala, separación, zoom, doble fila, desvanecer y textos de duración y cargas.
  - Iconos de clase, rol, líder, marca de banda, ready check y AFK.
  - Flecha de dirección fuera de rango.
- **Skins → Headers:** cabeceras "Grupo N" y título del marco, con textura y fuente.
- **Skins → Frames General:**
  - Ancla y dirección de crecimiento desde 4 esquinas; barras verticales; escala; estrato.
  - Fondo y borde del marco; bloqueo con modificador.
- **Spells:**
  - Atajos de botón × modificador; rueda y teclas; botones del 6 al 20 con un plugin.
  - Opciones por atajo: evitar el cursor azul, seleccionar, abalorios.
  - SmartCast.
- **Debuffs y Buffs:**
  - Listas personalizadas por ID con prioridad, color y brillo, y avisos con sonido.
  - Buffs vigilados con destinos (rol, clase, lista privada), encantamientos de arma, comida y frascos.
- **Tips:** tooltip configurable, con la lista de hechizos de cada clic.
- **Import/Export:** skins, listas, hechizos; compartir skins por canal de addon; skins incluidos.
- **Adaptaciones a Forever:**
  - Curación entrante con el calculador nativo.
  - Toda la barra teñida por el tipo de dispel con `AuraContainer` + `AddDispelTypeTexture` anclada a la textura de vida (`HealBot_ForeverFrames.lua:97-131`).
  - Escudo con las texturas atlas `raidframe-shield-fill`.
  - Aggro solo cuando `UnitThreatSituation` es legible.

## 2. Tabla de brechas

| Función | Healsilus | ¿Viable con secretos? | Prioridad |
|---|---|---|---|
| Skins/estilos con nombre (crear, duplicar, borrar) | no (perfil único) | sí: es configuración aplicada con CombatQueue | **alta** |
| Skin automática por contexto (solo, grupo, banda 10/20/40, BG, spec, zona) | parcial (solo spec) | sí, fuera de combate; en combate se encola | **alta** |
| Más texturas (propias + LibSharedMedia) | parcial (3) | sí | **alta** |
| Fuente, tamaño y contorno de cada texto | no | sí | **alta** |
| Posición, alineación, offsets y máximo de caracteres de nombre, vida y estado | no | sí | **alta** |
| Umbrales y colores editables de la curva de vida | no (curva fija) | sí (puntos de la curva) | **alta** |
| Color y alfa del fondo de la barra | no | sí | **alta** |
| Barra entera teñida por el tipo de dispel (además del anillo) | parcial (anillo) | sí, misma técnica que HealBot | **alta** |
| Resaltado al pasar el ratón y del objetivo actual | no | sí | **alta** |
| Iconos de aura: ancla en 8+ posiciones, dentro/fuera, separación, crecimiento, zoom | parcial (tamaño y máximo) | sí (geometría del contenedor) | **alta** |
| Barra de maná o poder (solo sanadores) | no | sí: StatusBar con UnitPower | **alta** |
| Estilos incluidos ("presets") | no | sí | **alta** |
| Color de vida por rol, personalizado o mezcla clase+vida | no | sí *(mezcla con una curva por clase, inferido)* | media |
| Color del nombre (clase, personalizado) | no | sí | media |
| Borde de unidad: color, grosor, alfa | no | sí | media |
| Fondo, borde y padding del marco; escala; estrato | no | sí | media |
| Colores y alfa de curación entrante y escudos; textura atlas de escudo | parcial (fijos) | sí | media |
| Estilos de aggro (sólido, parpadeo, brillo) | parcial (sólido) | sí cuando es legible | media |
| Formatos del texto de vida (1K / 1.2K, corchetes) | parcial | parcial (depende de que el formateo acepte secretos) | media |
| Indicador de maná bajo | no | parcial (curva de UnitPowerPercent, inferido) | media |
| Barras verticales, llenado invertido, crecer desde 4 esquinas | parcial | sí | media |
| Varios marcos con grupos asignables; cabeceras "Grupo N"; título del bloque | parcial (bloques fijos) | sí | media |
| Brillo en icono o barra al tener un debuff | no | sí *(inferido)* | media |
| Debuffs personalizados (lista blanca/negra por ID) | no | sí (`includeSpellIDs`/`excludeSpellIDs`) | media |
| Buffs vigilados con más destinos (roles, clases) | parcial (todos/tanques) | sí, fuera de combate | media |
| Iconos de clase, rol, líder y marca de banda | no | sí | media |
| Tooltip configurable con la lista de clics | parcial | sí | media |
| Atajos de rueda o teclado sobre la barra | no | sí *(snippet seguro OnEnter/OnLeave, inferido)* | media |
| Listas privadas (tus tanques o sanadores) | no | sí (nameList, fuera de combate) | media |
| Importar/exportar skins por separado; compartir | parcial (perfil completo) | sí | media |
| Evitar cursor azul / seleccionar al lanzar | **sí** (pestaña Clics) | sí | — |
| Lanzar al pulsar o soltar | sí | sí | — |
| Barras auxiliares genéricas (24 tipos) | no | parcial: poder, entrante y escudos sí; amenaza y curas recientes no | baja |
| Overheal y overshield | no | parcial *(inferido)* | baja |
| Ocultar el texto con la vida llena (en combate) | no | parcial *(curva hacia alfa, inferido)* | baja |
| Desvanecer o avisar cuando un aura va a expirar | no | **no** (compara duraciones) | — |
| % de amenaza, barra de amenaza | no | **no** | — |
| Flecha de dirección fuera de rango | no | **no** (posiciones restringidas) | — |
| SmartCast (el addon elige el hechizo) | no | **no** (prohibido: decide qué lanzar) | — |
| Health Drop, Group Bars, Hot Bars, orden por vida | no | **no** (calculan con secretos) | — |

## 3. Las 10 mejoras de más valor (sobre todo personalización)

1. **Sistema de estilos (skins).** Separar del perfil la parte visual (barras, textos, iconos, colores, disposición). Estilos con nombre: crear, duplicar, borrar y renombrar. Requiere migración de datos v1→v2.
2. **Estilos incluidos y cambio automático por contexto.** Por ejemplo "Compacto 40", "Grupo grande" y "Estilo HealBot", con una regla de qué estilo usar en solitario, grupo y banda 10/20/40. Fuera de combate; en combate se encola.
3. **Tipografía y disposición de textos.** Para nombre, vida y estado: fuente, tamaño, contorno, ancla, offsets y máximo de caracteres.
4. **Más texturas y colores.** Texturas propias y de LibSharedMedia, color y alfa del fondo, curva de vida editable, y modos "rol" y "personalizado".
5. **Barra entera teñida por el tipo de dispel.** Opción anillo / barra / ambos, con su alfa.
6. **Layout de los iconos de aura.** Ancla, dentro o fuera de la barra, separación, dirección de crecimiento, zoom y fuente de la cuenta atrás.
7. **Bordes y resaltados.** Borde de unidad, estilo del aggro (parpadeo o brillo), resaltado al pasar el ratón y del objetivo actual.
8. **Barra de maná para sanadores**, con indicador de maná bajo.
9. **Orientación y disposición.** Barras verticales, crecer desde las 4 esquinas, escala, estrato, fondo y borde del marco, cabeceras "Grupo N".
10. **Iconos de estado y tooltip útil.** Rol, líder, marca de banda, ready check, y un tooltip con lo que hace cada clic.

**Descartados por las reglas de Forever:**
- SmartCast.
- Avisos por duración de auras.
- % de amenaza.
- Curas recientes.
- Health Drop.
- Barras de grupo u HoT que dependen de la vida.
- Orden por vida.
- Flecha de dirección.
