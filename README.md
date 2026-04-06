# Speech-to-text local avec Parakeet

Cette base propose maintenant :

- un mode CLI simple pour tester la transcription
- un backend Python local pour Parakeet
- une app macOS native en SwiftUI/AppKit
- un push-to-talk configurable
- la sélection du micro
- la copie dans le presse-papiers puis le collage dans le champ actif

## Pourquoi cette base

Sur ton poste actuel, tu es sur un Mac Apple Silicon (`arm64`). La voie la plus simple pour démarrer en local est donc :

- micro : `sounddevice`
- transcription locale : `parakeet-mlx`
- modèle : `mlx-community/parakeet-tdt-0.6b-v3`

Important :

- `nvidia/parakeet-tdt-0.6b-v2` est surtout orienté anglais.
- `nvidia/parakeet-tdt-0.6b-v3` supporte 25 langues européennes, dont le français.
- La documentation NVIDIA indique que l'intégration officielle NeMo est surtout prévue pour Linux et GPU NVIDIA.
- Sur Mac Apple Silicon, l'option pratique est d'utiliser une conversion MLX du modèle Parakeet.

## Architecture recommandée

Le projet est maintenant séparé en deux couches :

1. backend Python local
   - charge Parakeet via `parakeet-mlx`
   - gère la capture audio et la transcription
   - expose un petit protocole JSON local sur `stdin/stdout`
2. app macOS native
   - interface utilisateur SwiftUI
   - barre de menu
   - choix de la touche push-to-talk
   - choix du micro
   - presse-papiers et auto-collage

## Ce que fait l'app macOS native

L'app native :

1. écoute une touche push-to-talk globale
2. enregistre tant que la touche reste appuyée
3. transcrit localement avec Parakeet
4. place le texte dans le presse-papiers
5. tente ensuite de coller le texte dans l'app qui a le focus
6. permet de quitter directement depuis son menu de barre de menu

## Installation

Tu peux utiliser `venv` ou `uv`. Exemple avec `venv` :

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e .
```

Si `sounddevice` pose problème sur ta machine, vérifie aussi que Python a bien l'autorisation d'accéder au micro dans les réglages macOS.

Pour l'app native, le backend Python reste nécessaire :

```bash
pip install -e .
```

## Mode CLI

Lister les périphériques audio :

```bash
speech-to-text --list-devices
```

Enregistrer 5 secondes puis transcrire :

```bash
speech-to-text --duration 5
```

Garder le WAV enregistré :

```bash
speech-to-text --duration 5 --keep-audio
```

Choisir explicitement un périphérique :

```bash
speech-to-text --device 1 --duration 5
```

## App macOS native

Le code Swift natif se trouve ici :

```bash
NativeMacApp/
```

Avant le premier build Swift sur cette machine, il faut accepter la licence Xcode :

```bash
sudo xcodebuild -license
```

Ensuite, tu peux ouvrir le package dans Xcode ou tenter un lancement depuis le terminal.

Ouvrir dans Xcode :

```bash
open NativeMacApp/Package.swift
```

Le backend Python attendu par l'app native est :

```bash
/Users/gregoryklein/workspace/speech-to-text/.venv/bin/python
```

L'app native lance ensuite :

```bash
python -m speech_to_text.backend_service
```

## App Python de barre de menu

L’ancienne app Python existe encore comme base de secours, mais la voie recommandée est maintenant l’app Swift native.

Lancer l’app Python de barre de menu :

```bash
speech-to-text-app
```

Une fois lancée :

- l'icône `Loquor` apparaît dans la barre de menu
- `Change push-to-talk key...` permet de choisir la touche
- `Input microphone` permet de choisir le micro
- `Auto-paste into active field` active ou désactive le collage automatique

Permissions macOS nécessaires :

- `Réglages système -> Confidentialité et sécurité -> Microphone`
- `Réglages système -> Confidentialité et sécurité -> Accessibilité`
- `Réglages système -> Confidentialité et sécurité -> Surveillance de l'entrée`

Sans `Accessibilité` et `Surveillance de l'entrée`, l'app ne peut pas écouter la touche globale ni coller dans le champ actif.

Note sur l'indicateur micro macOS :

- le point orange de micro sur l'écran principal est un indicateur système de confidentialité
- l'app ne doit pas chercher à le masquer
- Apple permet seulement un masquage limité sur des écrans externes dans certains cas système

## Packaging natif

Le repo contient maintenant un script pour produire un vrai bundle `.app` :

```bash
./scripts/build_native_app.sh
```

Le bundle est généré ici :

```bash
dist/Loquor.app
```

Pour l’installer dans `~/Applications` :

```bash
./scripts/install_native_app.sh
```

Le bundle embarque :

- l’app Swift native
- le backend Python
- le modèle et ses dépendances

## Limites actuelles

- le collage automatique repose sur une simulation de `Cmd+V`
- si aucun champ texte n'a le focus, le texte reste simplement dans le presse-papiers
- l’app Swift native dépend encore du backend Python du repo
- la licence Xcode doit être acceptée avant le premier build Swift

## Recommandation concrète

Si ton objectif est une app perso sur Mac, commence avec cette base MLX.

Si ton objectif est un produit plus portable multi-OS ou une infra GPU, alors la prochaine étape sera plutôt :

- backend Python avec NeMo
- Linux
- GPU NVIDIA
- Parakeet officiel via `nemo_toolkit["asr"]`

## Sources

- NVIDIA Parakeet v3 : https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- NVIDIA Parakeet v2 : https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2
- NeMo documentation : https://docs.nvidia.com/nemo-framework/
- MLX Parakeet v3 : https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3
- parakeet-mlx : https://github.com/senstella/parakeet-mlx
