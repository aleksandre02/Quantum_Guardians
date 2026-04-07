# Education Realm — Card-Based Tactical RPG

A turn-based card game built in **Godot 4.2** (GDScript). The theme is education and social equity. The player fights an enemy representing systemic barriers by strategically playing cards each turn to weaken it across three dimensions: **Access**, **Quality**, and **Equity**.

The core mechanic is directly inspired by **quantum mechanics** — superposition, wave function collapse, and decoherence are not just cosmetic labels; they drive the actual gameplay logic.

---

## How to Run

https://aleksandretit.itch.io/quantum-guardians
you can play demo on this website (sounds are loud, and there is currently no setting for lowering it)
otherwise you would have to download the godot engine plus clone this repo
---

## How to Play

- You hold **4 cards** at a time, each typed as Access, Quality, or Equity.
- **Click a card** to play it — this widens the superposition range for that stat.
- Press **End Turn** to collapse all ranges to their final values (wave function collapse).
- Win by getting all three stats to **100** after an End Turn.
- Lose if **pressure reaches 100** or **decoherence triggers 5 times**.

---

## Core Mechanics

### Superposition
Each stat (Access, Quality, Equity) exists as a range of possible values rather than a single number. Playing a card widens the range asymmetrically — the upper bound grows faster than the lower, so better outcomes become more likely but are never guaranteed. Three layered bars visualise this:

- **Coloured bar** — last confirmed (observed) value
- **White bar** — upper bound of the possible range
- **Dark bar** — lower bound of the possible range

### Wave Function Collapse
Pressing **End Turn** collapses each stat to a random value drawn uniformly from its current range. The player cannot know where the value will land — only that playing more cards shifts the range upward.

### Decoherence
Each card played doubles the probability of a decoherence event. When it triggers:

- A random stat's range collapses back to its last confirmed value (erasing this turn's progress on that stat).
- The screen shakes, the enemy attacks, and the player takes a hit.
- The decoherence bar resets.
- After **5 decoherence events**, the game is lost.

The probability formula is `numerator / 526`, where numerator starts at 1 and doubles with each safe card. This creates a risk/reward dilemma: more cards = better range, but higher chance of losing it all.

### Pressure
A pressure bar increases by a rising amount each End Turn, following the schedule `[5, 8, 12, 17, 23, 30, 38, 47]`. Reaching 100 is a loss. A ghost bar always previews the next turn's cost.

### Diminishing Returns
Playing the same card type repeatedly in one turn gives less range expansion: 100% → 80% → 60% → 20% minimum. This encourages spreading cards across all three stats.

---

## Project Structure

```
project.godot
assets/
  cards/          — Card textures (access_3.png, quality_3.png, equity_3.png)
  sfx/            — All sound effects and background music
scenes/           — Godot scene files (.tscn)
scripts/
  game.gd         — Master game controller (combat loop, turn logic, win/lose)
  card.gd         — Individual card: hover animation, click signal, audio
  card_manager.gd — Hand management: deal, play, reshuffle animations
  weakness_meter.gd — Three-bar superposition UI and collapse logic
  healthbar.gd    — Pressure bar with ghost preview
  player.gd       — Player character movement and animation
  enemy.gd        — Enemy character movement and animation
CHANGES.txt       — Full development log and submission description
```

---

## Audio

| Sound | Trigger |
|---|---|
| Background music | Loops from game start |
| Card hover | Mouse enters a card |
| Card click | Card is clicked |
| Card shuffle | Initial deal, end-turn reshuffle, game-end collection |
| Attack | Player plays a card (normal turn) |
| Hit | Enemy is hit; player is hit during decoherence |
| Decoherence | Decoherence event triggers |
| Victory | Player wins |
| Game Over | Player loses |

---

## Win / Lose Conditions

| Result | Condition |
|---|---|
| **Win** | All three stats reach 100 after an End Turn collapse |
| **Lose** | Pressure reaches 100, or decoherence triggers 5 times |

---

## Engine & Language

- **Engine:** Godot 4.2
- **Language:** GDScript
- All audio players and runtime bars are created in code (not the scene editor) to keep `.tscn` files clean.
