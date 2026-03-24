# Carta

App macOS minimale in SwiftUI: una sola finestra ridimensionabile con editor note essenziale.

## Comportamento

- La finestra resta sempre sopra alle altre applicazioni usando il livello `floating`.
- Il contenuto e' persistente: il rich text viene salvato automaticamente.
- La finestra e' trascinabile, ridimensionabile e mantiene uno stile molto essenziale.
- Formattazione via scorciatoie: `cmd+b`, `cmd+i`, `cmd+u`.
- Zoom testo via scorciatoie: `cmd+` e `cmd-`.
- Dalla menu bar si possono aprire impostazioni e scegliere il font tra sistema e una lista ridotta di font web safe.

## Avvio

```bash
swift run
```

## Note tecniche

- Il package resta un semplice eseguibile Swift Package.
- Per creare una `.app` firmata o distribuibile conviene aprire `Package.swift` in Xcode e rifinire bundle, icona e signing.
