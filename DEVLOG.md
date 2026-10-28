# 🧙‍♂️ Grimoire Studio — Devlog: La Gran Actualización de Acabados, Fabricación y Reglas

**Fecha:** 28 de Octubre, 2026  
**Versión:** v0.6.0  
**Estado:** Producción / Rama Principal (`main`)  

---

## 🌟 Resumen de la Actualización

Esta entrega marca uno de los hitos más ambiciosos en el desarrollo de **Grimoire Studio**. Hemos transformado la herramienta de un motor de maquetación y prototipado rápido en una **suite integral de publicación y diseño de juegos de mesa y TCGs (Trading Card Games)**. 

Con esta actualización cerramos la brecha completa entre el diseño conceptual de cartas, el balance matemático del mazo, el acabado visual de imprenta profesional, la exportación a fabricantes físicos y digitales, y la redacción del manual de reglas oficial del juego.

---

## 🚀 Novedades Destacadas

### 1. 🖼️ Sincronización Automática de Arte y Base de Datos (`art_url`)
* **Problema resuelto:** Anteriormente, algunas cartas mostraban la columna `art_url` vacía en la vista de base de datos a pesar de tener una ilustración asignada en la plantilla de su categoría.
* **Sincronización bidireccional inmediata:** Al asignar o modificar cualquier imagen desde el Inspector de Capas, la ruta del archivo se refleja instantáneamente en la fila activa del CSV/BD (`bindingKey` o `art_url`).
* **Resolución inteligente de variables:** La función de sincronización ahora inspecciona las capas visuales de cada plantilla asignada y puebla automáticamente las rutas relativas (`assets/...`) para todas las cartas existentes.
* **Herencia en creación de cartas:** Toda nueva carta creada o duplicada hereda la ilustración de su plantilla predeterminada o carta base, garantizando consistencia total en el catálogo.

---

### 2. 🖨️ Conectores con Fabricantes y Plataformas Digitales
Grimoire Studio ahora se integra de forma nativa con los estándares industriales de producción de cartas:

* **The Game Crafter (TGC):**
  * Formato Poker estándar: **825 × 1125 px a 300 DPI** (área segura + sangrado de 36 px / bleed zone).
  * Generación automática del archivo de metadatos `thegamecrafter_manifest.json`.
  * Generación de una guía paso a paso para carga directa a la plataforma web.
* **MakePlayingCards (MPC):**
  * Dimensiones Poker internacionales: **816 × 1110 px a 300 DPI** (63 × 88 mm + bleed de corte).
  * Estructuración automática de paquetes con carpetas organizadas `fronts/` (frentes) y `backs/` (reversos).
  * Instrucciones integradas en `mpc_order_guide.txt` para pedidos sin errores de alineación.
* **Screentop.gg (Mesa Digital Web):**
  * Generador de **Hojas de Sprites en Cuadrícula (Grid Sheets)** optimizadas para navegadores web.
  * Exportación con esquema `screentop_asset.json` listo para arrastrar y soltar en Screentop.gg sin configurar coordenadas manualmente.

---

### 3. 📖 Creador del Manual de Reglas (Rulebook Builder)
Se incorpora una pantalla dedicada al diseño y maquetación del libro de reglas del juego, accesible desde el menú lateral o con el atajo global **`Ctrl + 6`**:

* **Gestor de Secciones Modular:**
  1. **Portada & Lore:** Título del juego, autores, sinopsis y ambientación.
  2. **Componentes del Juego:** Conteo automático e inteligente de cartas agrupadas por categoría y multiplicador de copias (`qty`) directo desde la base de datos.
  3. **Objetivo & Preparación (Setup):** Instrucciones de inicio de partida paso a paso.
  4. **Fases del Turno:** Secuencia detallada de rondas de juego con títulos y descripciones.
  5. **Anatomía de una Carta:** Desglose visual y explicativo de los elementos de las cartas (coste, tipo, caja de texto, estadísticas).
  6. **Glosario:** Términos clave y palabras reservadas del reglamento.
  7. **Preguntas Frecuentes (FAQ):** Resolución de dudas comunes y casos límite.
