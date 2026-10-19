# 🎴 Grimoire Studio — Guía de Configuración & Textos para Itch.io

Esta guía contiene la información exacta y los textos formateados listos para copiar y pegar en el formulario de publicación de tu página de proyecto en **itch.io** (según los campos mostrados en tus capturas de pantalla).

---

## 📋 Resumen Rápido de Campos de itch.io

| Campo | Valor Recomendado | Explicación |
|---|---|---|
| **Custom noun** | `card creator` *(o dejar en blanco para 'tool')* | Cómo se refiere itch.io a tu proyecto en descargas y botones ("Download this card creator"). |
| **Tags** *(Máximo 10)* | `card-game`, `tabletop`, `boardgame`, `tcg`, `tools`, `game-development`, `prototyping`, `design-tool`, `generator`, `printing` | Etiquetas de búsqueda clave para que creadores de juegos de mesa y diseñadores indie encuentren tu herramienta. |
| **AI generation disclosure** | **Yes** *(si incluyes imágenes de muestra generadas o el motor de arte AI)* ó **No** *(si consideras sólo el código/software)* | Ver sección detallada abajo con el texto de divulgación para copiar. |
| **App store links** | Dejar vacío | *(A menos que ya lo tengas subido a Steam o Windows Store).* |
| **Community** | `Comments` (Predeterminado) o `Discussion board` | `Comments` es ideal para comenzar. Si quieres foros separados para bugs y sugerencias, elige `Discussion board`. |
| **Visibility & access** | `Draft` (Borrador inicial) | Guárdalo como Draft para previsualizar el diseño de tu página. Una vez estés satisfecho, cámbialo a `Public`. |

---

## 🏷️ 1. Tags sugeridos (Copiar y pegar)

Copia y pega estos 10 tags en el campo **Tags**:
```text
card-game, tabletop, boardgame, tcg, tools, game-development, prototyping, design-tool, generator, printing
```

---

## 🤖 2. Divulgación de IA (AI Generation Disclosure)

Si utilizas el motor integrado de generación de imágenes (Pollinations.ai / IA local) o tus cartas de muestra tienen arte generado por IA:
- Selecciona: **◉ Yes — This project contains the output of Generative AI**
- En el campo de explicación que aparece, pega este texto en inglés:

> **AI Disclosure:**
> Grimoire Studio is an independent software tool for tabletop game designers. The application includes optional built-in generative AI features (via Pollinations.ai) to help creators generate prototype card illustrations, as well as sample starter card templates with AI-assisted placeholder artwork. All code, UI, architecture, and canvas engines were developed originally.

*(Si distribuyes el ejecutable limpio sin ninguna ilustración generada por IA, puedes marcar **◉ No**).*

---

## 🏷️ 3. Custom Noun

- Escribe: `card creator`  
*(O déjalo vacío si prefieres el término estándar `tool`).*

---

## 💬 4. Community & Visibility

- **Community:** Marca `◉ Comments — Add a nested comment thread to the bottom of the project page`
- **Visibility:** Marca `◉ Draft — Only those who can edit the project can view the page` (luego de guardar y ver la vista previa, pulsa `Public`).

---

## 📝 5. Campo "Description" (Contenido principal de la página)

A continuación tienes dos versiones de la descripción:
1. **Versión en Inglés (Recomendada):** La gran mayoría de usuarios de itch.io que buscan herramientas de desarrollo de juegos de mesa buscan en inglés.
2. **Versión en Español:** Por si deseas orientar tu página a la comunidad hispanohablante.

> **💡 Consejo para itch.io:** Puedes presionar el botón `<>` en la barra de herramientas del editor de itch.io para pegar el código HTML directamente con negritas, títulos y listas ya formateadas, o bien pegar el texto plano en el editor visual.

---

### 🌐 Opción A: Descripción en Inglés (Recomendada)

