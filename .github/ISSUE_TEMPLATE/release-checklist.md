---
name: Release Checklist
about: Checklist pour préparer une nouvelle release
title: 'Release v[VERSION] Checklist'
labels: 'release'
assignees: ''
---

# 📋 Release Checklist v[VERSION]

## Pre-Release Testing
- [ ] Tests unitaires passent en local (`swift test`)
- [ ] Build release fonctionne (`swift build -c release`)
- [ ] App fonctionne sur macOS 13.0+
- [ ] Permissions microphone/screen recording demandées correctement
- [ ] Enregistrement audio système + microphone opérationnel
- [ ] Interface status bar responsive et stable
- [ ] Pas de memory leaks détectés
- [ ] Performance acceptable sur machines anciennes

## Code Quality
- [ ] Code review terminé et approuvé
- [ ] Documentation mise à jour (CLAUDE.md, README.md)
- [ ] Changelog rédigé avec nouveautés et corrections
- [ ] Version bump dans Package.swift si nécessaire
- [ ] Pas de TODO/FIXME critiques restants

## Release Preparation
- [ ] Branch `release/v[VERSION]` créée depuis `main`
- [ ] Tag git créé : `git tag v[VERSION]`
- [ ] CHANGELOG.md mis à jour avec la nouvelle version
- [ ] Version dans Info.plist cohérente

## CI/CD Validation
- [ ] Pipeline CI passe sur `release/v[VERSION]`
- [ ] Build artifacts générés correctement
- [ ] DMG créé et testé sur machine propre

## Security & Compliance
- [ ] Scan sécurité passé (pas de vulnérabilités critiques)
- [ ] Permissions macOS configurées correctement
- [ ] App bundle structure validée

## Distribution
- [ ] GitHub Release créée avec assets
- [ ] Release notes rédigées et claires
- [ ] DMG téléchargeable et installable
- [ ] Vérification installation sur macOS propre

## Post-Release
- [ ] Release annoncée (si applicable)
- [ ] Monitoring des crash reports
- [ ] Issues utilisateurs surveillées
- [ ] Metrics d'adoption trackées
- [ ] Feedback collecté pour prochaine version

## Rollback Plan
En cas de problème critique :
- [ ] Plan de rollback documenté
- [ ] Version précédente accessible
- [ ] Process de hotfix défini

---

**Notes additionnelles:**
- Tester sur plusieurs versions macOS (13.0, 14.0, 15.0+)
- Vérifier compatibilité avec différentes configurations Teams
- S'assurer que l'auto-détection calendrier fonctionne
- Performance avec enregistrements longs (1h+)