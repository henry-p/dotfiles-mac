# Gmail-Abruf und Eingabeformat

## Vollständiger Snapshot

1. Gmail-Tools über Name und Beschreibung entdecken. `search_email_ids` liefert die vollständige ID-Liste, `read_email` mit `format: "full"` liefert den äußeren MIME-Baum.
2. `as_of` einmal als ISO-Zeit mit Zeitzone festlegen. Dieselbe Grenze als Unix-Sekunden in `before:` verwenden. `as_of` auf eine volle Sekunde setzen, damit Gmail-Suche und lokale Prüfung identisch abgrenzen.
3. Alle Suchseiten lesen, `message_ids` deduplizieren, Folgetoken bis zum Ende verfolgen. Alle IDs in einem Manifest speichern. Geschätzte Ergebnismengen sind keine bestätigte Vollständigkeit.
4. Jede ID vollständig lesen. Batches von etwa 10–20 unabhängigen Leseaufrufen sind zweckmäßig. Erfolgreiche Antworten fortlaufend in eine private JSONL-Datei schreiben. Bei Wiederaufnahme ausschließlich fehlende IDs lesen; bestehende Ergebnisse unverändert erhalten.
5. Die ID-Mengen müssen übereinstimmen. Bei einem Lesefehler gezielt erneut lesen. Bleibt die Nachricht unzugänglich, Abruflücke benennen und den Report nicht als vollständig darstellen. Der Analyzer lehnt eine unvollständige Eingabe ab.

Für einen begrenzten Zeitraum eine exklusive obere Grenze und eine inklusive untere Grenze verwenden. Wenn Gmail-Datumsoperatoren abweichende Tagesgrenzen hätten, nach Unix-Zeit abfragen oder etwas breiter suchen und die erwartete ID-Liste anhand vollständig gelesener Zeitstempel abgrenzen. Das tatsächliche Vorgehen im Manifest nachvollziehbar halten. Keine früheren Snapshotzahlen als aktuelle Zahlen übernehmen.

## Manifest

Die Datei enthält:

```json
{
  "query": "in:anywhere from:quote@sacoshipping.com before:<Unix-Sekunden>",
  "as_of": "<ISO-Zeit mit Zeitzone>",
  "pagination_complete": true,
  "expected_message_ids": ["<alle tatsächlich gefundenen Gmail-IDs>"]
}
```

Optional `since` als inklusive ISO-Untergrenze mit Zeitzone hinzufügen. Die JSON-Beispiele sind Strukturbeschreibungen; Platzhalter durch tatsächliche Werte ersetzen. Das Manifest darf keine OAuth-Tokens oder Zugangsdaten enthalten.

## Nachrichten

`analyze.py` akzeptiert eine JSONL-Datei, ein JSON-Array oder `{"messages": [...]}`. Pro Nachricht kann eine unveränderte `read_email`-Antwort mit `structuredContent` oder deren Inhalt gespeichert werden. Die relevanten Connectorfelder sind `id`, `internal_date`, `payload.headers`, `payload.mime_type`, `payload.parts` und `payload.body.content` beziehungsweise `base64_url_content`.

Alternativ vollständig normalisierte äußere Nachrichtentexte speichern:

```json
{
  "id": "<Gmail-ID>",
  "internal_date": "<Millisekunden seit Unix-Epoche>",
  "from": "SACO Quote AI <quote@sacoshipping.com>",
  "subject": "<vollständiger Betreff oder leerer String>",
  "body_text": "<vollständiger äußerer Klartext>",
  "body_html": "<äußeres HTML, falls verfügbar>"
}
```

`body_html` ist optional. Wenn `body_text` fehlt, muss vollständiges `body_html` vorliegen. Ein leeres äußeres Textteil plus HTML ist erlaubt. Bei einem auszulagernden MIME-Textteil dessen Inhalt über eine unterstützte Leseoperation beschaffen und die normalisierte Darstellung verwenden. Snippets und reine Metadaten sind keine vollständige Eingabe.

Der Analyzer bevorzugt äußeren Klartext und nutzt HTML zusätzlich zur Tarifprüfung. Er ignoriert Dateianhänge, `Content-Disposition: attachment`, benannte MIME-Teile und `message/rfc822`. Text und HTML derselben Nachricht werden nicht als zwei Nachrichten oder doppelte Fehler gezählt. Einen fehlenden Subject-Header als leeren Betreff behandeln.

## Fehlerprüfung

Die Regeln erkennen die deutsch- und englischsprachigen Meldungen des bisherigen Reports. Drei Hinweise ohne Aufzählungszeichen werden gesondert erkannt: unbestätigte Packstückdaten, technischer Verarbeitungsabbruch und nicht zugeordneter Zielort.

Eine Fehlergruppe wird pro E-Mail dedupliziert. Bekannte Kunden-/Firmen-/Tarifmeldungen sind ausgeschlossen. Ohne weitere erkannte Fehler und mit einer bekannten ausgeschlossenen Meldung zählt die E-Mail zu `excludedCustomerOnly`. Andernfalls erscheint sie in `uncategorizedNeedsWork` und `review`.

`review` kann auch neue OSCA-Meldungen neben bereits bekannten Fehlern enthalten. Vor Abschluss lesen. Bei einer belegten neuen Fehlerart deren stabile ID, deutschen Namen, Erkennungsregel und Farbe in `error-groups.json` ergänzen. Bestehende IDs nicht umnummerieren: `error-07`, `error-11` und `processing-abort` werden von den drei Sondererkennungen verwendet. Die sechs Farben bündeln verwandte Meldungen; die vollständigen Namen stehen in Tabelle und Tooltip.

Rohdaten und `review` sind Arbeitsunterlagen. Das HTML enthält aggregierte Werte und keine Rohtexte oder Kundenkontakte. Ein Fehlercode ohne Beschreibung bleibt eine unbeschriebene OSCA-Meldung; weder Ursache noch Verantwortlichkeit daraus ableiten.
