# Loquor

Loquor est une app macOS de dictee locale avec push-to-talk, transcription Parakeet en local, choix du micro et insertion automatique dans le champ actif. Elle est pensee pour etre installee comme une vraie application et lancee depuis `/Applications`.

## Download

Telecharger la derniere version depuis les releases :

- [Latest release](https://github.com/Greg-Klein/loquor/releases/latest)

## Installer l'app macOS

1. Telecharger l'archive ou le DMG depuis la derniere release.
2. Ouvrir l'archive ou monter le DMG.
3. Deplacer `Loquor.app` dans `/Applications`.
4. Lancer `Loquor`.

Si macOS indique que l'app est modifiee ou endommagee, lancer :

```bash
xattr -dr com.apple.quarantine /Applications/Loquor.app
```

Puis relancer `Loquor`.

## Permissions macOS

Loquor peut demander :

- `Microphone`, pour capturer ta voix
- `Accessibility`, pour inserer le texte genere dans le champ actuellement focalise
- `Input Monitoring`, pour ecouter le push-to-talk global selon la configuration

## Notes d'usage

- Loquor tourne localement sur macOS.
- L'app vit dans la barre de menu.
- Si aucun champ texte n'a le focus, le texte reste disponible via le presse-papiers.
- Le modele Parakeet n'est pas embarque dans le bundle aujourd'hui.
- Il peut etre telecharge au premier lancement, avec un etat de prechargement visible dans l'UI.

## Stack technique

Sur Mac Apple Silicon (`arm64`), la pile la plus simple pour une transcription locale avec Parakeet est :

- micro : `sounddevice`
- transcription locale : `parakeet-mlx`
- modele : `mlx-community/parakeet-tdt-0.6b-v3`

Notes :

- `nvidia/parakeet-tdt-0.6b-v2` est surtout oriente anglais.
- `nvidia/parakeet-tdt-0.6b-v3` supporte 25 langues europeennes, dont le francais.
- La documentation NVIDIA indique que l'integration officielle NeMo est surtout prevue pour Linux et GPU NVIDIA.
- Sur Mac Apple Silicon, l'option pratique est d'utiliser une conversion MLX du modele Parakeet.

## Architecture

Le projet est structure en deux couches :

1. backend Python local
   - charge Parakeet via `parakeet-mlx`
   - gere la capture audio et la transcription
   - expose un petit protocole JSON local sur `stdin/stdout`
2. app macOS native
   - interface utilisateur SwiftUI
   - barre de menu
   - choix de la touche push-to-talk
   - choix du micro
   - presse-papiers et auto-collage

## Fonctionnement de l'app macOS native

L'app native :

1. ecoute une touche push-to-talk globale
2. enregistre tant que la touche reste appuyee
3. transcrit localement avec Parakeet
4. place le texte dans le presse-papiers
5. tente ensuite de coller le texte dans l'app qui a le focus
6. permet de quitter directement depuis son menu de barre de menu

## Build

Tu peux utiliser `venv` ou `uv`. Exemple avec `venv` :

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e ".[build]"
```

Si `sounddevice` pose probleme sur ta machine, verifie aussi que Python a bien l'autorisation d'acceder au micro dans les reglages macOS.

Pour produire un bundle autonome partageable, le build natif a besoin de `PyInstaller` dans la venv. L'extra `build` l'installe automatiquement.

## App macOS native

Le code Swift natif se trouve dans :

```bash
NativeMacApp/
```

Avant le premier build Swift, il faut accepter la licence Xcode :

```bash
sudo xcodebuild -license
```

Ouvrir dans Xcode :

```bash
open NativeMacApp/Package.swift
```

En developpement local uniquement, l'app peut encore utiliser le backend Python du repo :

```bash
/Users/gregoryklein/workspace/speech-to-text/.venv/bin/python
```

Dans le bundle final, l'app lance un executable backend autonome embarque.

En fallback de developpement, elle lance :

```bash
python -m speech_to_text.backend_service
```

## Packaging macOS

Le repo contient un script pour produire un vrai bundle `.app` :

```bash
./scripts/build_native_app.sh
```

Le bundle est genere ici :

```bash
dist/Loquor.app
```

Un DMG installable peut aussi etre genere avec :

```bash
./scripts/build_dmg.sh
```

Le DMG est genere ici :

```bash
dist/Loquor.dmg
```

Pour l'installer dans `/Applications` :

```bash
./scripts/install_native_app.sh
```

Le bundle embarque :

- l'app Swift native
- un backend Python autonome construit avec `PyInstaller`
- les dependances du backend

## Limites connues

- le collage automatique repose sur une simulation de `Cmd+V`
- si aucun champ texte n'a le focus, le texte reste simplement dans le presse-papiers
- le build natif depend de `PyInstaller` dans la venv de build
- la licence Xcode doit etre acceptee avant le premier build Swift

## Sources

- NVIDIA Parakeet v3 : https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- NVIDIA Parakeet v2 : https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2
- NeMo documentation : https://docs.nvidia.com/nemo-framework/
- MLX Parakeet v3 : https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3
- parakeet-mlx : https://github.com/senstella/parakeet-mlx
