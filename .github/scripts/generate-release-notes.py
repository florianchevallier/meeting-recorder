#!/usr/bin/env python3
"""
Generate AI-powered release notes from conventional commits
Supports: OpenAI (GPT-4) and Google Gemini
"""

import os
import sys
import json
import subprocess
from typing import List, Dict

def get_commits_since_last_tag() -> List[Dict[str, str]]:
    """Get all commits since the last tag"""
    try:
        result = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0", "HEAD^"],
            capture_output=True,
            text=True,
            check=True
        )
        prev_tag = result.stdout.strip()
        print(f"📊 Analyzing commits since {prev_tag}...", file=sys.stderr)
    except subprocess.CalledProcessError:
        prev_tag = ""
        print("📊 No previous tag found, analyzing all commits...", file=sys.stderr)

    git_range = f"{prev_tag}..HEAD" if prev_tag else "HEAD"
    result = subprocess.run(
        ["git", "log", git_range, "--pretty=format:%H|%s|%b|%an", "--no-merges"],
        capture_output=True,
        text=True,
        check=True
    )

    commits = []
    for line in result.stdout.strip().split('\n'):
        if not line:
            continue
        parts = line.split('|', 3)
        if len(parts) >= 2:
            commits.append({
                'hash': parts[0][:7],
                'subject': parts[1],
                'body': parts[2] if len(parts) > 2 else '',
                'author': parts[3] if len(parts) > 3 else ''
            })

    return commits

def categorize_commits(commits: List[Dict[str, str]]) -> Dict[str, List[Dict[str, str]]]:
    """Categorize commits by conventional commit type"""
    categories = {
        'feat': [],
        'fix': [],
        'docs': [],
        'style': [],
        'refactor': [],
        'perf': [],
        'test': [],
        'chore': [],
        'ci': [],
        'other': []
    }

    for commit in commits:
        subject = commit['subject']
        found = False
        for category in categories.keys():
            if subject.startswith(f"{category}:") or subject.startswith(f"{category}("):
                categories[category].append(commit)
                found = True
                break
        if not found:
            categories['other'].append(commit)

    return categories

def create_prompt(version: str, categories: Dict[str, List[Dict[str, str]]]) -> str:
    """Create the prompt for AI generation"""
    commit_summary = []
    for category, commits_list in categories.items():
        if commits_list and category != 'other':
            commit_summary.append(f"\n### {category.upper()}:")
            for commit in commits_list:
                commit_summary.append(f"- {commit['subject']}")
                if commit['body']:
                    commit_summary.append(f"  Details: {commit['body'][:100]}")

    return f"""Tu es un expert en communication technique. Génère des release notes professionnelles mais accessibles pour Meety v{version}, une application macOS d'enregistrement de réunions.

Commits depuis la dernière version:
{''.join(commit_summary)}

Instructions:
1. Écris en français, ton professionnel mais accessible
2. Structure en sections: "Nouveautés", "Corrections", "Améliorations techniques"
3. Explique les bénéfices utilisateur, pas juste les changements techniques
4. Sois concis mais informatif
5. Utilise des emojis avec parcimonie (1-2 par section)
6. Ignore les commits chore/ci sauf s'ils sont significatifs pour l'utilisateur

Format attendu:
# Meety v{version}

## 🎯 Résumé
[1-2 phrases sur ce que cette version apporte]

## ✨ Nouveautés
[Liste des nouvelles fonctionnalités avec bénéfices utilisateur]

## 🐛 Corrections
[Liste des bugs corrigés]

## 🔧 Améliorations techniques
[Améliorations de performance, stabilité, etc.]

## 📦 Installation
- Via Homebrew: `brew upgrade --cask meety`
- Téléchargement direct: [lien vers la release]

Génère uniquement le contenu markdown, sans préambule ni conclusion."""

