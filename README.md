# Healsilus

Marcos de curación con click-casting (estilo HealBot) para **World of Warcraft: Forever**, hechos desde cero para las restricciones de addons de la arquitectura Midnight (valores secretos).

## Qué hace

- Click-casting: botón del ratón + Alt/Ctrl/Shift → hechizo (con rango opcional), macro, objetivo o menú.
- Barras de grupo y banda (10/20/40), bloque de tanques, mascotas, objetivo y foco amistosos.
- Curación entrante y escudos, rango, aggro, muerto y desconectado.
- Tus HoTs con cuenta atrás, debuffs con el color del tipo de dispel y buffs tuyos que faltan.
- Perfiles por clase, por personaje y por especialización. Exportar e importar.
- Perfil de serie para druida.

## Normas de Blizzard

El addon nunca decide qué hechizo lanzar ni a quién: cada lanzamiento es un clic tuyo sobre una asignación fija. Los valores secretos solo se pasan a widgets nativos y nada seguro se toca en combate.

## Instalación (desarrollo)

```powershell
powershell -ExecutionPolicy Bypass -File tools/link-addon.ps1
```

Luego, en el juego, `/reload` y `/hs`.

## Comandos

| Comando | Qué hace |
|---|---|
| `/hs` | Abre la configuración |
| `/hs diag` | Diagnóstico del cliente y del addon |
| `/hs lock` | Bloquea o desbloquea los marcos para moverlos |
| `/hs preview 5` (10, 20, 40) | Vista previa con miembros falsos; `/hs preview` la cierra |
| `/hs debug` | Mensajes de depuración |

## Pruebas

Necesitas LuaJIT (`scoop install luajit`). Desde la raíz del repositorio:

```powershell
luajit tests/run.lua
```

```powershell
luajit tools/check.lua
```

La verificación en el juego está en [docs/testing/in-game-checklist.md](docs/testing/in-game-checklist.md).
