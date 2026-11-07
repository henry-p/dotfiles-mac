---
name: saco-quote-report
description: Erstelle oder aktualisiere den SACO-Quotierungsreport aus Gmail als einzelnes HTML-Dokument mit monatlicher Statusverteilung, deutscher Executive Summary, Fehlerranking sowie absoluten und relativen Sankey-Verläufen. Verwenden, wenn dieser SACO-Report erneut erstellt oder aktualisiert werden soll.
---

# SACO Quote Report

Erzeuge einen deutschen, zusammenhängenden HTML-Report aus allen E-Mails von `quote@sacoshipping.com`. Standardmäßig die gesamte verfügbare Historie bis zum Beginn dieses Abrufs verwenden. Einen vom Nutzer vorgegebenen Zeitraum übernehmen. Monat und Datum in `Europe/Berlin` bestimmen.

## Definitionen beibehalten

- Needs work: Betreff enthält `[Needs work]`, unabhängig vom Tarif.
- Working DUMMY: Kein solcher Betreffmarker und im Tarif-Feld steht `VORGABE`. Beide historischen Schreibweisen `77777` und `777777` erfassen. In sichtbaren Kategorien heißt das `DUMMY`.
- Working: Weder Marker noch VORGABE im Tarif-Feld.
- Eine E-Mail entspricht einem Datensatz. Wiederholte Verarbeitungen mit unterschiedlichen Gmail-IDs bleiben enthalten; identische Gmail-IDs deduplizieren. Keine eindeutigen Kundenanfragen oder bestätigten Erfolgsergebnisse aus diesen Kategorien ableiten.
- Das Fehlerranking untersucht ausschließlich Needs-work-E-Mails. Kunden-/Firmen-/Tarifzuordnungsfehler ausschließen. Zusätzliche Orts-, SACO-, Sendungs- und Transportfehler auch bei DUMMY-E-Mails zählen. Pro E-Mail jede Fehlerart höchstens einmal zählen.
- Prozentwerte im Statusdiagramm beziehen sich auf alle E-Mails des jeweiligen Monats. Ranking-Prozente beziehen sich auf alle Needs-work-E-Mails des Zeitraums. Relative Sankey-Anteile beziehen sich auf alle berücksichtigten Fehlernennungen des jeweiligen Monats, nicht auf E-Mails.

## Daten neu abrufen

Lies [references/gmail-input.md](references/gmail-input.md) vor dem Abruf. Verwende den Gmail-Connector und eine feste Abrufgrenze. Suche `in:anywhere from:quote@sacoshipping.com before:<Unix-Sekunden>` ohne Beschränkung auf Posteingang oder ungelesene Nachrichten. Spam und Papierkorb sind eingeschlossen. Erweitere die Suche um explizite Zeitraumvorgaben.

Alle Seiten mit `search_email_ids` abrufen und jede ID mit `read_email, format full` lesen. Detaillierte `search_emails`-Ergebnisse sind kein Vollständigkeitsnachweis: In dieser Analyse fehlten dort Nachrichten, die in der ID-Suche vorhanden waren. Seiten können weniger als die angeforderte Menge liefern und trotzdem einen Folgetoken haben. Erst bei fehlendem Folgetoken stoppen.

Nur den eigenen äußeren Nachrichtentext auswerten. Anhänge und verschachtelte `message/rfc822`-Originalmails nicht als weitere Report-E-Mails oder zusätzliche Fehlermeldungen zählen. Metadaten, vollständigen äußeren Text und gegebenenfalls HTML erfassen. Ein Gmail-Snippet genügt nicht, um Tarif und Fehler vollständig zu bestimmen. Arbeite mit begrenzten parallelen Lesebatches und speichere sie fortlaufend, damit ein unterbrochener Abruf fortgesetzt werden kann.

Stelle die gelesenen IDs gegen die vollständige Suchliste ab. Fehlgeschlagene Lesevorgänge gezielt wiederholen. Einen unvollständigen Abruf nicht als vollständigen Report ausgeben. Frühere Zahlen und HTML-Dateien dienen höchstens zum Vergleich und ersetzen keinen aktuellen Abruf.

## Analysieren und erstellen

```sh
python3 <skill-dir>/scripts/analyze.py --input <messages.jsonl> --manifest <manifest.json> --output <analysis.json>
python3 <skill-dir>/scripts/render.py --input <analysis.json> --output <saco-quote-report.html>
```

Die Skripte verwenden die Python-Standardbibliothek. Sie benötigen keine eigene Gmail-Anmeldung. Der Connectorabruf erfolgt durch den ausführenden Agenten. Eingabeformat und Wiederaufnahme stehen in der Eingabereferenz.

Prüfe in `analysis.json` insbesondere `review`, `uncategorizedNeedsWork`, die Monats- und Statussummen. Die bisherigen Fehlerarten stehen in [references/error-groups.json](references/error-groups.json). Neue oder nicht zuordenbare Meldungen anhand ihres äußeren Nachrichtentexts prüfen; nicht stillschweigend als Zuordnungsfehler ausschließen oder einer ähnlichen Kategorie zuschlagen. Ergänze die Regeldatei bei einer belegten neuen Fehlerart, analysiere erneut und erhalte bestehende Kategorien. Keine Ursachen aus einem Fehlercode erraten. Eine ungeklärte Meldung als nicht zugeordnet ausweisen, wenn sie sich aus der Quelle nicht bestimmen lässt.