def generate_with_openai(prompt: str) -> str:
    """Generate release notes using OpenAI API"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise ValueError("OPENAI_API_KEY not found")

    try:
        from openai import OpenAI

        client = OpenAI(api_key=api_key)

        print("🤖 Generating release notes with OpenAI GPT-4...", file=sys.stderr)

        response = client.chat.completions.create(
            model="gpt-4o",  # or gpt-4-turbo
            messages=[{
                "role": "system",
                "content": "Tu es un expert en rédaction de release notes techniques."
            }, {
                "role": "user",
                "content": prompt
            }],
            max_tokens=2000,
            temperature=0.7
        )

        return response.choices[0].message.content

    except ImportError:
        raise ImportError("openai package not found. Install with: pip install openai")

def generate_with_gemini(prompt: str) -> str:
    """Generate release notes using Google Gemini API"""
    api_key = os.environ.get('GOOGLE_API_KEY')
    if not api_key:
        raise ValueError("GOOGLE_API_KEY not found")

    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)

        print("🤖 Generating release notes with Google Gemini...", file=sys.stderr)

        model = genai.GenerativeModel('gemini-2.0-flash-exp')
        response = model.generate_content(prompt)

        return response.text

    except ImportError:
        raise ImportError("google-generativeai package not found. Install with: pip install google-generativeai")

def generate_with_ai(version: str, categories: Dict[str, List[Dict[str, str]]]) -> str:
    """Generate release notes using available AI provider"""

    prompt = create_prompt(version, categories)

    # Try OpenAI first
    if os.environ.get('OPENAI_API_KEY'):
        try:
            content = generate_with_openai(prompt)
        except Exception as e:
            print(f"⚠️  OpenAI error: {e}", file=sys.stderr)
            content = None
    # Try Gemini second
    elif os.environ.get('GOOGLE_API_KEY'):
        try:
            content = generate_with_gemini(prompt)
        except Exception as e:
            print(f"⚠️  Gemini error: {e}", file=sys.stderr)
            content = None
    else:
        print("⚠️  No API key found (OPENAI_API_KEY or GOOGLE_API_KEY)", file=sys.stderr)
        content = None

    if not content:
        print("⚠️  Falling back to basic format", file=sys.stderr)
        return generate_basic_notes(version, categories)

    # Add security and installation info
    content += f"""

## 🔒 Sécurité
- ✅ Signé avec Developer ID Application
- ✅ Notarisé par Apple - aucun avertissement de sécurité
- ✅ Code source ouvert sur GitHub
- ✅ Données 100% locales sur votre Mac

## 📋 Configuration requise
- macOS 14.0 ou supérieur
- Permissions : microphone, enregistrement d'écran, documents, accessibilité

## 🔗 Liens utiles
- [Code source](https://github.com/florianchevallier/meeting-recorder)
- [Documentation](https://github.com/florianchevallier/meeting-recorder#readme)
- [Signaler un bug](https://github.com/florianchevallier/meeting-recorder/issues)
"""

    return content

def generate_basic_notes(version: str, categories: Dict[str, List[Dict[str, str]]]) -> str:
    """Generate basic release notes without AI"""

    notes = [f"# Meety v{version}\n"]

    # Features
    if categories['feat']:
        notes.append("\n## ✨ Nouvelles fonctionnalités\n")
        for commit in categories['feat']:
            subject = commit['subject'].replace('feat:', '').replace('feat(', '(').strip()
            notes.append(f"- {subject}")

    # Fixes
    if categories['fix']:
        notes.append("\n## 🐛 Corrections\n")
        for commit in categories['fix']:
            subject = commit['subject'].replace('fix:', '').replace('fix(', '(').strip()
            notes.append(f"- {subject}")

    # Performance
    if categories['perf']:
        notes.append("\n## ⚡ Performance\n")
        for commit in categories['perf']:
            subject = commit['subject'].replace('perf:', '').replace('perf(', '(').strip()
            notes.append(f"- {subject}")

    # Refactoring
    if categories['refactor']:
        notes.append("\n## 🔧 Améliorations techniques\n")
        for commit in categories['refactor']:
            subject = commit['subject'].replace('refactor:', '').replace('refactor(', '(').strip()
            notes.append(f"- {subject}")

    # Documentation
    if categories['docs']:
        notes.append("\n## 📚 Documentation\n")
        for commit in categories['docs']:
            subject = commit['subject'].replace('docs:', '').replace('docs(', '(').strip()
            notes.append(f"- {subject}")

    notes.append(f"""
## 📦 Installation

### Via Homebrew (recommandé)
```bash
brew upgrade --cask meety
```

### Téléchargement direct
Téléchargez le DMG ci-dessous et glissez Meety.app dans votre dossier Applications.

## 🔒 Sécurité
- ✅ Signé avec Developer ID Application
- ✅ Notarisé par Apple
- ✅ Code source disponible sur GitHub
- ✅ Données 100% locales sur votre Mac

## 📋 Configuration requise
- macOS 14.0 ou supérieur
- Permissions : microphone, enregistrement d'écran, documents, accessibilité
""")

    return '\n'.join(notes)

def main():
    if len(sys.argv) < 2:
        print("Usage: generate-release-notes.py <version>", file=sys.stderr)
        sys.exit(1)

    version = sys.argv[1].lstrip('v')

    print(f"🚀 Generating release notes for v{version}...", file=sys.stderr)

    commits = get_commits_since_last_tag()
    print(f"📝 Found {len(commits)} commits", file=sys.stderr)

    if not commits:
        print("⚠️  No commits found since last tag", file=sys.stderr)
        sys.exit(1)

    categories = categorize_commits(commits)
    release_notes = generate_with_ai(version, categories)

    print(release_notes)
    print("\n✅ Release notes generated successfully!", file=sys.stderr)

if __name__ == "__main__":
    main()