* **Exportación de Folleto A5 (PDF Imprimible):**
  * Motor de renderizado vectorial en formato A5 multipágina listo para impresión en folleto grapado o plegado.
  * Portada temática con tipografías y paleta oscura de la suite.

---

### 4. 🎨 Acabados Visuales "Premium" (Efecto TCG Profesional)

#### A. Badges, Costes de Maná y Símbolos en Línea
El motor de renderizado de texto ahora reconoce sintaxis de insignias enriquecidas tanto en español como en inglés:
* **Costes numéricos:** `{0}` al `{9}`
* **Elementos y maná:** `{fuego}` / `{fire}`, `{agua}` / `{water}`, `{planta}` / `{nature}`, `{luz}` / `{light}`, `{sombra}` / `{dark}`
* **Acciones y combate:** `{girar}` / `{tap}` / `{T}`, `{espada}` / `{sword}`, `{escudo}` / `{shield}`, `{vida}` / `{heart}`, `{calavera}` / `{skull}`, `{estrella}` / `{star}`, `{accion}` / `{action}`
* Se agregaron chips de inserción rápida de un clic en el Inspector de Capas.

#### B. Trazo Exterior de Texto (Stroke Outline)
* Soporte nativo para contornos y trazos en capas de texto y títulos (`textStrokeWidth` y `textStrokeColor`).
* Renderizado nítido en doble pasada (capa de trazo + capa de relleno) que garantiza legibilidad cinematográfica sobre ilustraciones detalladas y fondos oscuros.

#### C. Simulación Holográfica 3D (Foil Shaders)
El visor 3D interactivo incorpora simulación de acabados coleccionables:
* **Rainbow Foil:** Refracción espectral iridiscente según el ángulo de inclinación de la carta.
* **Secret Rare Gold:** Relieve dorado reflectante con brillo metálico.
* **Cosmic Prism:** Efecto estelar dispersivo ideal para cartas legendarias o ultra raras.

---

### 5. 📊 Dashboard de Analítica y Balance de Mazo (`Ctrl + 5`)
Diseñado para game designers que buscan afinar la curva y viabilidad de su juego:
* **Curva de Coste / Maná:** Gráficos de barras interactivos con promedios y distribución por turnos.
* **Distribución de Tipos & Categorías:** Gráficos de tarta con desglose porcentual de criaturas, hechizos, artefactos, etc.
* **Estadísticas de Combate:** Ratios de Ataque vs. Defensa y promedios por nivel de coste.
* **Alertas Inteligentes de Balance:** Detección de cartas excesivamente poderosas o fuera de curva (outliers).
* **Simulador de Manos Iniciales (Mulligan):**
  * Simulación Monte Carlo de extracciones iniciales (manos de 5, 7 o personalizadas).
  * Cálculo de probabilidad matemática exacta mediante **distribución hipergeométrica** para predecir la probabilidad de robar cartas clave en el turno 1.

---

## 🛠️ Mejoras Técnicas y Control de Calidad

* **191 Pruebas Automatizadas Pasando al 100%:** Suite de tests unitarios y de widgets ejecutada sin fallos (`flutter test`).
* **Análisis de Código Limpio:** 0 advertencias y 0 errores en `dart analyze`.
* **Auditoría de Seguridad Realizada:** Verificación estricta de ausencia de tokens, claves privadas, variables de entorno locales o archivos sensibles en el control de versiones.
* **Nuevo Instalador para Windows:**
  * Compilado en modo Release nativo x64.
  * Empaquetado en un único ejecutable instalador con NSIS: `Grimoire_Studio_Setup.exe` (18.88 MB).
  * Sin dependencias externas ni requisitos de permisos elevados.

---

## 🗺️ Próximos Pasos en el Roadmap

1. **Localización de Manuales:** Soporte multilingüe simultáneo para el exportador de reglas (ES / EN).
2. **Plantillas Foil Personalizadas:** Permitir máscaras UV monocromáticas en PNG para definir áreas exactas con acabado holográfico en la carta física.
3. **Generación Asistida por IA de Variaciones:** Creación de versiones alternas de cartas (Full Art, Promo) manteniendo la estructura de datos intacta.

---

*¡Gracias por acompañarnos en la forja de Grimoire Studio!* 🎴✨