## Ein zusammenhängendes HTML-Dokument

Die Vorlage [assets/report.html](assets/report.html) und `render.py` liefern die vereinbarten Formate in einem selbständigen, offline lesbaren Dokument:

1. Executive Summary: Kurze deutsche Bullet Points, aus denselben Aggregaten wie die Diagramme. Sachlich, ohne „nur“, wertende Adjektive oder unbelegte Aussagen über manuellen Aufwand.
2. Statusverteilung: Monatlich gestapelte Balken mit Working, Working DUMMY und Needs work. Jede nichtleere Teilfläche hat vier abgerundete Ecken und einen gerundeten Monatsanteil. Mengen und präzisere Anteile stehen zusätzlich im Tooltip und in einer zugänglichen Wertetabelle.
3. Fehlerranking: Absteigend sortierte Tabelle mit Anzahl betroffener E-Mails und Anteil an allen Needs-work-E-Mails. Gleichstände gleich ranken.
4. Absoluter Fehlerverlauf: Sankey-artig verbundene Monatsverteilungen mit Banddicke entsprechend der Fehlernennungen und einer gemeinsamen Mengenskala.
5. Relative Fehlerverteilung: Dieselben Daten, Reihenfolge und Farben, je Monat auf 100 % der Fehlernennungen normiert. Nullmonate haben keine Verteilung, nicht erfundene Anteile.
6. Relative Gesamtverteilung einschließlich Working und Working DUMMY: Jeder Monat entspricht 100 % aller E-Mails. Needs-work-E-Mails mit mehreren erkannten Fehlerarten werden mit je `1 / Anzahl Fehlerarten` auf diese verteilt, damit jede E-Mail insgesamt einmal zählt. Reine Kunden-/Tarifzuordnungsfehler und nicht zugeordnete Needs-work-E-Mails erhalten eigene Bänder, damit keine E-Mails fehlen. Nur in dieser Gesamtansicht diese Restgruppen einbeziehen; das bestehende Fehlerranking und die beiden Fehlerverläufe bleiben unverändert. Den monatlichen Needs-work-Anteil direkt anzeigen. Gemeinsame dünne Konturen fassen Working und Working DUMMY als Working gesamt sowie sämtliche Needs-work-Fehlergruppen zusammen; die Untergruppen und ihre Bänder bleiben erhalten. Im Gesamt-Sankey liegen alle Fehlergruppen oben, Working und Working DUMMY darunter. Beide Working-Untergruppen erhalten unterschiedliche Grüntöne. Für Fehler Rot, Orange, Violett oder Grau verwenden; keine grünen oder sonst positiv besetzten Farben. Die leuchtende Palette der Chat-Ansicht verwenden, auch im HTML-Report. Die zentralen Farbvariablen in assets/report.html enthalten diese Zuordnung; nicht durch eine gedecktere Standardpalette ersetzen. Neutrale und gemischte Farben an Hell-/Dunkelmodus anpassen. Mengen in den Detailfehlerbändern sind anteilig zugeordnete E-Mails, nicht ganzzahlige Fehlerhäufigkeiten. Tooltip und Wertetabelle müssen das benennen. Nicht behaupten, dass die Bandverteilung allein einen absoluten Rückgang belegt.

Die Sankey-Verbindungen vergleichen unabhängige Monatsverteilungen. Sie verfolgen keine einzelnen Anfragen und behaupten keinen Fehlerwechsel derselben E-Mail. Mehrfachfehler pro E-Mail erklären abweichende Fehler- und Nachrichtensummen. Anfangs- und Endteilmonate sichtbar markieren. Fehlerarten mit null Nennungen nicht als beobachtete Fehler ausgeben. Alle tatsächlich gefundenen Gruppen erhalten.

Die Vorlage enthält die aggregierten Daten, CSS und JavaScript inline. Rohtexte, Kundenadressen und Anhänge gehören nicht in das ausgelieferte HTML. Detailwerte für Fehlergruppen sind ausklappbar. Statusdiagramm, Text, Ranking und beide Fehlerverläufe müssen auf genau derselben `analysis.json` beruhen.

## Prüfen und übergeben

- Die eingebauten Konsistenzprüfungen müssen bestehen. Summen und Nenner kontrollieren; in positiven Fehlermonaten müssen relative Anteile 100 % ergeben.
- Einen repräsentativen Report im verfügbaren Browser bei breiter und schmaler Ansicht öffnen. Sichtbare Balken, Rundungen aller Teilflächen, Beschriftungen, beide Fehlerverläufe, Tooltips und ausklappbare Werte prüfen. Bei fehlendem Browser diese konkrete Einschränkung nennen; eine erfolgreiche Python-Ausführung ist kein Renderingnachweis.
- Abschließend genau das erzeugte HTML verlinken. Den abgedeckten Zeitraum nennen. Nicht automatisch veröffentlichen, versenden oder eine wiederkehrende Automation einrichten.
