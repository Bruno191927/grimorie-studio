---
name: grimoire-visual-design
description: Design system, UI/UX specification, color palette, and component guidelines for Grimoire Studio based on the modern dark-themed collectible card aesthetic.
---

# Grimoire Studio — Visual Design System & UI Specification

Este skill documenta la dirección visual, tokens de diseño, sistema de componentes y directrices estéticas para **Grimoire Studio**, inspirada en la interfaz moderna de galerías de coleccionables digitales y herramientas de diseño para tabletop.

---

## 1. Filosofía de Diseño y Estética

- **Dark Fantasy / High-Tech Moderno**: Fondo ultra oscuro con matices azul marino y carbón (`#0B0E14`), superficies elevadas en capas (`#131622`, `#1A1D2E`), y acentos vibrantes neón violeta (`#7C3AED`), índigo (`#6366F1`) y coral/ámbar para elementos interactivos.
- **Jerarquía y Densidad Profesional**: Inspirado en suites creativas y colecciones modernas, combinando densidad de datos con acabados pulidos: bordes sutiles de 1px con brillo tenue, tarjetas con esquinas redondeadas (16px), micro-badges de estados, y tipografía moderna geométrica.
- **Enfoque en el Arte de las Cartas**: El contenido visual (las cartas e ilustraciones generadas por IA) es el protagonista. Los marcos de las cartas tienen fondos contrastantes, marcos estilizados y micro-etiquetas de juego (coste de maná, rareza, creador, estadísticas).

---

## 2. Paleta de Colores y Tokens Semánticos

| Token | Hex / Valor | Uso |
| :--- | :--- | :--- |
| `--bg-canvas` | `#0B0E14` | Fondo principal de la ventana y lienzo de trabajo |
| `--surface-panel` | `#111420` | Barra superior, barras laterales y paneles de herramientas |
| `--surface-card` | `#171B2B` | Fondo de las tarjetas de cartas y contenedores flotantes |
| `--surface-card-hover`| `#1F243A` | Estado hover de tarjetas e inspectores |
| `--border-subtle` | `#23283E` | Bordes divisorios estándar de paneles y cards (1px solid) |
| `--border-focus` | `#7C3AED` | Borde activo / seleccionado con resplandor suave (`box-shadow`) |
| `--accent-primary` | `#7C3AED` | Color primario de marca (violeta místico) |
| `--accent-secondary`| `#6366F1` | Color secundario (índigo vibrante para botones de acción) |
| `--accent-badge` | `#3B82F6` | Píldoras de facciones, escuelas y tipos de carta |
| `--accent-flame` | `#F59E0B` | Píldora de contador de maná / tiempo con icono de llama |
| `--text-primary` | `#F8FAFC` | Títulos principales, nombres de cartas y encabezados |
| `--text-secondary` | `#94A3B8` | Subtítulos, autores, etiquetas de atributos y filtros |
| `--text-muted` | `#64748B` | Textos de ayuda, leyendas y valores deshabilitados |
| `--rarity-mythic` | `#EC4899` | Borde y resplandor para cartas Míticas / Legendarias |
| `--rarity-rare` | `#8B5CF6` | Borde y resplandor para cartas Raras |
| `--rarity-uncommon`| `#3B82F6` | Borde y resplandor para cartas Poco Comunes |
| `--rarity-common` | `#64748B` | Borde neutro para cartas Comunes |

---

## 3. Anatomía de Componentes Clave

### A. Barra Superior de Navegación (Global Header)
- **Logotipo de Grimoire Studio**: Isotipo de llama mística / tomo arcano con gradiente violeta-índigo (`from-purple-600 to-indigo-500`) + texto en negrita.
- **Buscador Rápido**: Input encapsulado con icono de lupa, placeholder estilizado (`"Buscar cartas, variables {{...}}, tags..."`).
- **Navegación de Modos**:
  - `Estudio / Editor` (Lienzo interactivo de capas y reglas condicionales)
  - `Galería de Cartas` (Explorador estilo marketplace con filtros)
  - `Base de Datos` (Gestor de tablas CSV / JSON con live-binding)
  - `Generador IA` (Pipeline local ComfyUI/Ollama y APIs Cloud)
  - `Playtest Table` (Mesa virtual interactiva)
  - `Exportar 300 DPI` (Generación de hojas de imprenta PDF / ZIP)
- **Acciones Rápidas**: Botón con píldora redondeada `"Conectar IA Local / Cloud"`, selector de tema claro/oscuro y estado del proyecto.

### B. Barra Lateral de Filtros y Atributos (Left Filter Sidebar)
- **Encabezado**: Título `"Filtros"` con botón de acción `"Limpiar"` o `"Reset"`.
- **Secciones Desplegables**:
  - **Tipos de Carta**: Criatura, Hechizo, Artefacto, Tierra / Entorno, Héroe, Encantamiento.
  - **Rareza**: Común, Rara, Épica, Mítica, Legendaria.
  - **Coste de Maná**: Slider interactivo de 0 a 10+.
  - **Estado de Generación IA**: Con Arte Final, Con Prompt Pendiente, Arte Placeholder.
  - **Formatos de Exportación**: Poker (63.5 x 88.9 mm), Tarot (70 x 120 mm), Cuadrado.

### C. Tarjeta de Carta de Grimoire (Card Showcase Tile)
Inspirada en el layout de la imagen de referencia:
1. **Header de la Tarjeta**:
   - Avatar del autor o mazo (círculo con borde)
   - Nombre de plantilla / mazo (ej. `Mazo Sombras • Tyler C.`)
   - Botón de favoritos / marcador con contador (`❤️ 100`)
2. **Área de Arte / Ilustración**:
   - Marco redondeado con fondo temático en degradado pastel suave o resplandor de elemento (fuego, hielo, bosque, vacío).
   - Ilustración del personaje o carta generada en alta fidelidad 3D / estilizada.
   - **Píldora Flotante Inferior**: Fondo translúcido oscuro con icono de llama y estadísticas clave (ej. `🔥 5 Maná · 4 ATK / 3 DEF` o temporizador de exportación).
3. **Pie de la Tarjeta**:
   - Título de la carta entre comillas o negrita: `"Flame Dress"`, `"Gólem Ancestral"`.
   - Fila de datos: Coste o valor activo, junto con etiqueta de tipo/facción con fondo de color suave (ej. `BSC`, `FUEGO`, `ÉPICA`).

---

## 4. Disposición de los Módulos de Grimoire Studio

```
┌────────────────────────────────────────────────────────────────────────┐
│  🔥 Grimoire Studio   [🔍 Buscar cartas/tags...]   [Modos]  [⚙️ Conectar IA]│
├───────────────┬────────────────────────────────────────┬───────────────┤
│ FILTROS       │ GALERÍA DE CARTAS / LIENZO             │ INSPECTOR     │
│               │                                        │               │
│ • Categorías  │  [Tarjeta 1]   [Tarjeta 2]   [Tarjeta 3]│ • Propiedades │
│ • Rarezas     │  [Tarjeta 4]   [Tarjeta 5]   [Tarjeta 6]│ • Data-Binding│
│ • Coste Maná  │  [Tarjeta 7]   [Tarjeta 8]   [Tarjeta 9]│ • Prompt IA   │
│ • Filtro IA   │                                        │ • Smart Tokens│
│               │  [ Cargar Más Cartas / Exportar Todo ] │               │
├───────────────┴────────────────────────────────────────┴───────────────┤
│ 📊 Tabla de Datos Activa: cards.csv | 1,000 cartas sincronizadas       │
└────────────────────────────────────────────────────────────────────────┘
```
