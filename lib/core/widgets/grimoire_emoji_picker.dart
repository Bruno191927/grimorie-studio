import 'package:flutter/material.dart';
import '../theme/grimoire_theme.dart';

class EmojiItem {
  final String emoji;
  final String name;
  final String category;
  final List<String> keywords;

  const EmojiItem({
    required this.emoji,
    required this.name,
    required this.category,
    this.keywords = const [],
  });
}

class GrimoireEmojiPicker extends StatefulWidget {
  final String? initialEmoji;
  final ValueChanged<String> onEmojiSelected;

  const GrimoireEmojiPicker({
    super.key,
    this.initialEmoji,
    required this.onEmojiSelected,
  });

  static Future<String?> show(BuildContext context, {String? currentEmoji}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 520,
          height: 560,
          child: GrimoireEmojiPicker(
            initialEmoji: currentEmoji,
            onEmojiSelected: (selected) {
              Navigator.of(ctx).pop(selected);
            },
          ),
        ),
      ),
    );
  }

  @override
  State<GrimoireEmojiPicker> createState() => _GrimoireEmojiPickerState();
}

class _GrimoireEmojiPickerState extends State<GrimoireEmojiPicker> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customInputController = TextEditingController();
  String _selectedCategory = 'Todos';
  String? _hoveredEmoji;
  String? _hoveredName;

  static const List<String> categories = [
    'Todos',
    'Fantasía & TCG',
    'Criaturas & Animales',
    'Magia & Elementos',
    'Armas & Objetos',
    'Símbolos & Cartas',
    'Monstruos & Héroes',
  ];

  static final List<EmojiItem> allEmojis = [
    // --- FANTASÍA & TCG ---
    const EmojiItem(emoji: '🦄', name: 'Unicornio', category: 'Fantasía & TCG', keywords: ['unicorn', 'unicornio', 'kawaii', 'establo', 'cuerno', 'magico']),
    const EmojiItem(emoji: '🐉', name: 'Dragón', category: 'Fantasía & TCG', keywords: ['dragon', 'dragón', 'fuego', 'bestia', 'reptil']),
    const EmojiItem(emoji: '🧙‍♂️', name: 'Mago', category: 'Fantasía & TCG', keywords: ['mago', 'wizard', 'hechicero', 'conjuro', 'arcano']),
    const EmojiItem(emoji: '🧝‍♀️', name: 'Elfa', category: 'Fantasía & TCG', keywords: ['elfa', 'elf', 'bosque', 'arquera']),
    const EmojiItem(emoji: '🧚', name: 'Hada', category: 'Fantasía & TCG', keywords: ['hada', 'fairy', 'magia', 'pixie', 'alas']),
    const EmojiItem(emoji: '🧞', name: 'Genio', category: 'Fantasía & TCG', keywords: ['genio', 'genie', 'deseo', 'lampara']),
    const EmojiItem(emoji: '🧜', name: 'Sirena / Tritón', category: 'Fantasía & TCG', keywords: ['sirena', 'mermaid', 'agua', 'oceano']),
    const EmojiItem(emoji: '🧛', name: 'Vampiro', category: 'Fantasía & TCG', keywords: ['vampiro', 'vampire', 'sangre', 'noche', 'colmillos']),
    const EmojiItem(emoji: '🧟', name: 'Zombi', category: 'Fantasía & TCG', keywords: ['zombi', 'zombie', 'no muerto', 'muerte', 'horda']),
    const EmojiItem(emoji: '🔮', name: 'Bola de Cristal', category: 'Fantasía & TCG', keywords: ['cristal', 'oraculo', 'magia', 'adivinacion', 'futuro']),
    const EmojiItem(emoji: '📜', name: 'Pergamino / Conjuro', category: 'Fantasía & TCG', keywords: ['pergamino', 'scroll', 'conjuro', 'hechizo', 'reglas']),
    const EmojiItem(emoji: '🪄', name: 'Varita Mágica', category: 'Fantasía & TCG', keywords: ['varita', 'wand', 'magia', 'hechizo', 'encantamiento']),
    const EmojiItem(emoji: '👑', name: 'Corona', category: 'Fantasía & TCG', keywords: ['corona', 'crown', 'rey', 'reina', 'realeza', 'lider']),
    const EmojiItem(emoji: '🏰', name: 'Castillo', category: 'Fantasía & TCG', keywords: ['castillo', 'fortaleza', 'torre', 'reino']),
    const EmojiItem(emoji: '💎', name: 'Gema / Cristal', category: 'Fantasía & TCG', keywords: ['gema', 'diamante', 'cristal', 'tesoro', 'recurso']),
    const EmojiItem(emoji: '💀', name: 'Calavera', category: 'Fantasía & TCG', keywords: ['calavera', 'skull', 'muerte', 'esqueleto', 'peligro']),
    const EmojiItem(emoji: '⚰️', name: 'Ataúd', category: 'Fantasía & TCG', keywords: ['ataud', 'coffin', 'cementerio', 'muerte', 'descarte']),
    const EmojiItem(emoji: '🧪', name: 'Poción', category: 'Fantasía & TCG', keywords: ['pocion', 'alquimia', 'elixir', 'quimica', 'cura']),
    const EmojiItem(emoji: '🗝️', name: 'Llave Antigua', category: 'Fantasía & TCG', keywords: ['llave', 'key', 'secreto', 'cerradura', 'tesoro']),
    const EmojiItem(emoji: '🪙', name: 'Moneda de Oro', category: 'Fantasía & TCG', keywords: ['moneda', 'oro', 'coin', 'coste', 'dinero']),
    const EmojiItem(emoji: '🪷', name: 'Loto Sagrado', category: 'Fantasía & TCG', keywords: ['loto', 'lotus', 'black lotus', 'mana', 'flor', 'sagrado']),
    const EmojiItem(emoji: '🧿', name: 'Ojo Protector', category: 'Fantasía & TCG', keywords: ['ojo', 'amuleto', 'proteccion', 'talismán']),
    const EmojiItem(emoji: '🏺', name: 'Urna Antigua', category: 'Fantasía & TCG', keywords: ['urna', 'vasija', 'reliquia', 'artefacto']),
    const EmojiItem(emoji: '💍', name: 'Anillo de Poder', category: 'Fantasía & TCG', keywords: ['anillo', 'ring', 'joya', 'poder', 'artefacto']),
    const EmojiItem(emoji: '📿', name: 'Rosario Místico', category: 'Fantasía & TCG', keywords: ['cuentas', 'oracion', 'monje', 'místico']),
    const EmojiItem(emoji: '📖', name: 'Grimorio / Libro', category: 'Fantasía & TCG', keywords: ['grimorio', 'libro', 'tomo', 'magia', 'conocimiento']),
    const EmojiItem(emoji: '🕯️', name: 'Vela Ritual', category: 'Fantasía & TCG', keywords: ['vela', 'ritual', 'luz', 'fuego', 'candelabro']),
    const EmojiItem(emoji: '🩸', name: 'Gota de Sangre', category: 'Fantasía & TCG', keywords: ['sangre', 'blood', 'vida', 'hp', 'sacrificio']),
    const EmojiItem(emoji: '⏳', name: 'Reloj de Arena', category: 'Fantasía & TCG', keywords: ['tiempo', 'reloj', 'espera', 'turno', 'cuenta atras']),
    const EmojiItem(emoji: '🪞', name: 'Espejo Encantado', category: 'Fantasía & TCG', keywords: ['espejo', 'reflejo', 'copia', 'clon', 'ilusion']),

    // --- CRIATURAS & ANIMALES ---
    const EmojiItem(emoji: '🐴', name: 'Caballo', category: 'Criaturas & Animales', keywords: ['caballo', 'horse', 'montura', 'corcel', 'establo']),
    const EmojiItem(emoji: '🐺', name: 'Lobo', category: 'Criaturas & Animales', keywords: ['lobo', 'wolf', 'manada', 'bestia', 'cazador']),
    const EmojiItem(emoji: '🦁', name: 'León', category: 'Criaturas & Animales', keywords: ['leon', 'lion', 'felino', 'depredador', 'rey']),
    const EmojiItem(emoji: '🐯', name: 'Tigre', category: 'Criaturas & Animales', keywords: ['tigre', 'tiger', 'rayas', 'selva', 'salvaje']),
    const EmojiItem(emoji: '🐻', name: 'Oso', category: 'Criaturas & Animales', keywords: ['oso', 'bear', 'fuerza', 'garras', 'bosque']),
    const EmojiItem(emoji: '🦅', name: 'Águila', category: 'Criaturas & Animales', keywords: ['aguila', 'eagle', 'ave', 'volar', 'cielo', 'vision']),
    const EmojiItem(emoji: '🦉', name: 'Búho Sabio', category: 'Criaturas & Animales', keywords: ['buho', 'owl', 'sabiduria', 'noche', 'ave']),
    const EmojiItem(emoji: '🦇', name: 'Murciélago', category: 'Criaturas & Animales', keywords: ['murcielago', 'bat', 'cueva', 'noche', 'vampiro']),
    const EmojiItem(emoji: '🐍', name: 'Serpiente', category: 'Criaturas & Animales', keywords: ['serpiente', 'snake', 'veneno', 'reptil', 'sigilo']),
    const EmojiItem(emoji: '🦖', name: 'T-Rex', category: 'Criaturas & Animales', keywords: ['dinosaurio', 'trex', 'rex', 'prehistorico', 'gigante']),
    const EmojiItem(emoji: '🦕', name: 'Braquiosaurio', category: 'Criaturas & Animales', keywords: ['dinosaurio', 'bronto', 'herbivoro', 'titan']),
    const EmojiItem(emoji: '🐙', name: 'Pulpo / Kraken', category: 'Criaturas & Animales', keywords: ['pulpo', 'kraken', 'tentaculos', 'mar', 'monstruo']),
    const EmojiItem(emoji: '🦈', name: 'Tiburón', category: 'Criaturas & Animales', keywords: ['tiburon', 'shark', 'mar', 'depredador', 'acuatico']),
    const EmojiItem(emoji: '🕷️', name: 'Araña', category: 'Criaturas & Animales', keywords: ['araña', 'spider', 'telaraña', 'veneno', 'trampa']),
    const EmojiItem(emoji: '🦂', name: 'Escorpión', category: 'Criaturas & Animales', keywords: ['escorpion', 'scorpion', 'veneno', 'aguijon', 'desierto']),
    const EmojiItem(emoji: '🦋', name: 'Mariposa', category: 'Criaturas & Animales', keywords: ['mariposa', 'butterfly', 'alas', 'transformacion', 'color']),
    const EmojiItem(emoji: '🐝', name: 'Abeja', category: 'Criaturas & Animales', keywords: ['abeja', 'bee', 'colmena', 'enjambre', 'picadura']),
    const EmojiItem(emoji: '🐗', name: 'Jabalí', category: 'Criaturas & Animales', keywords: ['jabali', 'boar', 'embestida', 'salvaje']),
    const EmojiItem(emoji: '🦊', name: 'Zorro', category: 'Criaturas & Animales', keywords: ['zorro', 'fox', 'astucia', 'sigilo', 'rapido']),
    const EmojiItem(emoji: '🐰', name: 'Conejo', category: 'Criaturas & Animales', keywords: ['conejo', 'rabbit', 'veloz', 'salto', 'suerte']),
    const EmojiItem(emoji: '🐱', name: 'Gato', category: 'Criaturas & Animales', keywords: ['gato', 'cat', 'felino', 'agil', 'mascota']),
    const EmojiItem(emoji: '🐶', name: 'Perro', category: 'Criaturas & Animales', keywords: ['perro', 'dog', 'lealtad', 'guardian']),
    const EmojiItem(emoji: '🐒', name: 'Mono', category: 'Criaturas & Animales', keywords: ['mono', 'monkey', 'agil', 'bromista']),
    const EmojiItem(emoji: '🐸', name: 'Rana / Sapo', category: 'Criaturas & Animales', keywords: ['rana', 'frog', 'pantano', 'veneno', 'salto']),
    const EmojiItem(emoji: '🐢', name: 'Tortuga', category: 'Criaturas & Animales', keywords: ['tortuga', 'turtle', 'caparazon', 'defensa', 'lento']),
    const EmojiItem(emoji: '🐊', name: 'Cocodrilo', category: 'Criaturas & Animales', keywords: ['cocodrilo', 'croc', 'mandibula', 'pantano']),
    const EmojiItem(emoji: '🦀', name: 'Cangrejo', category: 'Criaturas & Animales', keywords: ['cangrejo', 'crab', 'pinzas', 'mar']),
    const EmojiItem(emoji: '🦑', name: 'Calamar', category: 'Criaturas & Animales', keywords: ['calamar', 'squid', 'tinta', 'mar']),
    const EmojiItem(emoji: '🦜', name: 'Loro / Guacamayo', category: 'Criaturas & Animales', keywords: ['loro', 'parrot', 'pirata', 'ave', 'color']),
    const EmojiItem(emoji: '🦚', name: 'Pavo Real', category: 'Criaturas & Animales', keywords: ['pavo real', 'peacock', 'plumas', 'belleza']),
    const EmojiItem(emoji: '🐼', name: 'Panda', category: 'Criaturas & Animales', keywords: ['panda', 'oso', 'bambu', 'zen']),
    const EmojiItem(emoji: '🐘', name: 'Elefante', category: 'Criaturas & Animales', keywords: ['elefante', 'fuerza', 'coloso', 'trompa']),

    // --- MAGIA & ELEMENTOS ---
    const EmojiItem(emoji: '🔥', name: 'Fuego', category: 'Magia & Elementos', keywords: ['fuego', 'fire', 'llama', 'ardiente', 'rojo', 'quemar']),
    const EmojiItem(emoji: '💧', name: 'Agua', category: 'Magia & Elementos', keywords: ['agua', 'water', 'gota', 'azul', 'fluido', 'mar']),
    const EmojiItem(emoji: '⚡', name: 'Rayo / Electricidad', category: 'Magia & Elementos', keywords: ['rayo', 'lightning', 'trueno', 'electrico', 'chispa', 'volt']),
    const EmojiItem(emoji: '❄️', name: 'Hielo / Nieve', category: 'Magia & Elementos', keywords: ['hielo', 'ice', 'nieve', 'congelar', 'frio']),
    const EmojiItem(emoji: '🌪️', name: 'Tornado / Viento', category: 'Magia & Elementos', keywords: ['viento', 'tornado', 'aire', 'torbellino', 'tempestad']),
    const EmojiItem(emoji: '🌈', name: 'Arcoíris', category: 'Magia & Elementos', keywords: ['arcoiris', 'rainbow', 'color', 'unicornio', 'magia']),
    const EmojiItem(emoji: '☀️', name: 'Sol / Luz', category: 'Magia & Elementos', keywords: ['sol', 'sun', 'luz', 'dia', 'sagrado', 'cegador']),
    const EmojiItem(emoji: '🌙', name: 'Luna / Noche', category: 'Magia & Elementos', keywords: ['luna', 'moon', 'noche', 'sombra', 'oscuridad']),
    const EmojiItem(emoji: '⭐', name: 'Estrella', category: 'Magia & Elementos', keywords: ['estrella', 'star', 'brillo', 'celeste', 'deseo']),
    const EmojiItem(emoji: '🌟', name: 'Estrella Brillante', category: 'Magia & Elementos', keywords: ['estrella', 'brillante', 'resplandor', 'mejora', 'bonus']),
    const EmojiItem(emoji: '✨', name: 'Destellos Mágicos', category: 'Magia & Elementos', keywords: ['chispas', 'sparkles', 'brillo', 'purpurina', 'encanto']),
    const EmojiItem(emoji: '💥', name: 'Explosión', category: 'Magia & Elementos', keywords: ['explosion', 'impacto', 'boom', 'daño', 'critico']),
    const EmojiItem(emoji: '🌋', name: 'Volcán', category: 'Magia & Elementos', keywords: ['volcan', 'lava', 'magma', 'furia', 'tierra']),
    const EmojiItem(emoji: '🌊', name: 'Ola / Tsunami', category: 'Magia & Elementos', keywords: ['ola', 'tsunami', 'marea', 'inundacion']),
    const EmojiItem(emoji: '☄️', name: 'Cometa / Meteoro', category: 'Magia & Elementos', keywords: ['cometa', 'meteoro', 'asteroide', 'impacto', 'espacio']),
    const EmojiItem(emoji: '🪐', name: 'Planeta Cósmico', category: 'Magia & Elementos', keywords: ['planeta', 'saturno', 'cosmos', 'galaxia', 'vacio']),
    const EmojiItem(emoji: '🍃', name: 'Hojas al Viento', category: 'Magia & Elementos', keywords: ['hojas', 'naturaleza', 'verde', 'bosque', 'viento']),
    const EmojiItem(emoji: '🍄', name: 'Hongo Venenoso', category: 'Magia & Elementos', keywords: ['hongo', 'mushroom', 'espora', 'veneno', 'bosque']),
    const EmojiItem(emoji: '🌸', name: 'Flor de Cerezo', category: 'Magia & Elementos', keywords: ['flor', 'petalos', 'primavera', 'suave']),
    const EmojiItem(emoji: '🌹', name: 'Rosa de Espinas', category: 'Magia & Elementos', keywords: ['rosa', 'espinas', 'sangre', 'pasion']),
    const EmojiItem(emoji: '🫧', name: 'Burbujas', category: 'Magia & Elementos', keywords: ['burbujas', 'bubbles', 'escudo', 'agua', 'flotar']),

    // --- ARMAS & OBJETOS ---
    const EmojiItem(emoji: '⚔️', name: 'Espadas Cruzadas', category: 'Armas & Objetos', keywords: ['espadas', 'swords', 'combate', 'pelea', 'duelo', 'ataque']),
    const EmojiItem(emoji: '🗡️', name: 'Daga', category: 'Armas & Objetos', keywords: ['daga', 'cuchillo', 'asesino', 'sigilo', 'traicion']),
    const EmojiItem(emoji: '🏹', name: 'Arco y Flecha', category: 'Armas & Objetos', keywords: ['arco', 'flecha', 'distancia', 'punteria', 'arquero']),
    const EmojiItem(emoji: '🛡️', name: 'Escudo', category: 'Armas & Objetos', keywords: ['escudo', 'shield', 'defensa', 'bloqueo', 'armadura', 'guardia']),
    const EmojiItem(emoji: '🪓', name: 'Hacha de Batalla', category: 'Armas & Objetos', keywords: ['hacha', 'axe', 'leñador', 'barbaro', 'corte']),
    const EmojiItem(emoji: '🔨', name: 'Martillo de Guerra', category: 'Armas & Objetos', keywords: ['martillo', 'hammer', 'herrero', 'golpe', 'aplastar']),
    const EmojiItem(emoji: '💣', name: 'Bomba', category: 'Armas & Objetos', keywords: ['bomba', 'bomb', 'explosion', 'mecha', 'purpurina']),
    const EmojiItem(emoji: '🧨', name: 'Dinamita', category: 'Armas & Objetos', keywords: ['dinamita', 'petardo', 'fuegos artificiales']),
    const EmojiItem(emoji: '🏆', name: 'Trofeo', category: 'Armas & Objetos', keywords: ['trofeo', 'victoria', 'campeon', 'premio', 'ganar']),
    const EmojiItem(emoji: '💰', name: 'Bolsa de Monedas', category: 'Armas & Objetos', keywords: ['dinero', 'botin', 'oro', 'tesoro', 'recompensa']),
    const EmojiItem(emoji: '⚖️', name: 'Balanza de Justicia', category: 'Armas & Objetos', keywords: ['balanza', 'justicia', 'equilibrio', 'orden', 'ley']),
    const EmojiItem(emoji: '🪦', name: 'Lápida', category: 'Armas & Objetos', keywords: ['lapida', 'tumba', 'muerte', 'cementerio']),
    const EmojiItem(emoji: '🔔', name: 'Campana Alarma', category: 'Armas & Objetos', keywords: ['campana', 'alarma', 'sonido', 'aviso']),
    const EmojiItem(emoji: '🧭', name: 'Brújula', category: 'Armas & Objetos', keywords: ['brujula', 'exploracion', 'rumbo', 'norte', 'mapa']),
    const EmojiItem(emoji: '🔭', name: 'Telescopio', category: 'Armas & Objetos', keywords: ['telescopio', 'estrellas', 'vision', 'astronomia']),
    const EmojiItem(emoji: '🪝', name: 'Garfio', category: 'Armas & Objetos', keywords: ['garfio', 'pirata', 'gancho', 'atrapar']),
    const EmojiItem(emoji: '📦', name: 'Cofre / Paquete', category: 'Armas & Objetos', keywords: ['caja', 'cofre', 'suministros', 'paquete']),
    const EmojiItem(emoji: '🏷️', name: 'Etiqueta', category: 'Armas & Objetos', keywords: ['etiqueta', 'tag', 'categoria', 'marca']),

    // --- SÍMBOLOS & CARTAS ---
    const EmojiItem(emoji: '🃏', name: 'Comodín / Carta', category: 'Símbolos & Cartas', keywords: ['carta', 'card', 'joker', 'baraja', 'mazo', 'tcg']),
    const EmojiItem(emoji: '🎲', name: 'Dado', category: 'Símbolos & Cartas', keywords: ['dado', 'dice', 'azar', 'suerte', 'tirada', 'juego de mesa']),
    const EmojiItem(emoji: '🎯', name: 'Diana / Blanco', category: 'Símbolos & Cartas', keywords: ['diana', 'objetivo', 'target', 'acierto', 'punteria']),
    const EmojiItem(emoji: '♟️', name: 'Peón de Ajedrez', category: 'Símbolos & Cartas', keywords: ['peon', 'ajedrez', 'estrategia', 'pieza', 'tablero']),
    const EmojiItem(emoji: '♠️', name: 'Picas', category: 'Símbolos & Cartas', keywords: ['picas', 'spades', 'poker', 'palo']),
    const EmojiItem(emoji: '♥️', name: 'Corazones', category: 'Símbolos & Cartas', keywords: ['corazones', 'hearts', 'vida', 'amor']),
    const EmojiItem(emoji: '♦️', name: 'Diamantes', category: 'Símbolos & Cartas', keywords: ['diamantes', 'diamonds', 'poker', 'brillo']),
    const EmojiItem(emoji: '♣️', name: 'Tréboles', category: 'Símbolos & Cartas', keywords: ['treboles', 'clubs', 'poker', 'suerte']),
    const EmojiItem(emoji: '🚫', name: 'Prohibido / ¡Neigh!', category: 'Símbolos & Cartas', keywords: ['neigh', 'relincho', 'cancelar', 'prohibido', 'stop', 'anular']),
    const EmojiItem(emoji: '🛑', name: 'Alto / Stop', category: 'Símbolos & Cartas', keywords: ['stop', 'alto', 'freno', 'detener', 'barrera']),
    const EmojiItem(emoji: '⚠️', name: 'Advertencia', category: 'Símbolos & Cartas', keywords: ['peligro', 'alerta', 'cuidado', 'riesgo']),
    const EmojiItem(emoji: '❓', name: 'Interrogación', category: 'Símbolos & Cartas', keywords: ['duda', 'misterio', 'pregunta', 'secreto']),
    const EmojiItem(emoji: '❗', name: 'Exclamación', category: 'Símbolos & Cartas', keywords: ['alerta', 'accion', 'sorpresa', 'inmediato']),
    const EmojiItem(emoji: '💠', name: 'Diamante Radiante', category: 'Símbolos & Cartas', keywords: ['rombo', 'mana', 'energia', 'celeste']),
    const EmojiItem(emoji: '🔴', name: 'Círculo Rojo', category: 'Símbolos & Cartas', keywords: ['rojo', 'red', 'fuego', 'vida']),
    const EmojiItem(emoji: '🔵', name: 'Círculo Azul', category: 'Símbolos & Cartas', keywords: ['azul', 'blue', 'agua', 'mana']),
    const EmojiItem(emoji: '🟢', name: 'Círculo Verde', category: 'Símbolos & Cartas', keywords: ['verde', 'green', 'tierra', 'naturaleza']),
    const EmojiItem(emoji: '🟣', name: 'Círculo Púrpura', category: 'Símbolos & Cartas', keywords: ['morado', 'purple', 'magia', 'caos']),
    const EmojiItem(emoji: '🟡', name: 'Círculo Amarillo', category: 'Símbolos & Cartas', keywords: ['amarillo', 'yellow', 'luz', 'oro']),
    const EmojiItem(emoji: '⚪', name: 'Círculo Blanco', category: 'Símbolos & Cartas', keywords: ['blanco', 'white', 'puro', 'sagrado']),
    const EmojiItem(emoji: '⚫', name: 'Círculo Negro', category: 'Símbolos & Cartas', keywords: ['negro', 'black', 'muerte', 'sombras']),
    const EmojiItem(emoji: '♾️', name: 'Infinito', category: 'Símbolos & Cartas', keywords: ['infinito', 'loop', 'combo', 'eterno']),
    const EmojiItem(emoji: '⚜️', name: 'Flor de Lis', category: 'Símbolos & Cartas', keywords: ['flor de lis', 'heraldica', 'noble', 'emblema']),
    const EmojiItem(emoji: '🌀', name: 'Vórtice', category: 'Símbolos & Cartas', keywords: ['vortice', 'portal', 'espiral', 'dimension']),

    // --- MONSTRUOS & HÉROES ---
    const EmojiItem(emoji: '😈', name: 'Demonio Pícaro', category: 'Monstruos & Héroes', keywords: ['demonio', 'diablo', 'maldad', 'picaro']),
    const EmojiItem(emoji: '👹', name: 'Ogro Japonés (Oni)', category: 'Monstruos & Héroes', keywords: ['oni', 'ogro', 'demonio', 'bestia']),
    const EmojiItem(emoji: '👺', name: 'Tengu / Goblin', category: 'Monstruos & Héroes', keywords: ['goblin', 'duende', 'tengu', 'nariz']),
    const EmojiItem(emoji: '👻', name: 'Fantasma', category: 'Monstruos & Héroes', keywords: ['fantasma', 'ghost', 'espectro', 'intangible']),
    const EmojiItem(emoji: '👽', name: 'Alien / Extraterrestre', category: 'Monstruos & Héroes', keywords: ['alien', 'extraterrestre', 'ovni', 'espacio']),
    const EmojiItem(emoji: '🤖', name: 'Robot / Gólem', category: 'Monstruos & Héroes', keywords: ['robot', 'golem', 'mecanico', 'androide', 'artefacto']),
    const EmojiItem(emoji: '👾', name: 'Monstruo Pixel', category: 'Monstruos & Héroes', keywords: ['invader', 'retro', 'pixel', 'arcade', 'gamer']),
    const EmojiItem(emoji: '🤡', name: 'Payaso Siniestro', category: 'Monstruos & Héroes', keywords: ['payaso', 'clown', 'caos', 'locura']),
    const EmojiItem(emoji: '🤠', name: 'Vaquero / Pistolero', category: 'Monstruos & Héroes', keywords: ['vaquero', 'cowboy', 'pistolero', 'forajido']),
    const EmojiItem(emoji: '🥷', name: 'Ninja', category: 'Monstruos & Héroes', keywords: ['ninja', 'sigilo', 'asesino', 'shuriken']),
    const EmojiItem(emoji: '🤴', name: 'Príncipe', category: 'Monstruos & Héroes', keywords: ['principe', 'noble', 'heredero', 'caballero']),
    const EmojiItem(emoji: '👸', name: 'Princesa', category: 'Monstruos & Héroes', keywords: ['princesa', 'noble', 'realeza']),
    const EmojiItem(emoji: '🦸', name: 'Superhéroe', category: 'Monstruos & Héroes', keywords: ['heroe', 'superheroe', 'capa', 'defensor']),
    const EmojiItem(emoji: '🦹', name: 'Supervillano', category: 'Monstruos & Héroes', keywords: ['villano', 'supervillano', 'malvado', 'nemesis']),
    const EmojiItem(emoji: '🎃', name: 'Calabaza Embrujada', category: 'Monstruos & Héroes', keywords: ['calabaza', 'halloween', 'miedo', 'fantasma']),
    const EmojiItem(emoji: '👁️', name: 'Ojo Omnipresente', category: 'Monstruos & Héroes', keywords: ['ojo', 'vision', 'vigilancia', 'mirada']),
    const EmojiItem(emoji: '🧠', name: 'Cerebro Psíquico', category: 'Monstruos & Héroes', keywords: ['cerebro', 'mente', 'psiquico', 'control', 'intelecto']),
    const EmojiItem(emoji: '🦾', name: 'Brazo Cibernético', category: 'Monstruos & Héroes', keywords: ['brazo', 'cibernetico', 'fuerza', 'mejora']),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialEmoji != null && widget.initialEmoji!.isNotEmpty) {
      _hoveredEmoji = widget.initialEmoji;
      final match = allEmojis.where((e) => e.emoji == widget.initialEmoji).firstOrNull;
      if (match != null) _hoveredName = match.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customInputController.dispose();
    super.dispose();
  }

  List<EmojiItem> get _filteredEmojis {
    final query = _searchController.text.trim().toLowerCase();
    return allEmojis.where((item) {
      final matchesCategory = _selectedCategory == 'Todos' || item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;
      if (item.emoji.contains(query)) return true;
      if (item.name.toLowerCase().contains(query)) return true;
      return item.keywords.any((k) => k.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmojis;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF141729),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sentiment_satisfied_alt, size: 18, color: GrimoireTheme.accentPurple),
              ),
              const SizedBox(width: 10),
              const Text(
                'Selector de Íconos y Emojis',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar emoji (ej. unicornio, espada, fuego, dado, zombi)...',
              prefixIcon: const Icon(Icons.search, size: 16, color: GrimoireTheme.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14, color: GrimoireTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF131526),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: GrimoireTheme.accentPurple),
              ),
            ),
            onChanged: (val) => setState(() {}),
          ),
        ),

        // Category Tabs
        SizedBox(
          height: 34,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _selectedCategory;
              return ChoiceChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                  ),
                ),
                selected: isSelected,
                selectedColor: GrimoireTheme.accentPurple,
                backgroundColor: const Color(0xFF131526),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Emojis Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        'No se encontraron emojis para "${_searchController.text}"',
                        style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Puedes escribir cualquier emoji o símbolo en la barra inferior.',
                        style: TextStyle(fontSize: 10, color: GrimoireTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 48,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isHovered = _hoveredEmoji == item.emoji;

                    return Tooltip(
                      message: '${item.name} (${item.category})',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () => widget.onEmojiSelected(item.emoji),
                        onHover: (hovering) {
                          if (hovering) {
                            setState(() {
                              _hoveredEmoji = item.emoji;
                              _hoveredName = item.name;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isHovered
                                ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                                : const Color(0xFF131524),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isHovered
                                  ? GrimoireTheme.accentPurple
                                  : GrimoireTheme.borderSubtle,
                              width: isHovered ? 1.5 : 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer / Custom Input & Preview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF141729),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              // Preview Box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _hoveredEmoji ?? '✨',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hoveredName ?? 'Pasa el cursor o selecciona',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'O escribe/pega cualquier símbolo libre:',
                      style: TextStyle(fontSize: 9, color: GrimoireTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Custom text input
              SizedBox(
                width: 70,
                height: 32,
                child: TextField(
                  controller: _customInputController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '🦄',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final text = _customInputController.text.trim();
                  if (text.isNotEmpty) {
                    widget.onEmojiSelected(text);
                  }
                },
                child: const Text('Usar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
