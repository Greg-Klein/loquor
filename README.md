# Loquor

Loquor est une app macOS de dictée locale avec push-to-talk, transcription Parakeet en local, choix du micro et insertion automatique dans le champ actif.

## Download

Télécharger la dernière version depuis les releases :

- 📦 [Latest release](https://github.com/Greg-Klein/loquor/releases/latest)

## 🚀 Installer l'app macOS

1. Télécharger `Loquor-macOS.zip` depuis la dernière release.
2. Décompresser l’archive.
3. Déplacer `Loquor.app` dans `/Applications`.
4. Lancer `Loquor`.

Si macOS indique que l’app est modifiée ou endommagée, lancer :

```bash
xattr -dr com.apple.quarantine /Applications/Loquor.app
```

Puis relancer `Loquor`.

## 🔐 Permissions macOS

Loquor peut demander :

- 🎙️ `Microphone`, pour capturer ta voix
- ⌨️ `Accessibility`, pour insérer le texte généré dans le champ actuellement focalisé

## ✨ Notes d’usage

- 🖥️ Loquor tourne localement sur macOS.
- 📍 L’app vit dans la barre de menu.
- 📋 Si aucun champ texte n’a le focus, le texte reste disponible via le presse-papiers.

## 🛠️ Développement

Le projet comprend :

- un mode CLI pour tester la transcription localement
- un backend Python local pour Parakeet
- une app macOS native en SwiftUI/AppKit
- un push-to-talk configurable
- la sélection du micro
- la copie dans le presse-papiers puis l’insertion dans le champ actif

## Stack technique

Sur Mac Apple Silicon (`arm64`), la pile la plus simple pour une transcription locale avec Parakeet est :

- micro : `sounddevice`
- transcription locale : `parakeet-mlx`
- modèle : `mlx-community/parakeet-tdt-0.6b-v3`

Notes :

- `nvidia/parakeet-tdt-0.6b-v2` est surtout orienté anglais.
- `nvidia/parakeet-tdt-0.6b-v3` supporte 25 langues européennes, dont le français.
- La documentation NVIDIA indique que l'intégration officielle NeMo est surtout prévue pour Linux et GPU NVIDIA.
- Sur Mac Apple Silicon, l'option pratique est d'utiliser une conversion MLX du modèle Parakeet.

## Architecture

Le projet est structuré en deux couches :

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

## Fonctionnement de l'app macOS native

L'app native :

1. écoute une touche push-to-talk globale
2. enregistre tant que la touche reste appuyée
3. transcrit localement avec Parakeet
4. place le texte dans le presse-papiers
5. tente ensuite de coller le texte dans l'app qui a le focus
6. permet de quitter directement depuis son menu de barre de menu

## Environnement Python

Tu peux utiliser `venv` ou `uv`. Exemple avec `venv` :

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e .
```

Si `sounddevice` pose problème sur ta machine, vérifie aussi que Python a bien l'autorisation d'accéder au micro dans les réglages macOS.

L'app native utilise également ce backend Python local :

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

Le code Swift natif se trouve dans :

```bash
NativeMacApp/
```

Avant le premier build Swift, il faut accepter la licence Xcode :

```bash
sudo xcodebuild -license
```

Le package peut ensuite être ouvert dans Xcode ou lancé depuis le terminal.

Ouvrir dans Xcode :

```bash
open NativeMacApp/Package.swift
```

Le backend Python utilisé par l'app native est lancé via :

```bash
python -m speech_to_text.backend_service
```

## App Python de barre de menu

L’ancienne app Python existe encore comme implémentation alternative, mais l’app Swift native est la voie recommandée.

Lancer l’app Python de barre de menu :

```bash
speech-to-text-app
```

Fonctionnalités exposées dans cette version :

- l'icône `Loquor` apparaît dans la barre de menu
- `Change push-to-talk key...` permet de choisir la touche
- `Input microphone` permet de choisir le micro
- `Auto-paste into active field` active ou désactive le collage automatique

Permissions macOS nécessaires :

- `Réglages système -> Confidentialité et sécurité -> Microphone`
- `Réglages système -> Confidentialité et sécurité -> Accessibilité`
- `Réglages système -> Confidentialité et sécurité -> Surveillance de l'entrée`

Sans `Accessibilité` et `Surveillance de l'entrée`, l'app ne peut pas écouter la touche globale ni insérer le texte dans le champ actif.

Note sur l'indicateur micro macOS :

- le point orange de micro sur l'écran principal est un indicateur système de confidentialité
- l'app ne doit pas chercher à le masquer
- Apple permet seulement un masquage limité sur des écrans externes dans certains cas système

## Packaging macOS

Le repo contient un script pour produire un bundle `.app` :

```bash
./scripts/build_native_app.sh
```

Le bundle est généré ici :

```bash
dist/Loquor.app
```

Pour l’installer dans `/Applications` :

```bash
./scripts/install_native_app.sh
```

Le bundle embarque :

- l’app Swift native
- le backend Python
- le modèle et ses dépendances

## Limites connues

- le collage automatique repose sur une simulation de `Cmd+V`
- si aucun champ texte n'a le focus, le texte reste simplement dans le presse-papiers
- l’app Swift native repose encore sur un backend Python local
- la licence Xcode doit être acceptée avant le premier build Swift

## Orientation technique

Pour une app locale sur Mac, cette architecture MLX est la plus simple à exploiter.

Pour un produit plus portable, multi-OS, ou orienté infrastructure GPU, l’évolution naturelle est plutôt :

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