```html
<p align="center">
  <h2><b>🎴 Grimoire Studio — The Ultimate Card Creator & Tabletop Prototyping Suite</b></h2>
  <p><i>Design, batch-generate, playtest, and print professional dual-sided cards for TCGs, board games, and RPGs.</i></p>
</p>

<hr/>

<h3>✨ Overview</h3>
<p>
<b>Grimoire Studio</b> is an all-in-one desktop card crafting studio designed from the ground up for indie game developers, tabletop designers, TCG enthusiasts, and RPG game masters. Whether you're designing a collectible card game, an expansive deck-builder, or custom cards for your next board game night, Grimoire Studio gives you the creative power of a professional graphic suite combined with the automation of a spreadsheet database.
</p>

<hr/>

<h3>🚀 Key Features</h3>

<ul>
  <li><b>🎨 Visual Drag & Drop Canvas:</b> Intuitive WYSIWYG editor with multi-layer stacking (Text, Dynamic Images, Vector Shapes, Backgrounds, and Frames). Enjoy fluid pan, zoom, alignment guides, and layer ordering.</li>
  <li><b>🃏 True Dual-Sided Cards:</b> Easily switch between Front and Back faces with a single click. Keep separate back designs or unified card backs across your entire game.</li>
  <li><b>📊 Dynamic Data-Binding & CSV Batch Generation:</b> Connect any layer on your card to database variables (like <code>card_name</code>, <code>rules_text</code>, <code>art_url</code>, attack, defense, cost). Change values in the built-in database table or import your CSV spreadsheet, and watch hundreds of cards update in real time!</li>
  <li><b>⚡ Predefined Starter Templates:</b> Don't start from scratch! Choose from ready-to-use template presets:
    <ul>
      <li><b>Default:</b> Clean, balanced layout (Title, Art, Container Shape, Description).</li>
      <li><b>Fantasy TCG:</b> Classic Magic / Hearthstone style with cost orbs and attribute shields.</li>
      <li><b>Board Game Action:</b> Dynamic action and event frames.</li>
      <li><b>Tarot & Hero:</b> Vertical portrait frames with mystic lore banners.</li>
      <li><b>Cyberpunk Neon:</b> Sci-fi holographic layout with neon accents.</li>
      <li><b>Minimalist Modern:</b> High-legibility, clean layout for eurogames.</li>
    </ul>
  </li>
  <li><b>🖨️ Print-and-Play (PnP) Ready:</b> Export your entire deck directly to high-resolution PDF with cut marks, margins, bleeds, and standard page formats (Letter, A4, Poker 63x88mm, Tarot 70x120mm, Mini cards). Export high-DPI individual PNGs or ZIP packages in seconds.</li>
  <li><b>🤖 Optional Built-in AI Art Generator:</b> Need quick placeholder art for your playtests? Use the integrated, free cloud AI generator (Pollinations.ai) to bring your characters, monsters, and spells to life without leaving the software.</li>
  <li><b>🎲 Built-in Playtest Simulator:</b> Test and draw your cards directly on an interactive tabletop surface before sending them to the printer.</li>
  <li><b>🔒 100% Offline & Private:</b> Your game assets, custom CSVs, and card mechanics remain stored safely and locally on your machine.</li>
</ul>

<hr/>

<h3>💻 System Requirements</h3>
<ul>
  <li><b>Operating System:</b> Windows 10 / 11 (64-bit)</li>
  <li><b>Processor:</b> 1.6 GHz or faster 64-bit processor</li>
  <li><b>Memory:</b> 4 GB RAM recommended</li>
  <li><b>Storage:</b> ~200 MB free disk space for installation</li>
  <li><b>Display:</b> 1280x720 minimum resolution (1080p recommended)</li>
</ul>

<hr/>

<h3>📦 Installation</h3>
<ol>
  <li>Download the <b>Grimoire_Studio_Setup.exe</b> (or standalone ZIP archive).</li>
  <li>Run the installer or extract to your preferred folder.</li>
  <li>Launch <b>Grimoire Studio</b> and start creating your first game!</li>
</ol>

<hr/>

<h3>💬 Feedback & Support</h3>
<p>
Grimoire Studio is actively maintained and evolved. If you have feature requests, suggestions, or bug reports, feel free to leave a comment below or join our community discussions!
</p>
```

---

### 🇪🇸 Opción B: Descripción en Español

