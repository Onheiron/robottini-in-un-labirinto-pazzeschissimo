# Struttura del Codice

## Organizzazione File

```
scripts/
├── maze_generator.gd    # Script principale - coordina tutto
├── maze_builder.gd      # Algoritmo di Eller
└── minimap.gd           # Gestione minimappa
```

## maze_generator.gd
**Responsabilità**: Coordinatore principale
- Gestisce input giocatore
- Mantiene stato corrente (posizione nelle celle padre/figlio)
- Coordina generazione labirinti
- Rendering scena e minimappa

## maze_builder.gd
**Responsabilità**: Generazione labirinti
- `generate_maze_connections()`: Crea connessioni 10x10 usando Eller
- `generate_cell_maze()`: Genera griglia 32x32 per una scena
- Classe statica senza stato

## minimap.gd
**Responsabilità**: Minimappa
- Traccia celle visitate
- Renderizza minimappa 100x100 (10x10 padre × 10x10 figlio)
- Evidenzia posizione corrente
