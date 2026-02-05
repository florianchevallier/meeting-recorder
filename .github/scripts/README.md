# 🤖 AI-Powered Release Notes Generator

Ce script génère automatiquement des release notes intelligentes à partir de vos conventional commits en utilisant Google Gemini.

## ✨ Fonctionnalités

- **Analyse automatique des commits** depuis la dernière version
- **Catégorisation intelligente** (feat, fix, perf, refactor, etc.)
- **Génération avec Gemini Flash** pour des notes de qualité professionnelle
- **Fallback automatique** vers un format basique si l'API n'est pas disponible
- **Support du français** avec ton professionnel mais accessible
- **Multi-provider** : Supporte OpenAI (GPT-4) et Google Gemini

## 🚀 Configuration

### 1. Obtenir une clé API Google Gemini

1. Va sur [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Connecte-toi avec ton compte Google
3. Clique **Create API Key**
4. Copie la clé (format: `AIza...`)

### 2. Ajouter la clé dans GitHub Secrets

1. Va sur ton repo GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Clique **New repository secret**
4. Nom : `GOOGLE_API_KEY`
5. Valeur : colle ta clé API
6. Clique **Add secret**

### 3. C'est tout ! 🎉

Le workflow GitHub Actions utilisera automatiquement cette clé pour générer les release notes lors de chaque release.

## 🧪 Test local

Pour tester le script localement :

```bash
# Installer les dépendances
pip install -r .github/scripts/requirements.txt

# Configurer ta clé API
export GOOGLE_API_KEY="AIza..."

# Générer les notes pour la prochaine version
.github/scripts/generate-release-notes.py v0.1.20
```

## 📝 Format des commits

Le script fonctionne mieux avec **Conventional Commits** :

```bash
feat: add automatic Teams meeting detection
fix: correct SHA256 mismatch in Homebrew formula
docs: update README with installation instructions
perf: optimize audio mixing performance
refactor: simplify permission management code
chore: update dependencies
```

## 🔧 Fonctionnement

1. **Récupère les commits** depuis le dernier tag Git
2. **Catégorise** les commits selon le préfixe (feat, fix, etc.)
3. **Envoie à Gemini** avec un prompt optimisé pour générer des notes claires
4. **Structure la sortie** avec sections utilisateur-friendly
5. **Fallback** vers un format basique si l'API échoue

## 💡 Exemple de sortie

```markdown
# Meety v0.1.20

## 🎯 Résumé
Cette version améliore la fiabilité des mises à jour Homebrew et
corrige un problème critique de vérification SHA256.

## ✨ Nouveautés
- Détection automatique des réunions Teams avec démarrage automatique
- Récupération automatique après mise en veille (macOS 15+)

## 🐛 Corrections
- Correction du mismatch SHA256 dans la formule Homebrew
- Amélioration de la stabilité lors des changements d'affichage

## 🔧 Améliorations techniques
- Ajout d'un système de retry avec backoff exponentiel
- Validation de la taille des fichiers téléchargés
- Délai de propagation CDN de 10 secondes

## 📦 Installation
[...]
```

## 🎯 Choix du provider AI

Le script essaie automatiquement dans cet ordre :
1. **OpenAI (GPT-4)** si `OPENAI_API_KEY` est définie
2. **Google Gemini** si `GOOGLE_API_KEY` est définie
3. **Format basique** si aucune clé n'est trouvée

Pour utiliser OpenAI plutôt que Gemini, définis `OPENAI_API_KEY` au lieu de `GOOGLE_API_KEY`.

## 🛡️ Sécurité

- La clé API est stockée de manière sécurisée dans GitHub Secrets
- Elle n'est jamais exposée dans les logs ou le code
- Seul le contenu des commits (déjà public) est envoyé à l'API
- Fallback automatique si l'API n'est pas disponible

## 💰 Coûts

Le script utilise **Gemini 2.0 Flash** (le plus rapide et économique) avec un maximum de 2000 tokens par génération.

**Estimation avec Gemini Flash** :
- Prix : Gratuit jusqu'à 1,500 requêtes/jour
- Au-delà : $0.00001875 par 1000 caractères (~0.000002$ par release)

Pour 100 releases/an : **GRATUIT** 🎉

**Si tu utilises OpenAI GPT-4** :
- Prix : ~$0.003 par release
- Pour 100 releases/an : ~$0.30/an

## 🔧 Personnalisation

Tu peux modifier le prompt dans `generate-release-notes.py` ligne 90 pour :
- Changer le ton (plus technique, plus marketing, etc.)
- Ajouter des sections personnalisées
- Modifier la structure
- Changer la langue

Tu peux aussi changer le modèle Gemini utilisé ligne 168 :
```python
model = genai.GenerativeModel('gemini-2.0-flash-exp')  # Plus rapide
# ou
model = genai.GenerativeModel('gemini-1.5-pro')  # Plus précis
```

## 📚 Plus d'infos

- [Google AI Studio](https://aistudio.google.com/)
- [Documentation Gemini API](https://ai.google.dev/docs)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## 🤝 Support multi-provider

Le script supporte automatiquement :
- ✅ **Google Gemini** (recommandé - rapide et gratuit)
- ✅ **OpenAI GPT-4** (fallback si Gemini non disponible)
- ✅ **Format basique** (si aucune API disponible)

Définis simplement la clé API correspondante et le script s'adapte automatiquement !