```html
<p align="center">
  <h2><b>🎴 Grimoire Studio — Editor y Creador de Cartas para Juegos de Mesa y TCG</b></h2>
  <p><i>Diseña, automatiza por lotes, prueba y exporta cartas profesionales a doble cara listas para imprimir.</i></p>
</p>

<hr/>

<h3>✨ ¿Qué es Grimoire Studio?</h3>
<p>
<b>Grimoire Studio</b> es una suite de diseño y prototipado pensada específicamente para creadores independientes de juegos de mesa, desarrolladores de cartas coleccionables (TCG), juegos de rol (RPG) y aficionados. Combina la flexibilidad de un editor visual por capas con la potencia de una base de datos vinculada a hojas de cálculo (CSV), permitiéndote diseñar una plantilla y generar cientos de cartas únicas al instante.
</p>

<hr/>

<h3>🚀 Características Principales</h3>

<ul>
  <li><b>🎨 Lienzo Visual Drag & Drop:</b> Editor WYSIWYG intuitivo con soporte de capas múltiples (Texto enriquecido, Imágenes dinámicas, Formas vectoriales, Fondos y Marcos). Incluye zoom, paneo fluido y guías de alineación.</li>
  <li><b>🃏 Cartas a Doble Cara (Front / Back):</b> Alterna fácilmente entre el anverso y reverso con un clic. Diseña reversos únicos o compartidos para todo tu mazo.</li>
  <li><b>📊 Vinculación Dinámica & Generación Masiva por CSV:</b> Conecta cualquier elemento visual a columnas de datos (como <code>card_name</code>, <code>rules_text</code>, <code>art_url</code>, coste o ataque). Modifica la tabla y observa cómo todas tus cartas se actualizan automáticamente.</li>
  <li><b>⚡ Estilos y Plantillas Predefinidas:</b> Comienza en segundos con estilos listos para usar:
    <ul>
      <li><b>Default:</b> Estructura limpia y estándar (Título, Imagen central, Contenedor y Descripción).</li>
      <li><b>TCG Fantasía:</b> Estilo clásico de fantasía (estilo Magic / Hearthstone) con orbes de coste y atributos.</li>
      <li><b>Juego de Mesa Acción:</b> Marcos dinámicos para cartas de eventos y acciones.</li>
      <li><b>Tarot y Héroes:</b> Retratos verticales con estética mística.</li>
      <li><b>Cyberpunk Neón:</b> Líneas futuristas con estética de interfaz holográfica.</li>
      <li><b>Minimalista Moderno:</b> Diseño limpio con máxima legibilidad para juegos europeos.</li>
    </ul>
  </li>
  <li><b>🖨️ Print-and-Play (PnP) & Exportación de Alta Resolución:</b> Genera PDFs listos para imprenta con marcas de corte, sangrado y soporte para tamaños estándar (Poker 63x88mm, Tarot 70x120mm, Mini cartas). Exporta imágenes PNG individuales en alta resolución o en paquetes ZIP.</li>
  <li><b>🤖 Generador de Arte IA Opcional:</b> Genera arte provisional para tus prototipos directamente desde la app mediante IA en la nube gratuita (Pollinations.ai).</li>
  <li><b>🎲 Simulador de Playtesting Integrado:</b> Pon a prueba y roba cartas de tu mazo en una mesa virtual interactiva antes de imprimir.</li>
  <li><b>🔒 100% Local y Privado:</b> Tus proyectos, imágenes y mecánicas de juego permanecen siempre seguros en tu computadora.</li>
</ul>

<hr/>

<h3>💻 Requisitos del Sistema</h3>
<ul>
  <li><b>Sistema Operativo:</b> Windows 10 / 11 (64-bit)</li>
  <li><b>Memoria:</b> 4 GB de RAM (recomendado)</li>
  <li><b>Almacenamiento:</b> ~200 MB de espacio libre</li>
  <li><b>Resolución de pantalla:</b> 1280x720 mínimo (1080p recomendado)</li>
</ul>

<hr/>

<h3>📦 Instalación</h3>
<ol>
  <li>Descarga el instalador <b>Grimoire_Studio_Setup.exe</b> (o el archivo ZIP independiente).</li>
  <li>Ejecuta el instalador o descomprime los archivos en tu carpeta deseada.</li>
  <li>¡Abre <b>Grimoire Studio</b> y da vida a tu primer juego!</li>
</ol>
```
