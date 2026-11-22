# Questfund 0.4.0

Questfund durchsucht den Rucksack, die ausgerüsteten Taschen und die persönliche Bank in **World of Warcraft: Forever**. Dazu kommen Reagenzientasche und Reagenzienbank, soweit der Client sie anbietet. Öffne das Fenster mit `/questfund`. Mit Titan Panel findest du **Questfund** unter **Interface**.

Öffne die Bank einmal im Spiel, damit Questfund ihre Fächer und Taschen einliest. Bei geschlossener Bank zeigt das Fenster den zuletzt erfassten Stand samt Datum und Uhrzeit. Die Taschen werden aus dem laufenden Client eingelesen.

- **Ohne aktive Quest** zeigt Gegenstände mit bekannter Questzuordnung, für die gerade keine passende Quest im Log steht.
- **Questlog** zeigt deine aktiven Quests, auch wenn du noch keinen zugehörigen Gegenstand besitzt. Bei einem Inventarfund kannst du die zugehörigen Quests über die Pfeile oben im Detailbereich wechseln.
- **Questgeber**, **Ziele** und **Abgabe** zeigen die jeweiligen Orte. Bei mehreren Stellen wechselst du mit den Pfeilen neben dem Gebiet. Auf der Weltkarte stehen Blau für Questgeber, Amber für Ziele und Mint für Abgaben. Sie zeigt bekannte Punkte der gewählten Quest im angezeigten Gebiet. Die Minimap verfolgt den ausgewählten Punkt.
- Sammelziele können mehrere mögliche Beutequellen haben. Bei einer aktiven Quest kann auch der Wegpunkt aus dem Questlog erscheinen. Unbekannte Orte sind in der Detailansicht gekennzeichnet.
- **Wiederholbar** zeigt bekannte wiederholbare Abgaben, auch für normale Stapelgegenstände wie Runenstoff. Wähle einen Gegenstand aus. In der Detailansicht siehst du Quest, Mindeststufe, Abgabe-NPC oder -Objekt, Zone und Koordinaten, soweit bekannt. Über die Pfeile wechselst du bei mehreren Abgaben oder Orten.
- Klick auf die Koordinaten öffnet die Weltkarte des Gebiets. Die mintfarbene Markierung zeigt den gewählten Abgabepunkt. Beim Darüberfahren siehst du NPC oder Objekt, Quest und Koordinaten. Beim Schließen der Karte erscheint Questfund wieder mit deiner Auswahl.
- **Verfolgen** startet die Weganzeige direkt. Sie bleibt auch nach Schließen der Weltkarte sichtbar und zeigt Himmelsrichtung und Luftlinie in Yards. Der Minimap-Pin sitzt am Ziel oder am Kartenrand, wenn das Ziel außerhalb des sichtbaren Ausschnitts liegt. Bei einem anderen Kartenbereich zeigt Questfund das Zielgebiet, falls keine gemeinsame Positionsberechnung möglich ist.
- Klick auf den Minimap-Pin oder die Weganzeige öffnet die kleine Gebietskarte. Der mintfarbene Punkt zeigt das verfolgte Ziel. Der helle Punkt zeigt deine Position, wenn du auf derselben Gebietskarte bist. **Stopp** rechts an der Weganzeige oder `/questfund stop` beendet die Verfolgung.
- Die Liste berücksichtigt die Fraktion der Quest sowie von Questgeber und Abgabe-NPC. Neutrale Kontakte stehen beiden Fraktionen zur Auswahl. Gegner können als Kampfziel oder Beutequelle erscheinen. Einschränkungen für einzelne Völker und Klassen bleiben berücksichtigt.
- **Benötigt pro Abgabe** zeigt die Menge für den gewählten Gegenstand. Darunter stehen Bestand und Fehlmenge. **Aus Bank holen** zeigt, wie viel du aus der Bank einpacken musst. Bei geschlossener Bank basiert das Ergebnis auf dem angezeigten Bankstand. Wurde die Bank noch nie gescannt, nennt Questfund die Fehlmenge in den Taschen. Über **Weitere Materialien** siehst du die übrigen bekannten Anforderungen.
- **Queststart** zeigt Gegenstände, die eine noch ausstehende Quest beginnen. **Aktiv** zeigt Gegenstände, die zu einer laufenden Quest gehören. **Unklar** sammelt vom Client oder Index als Questgegenstand erkannte Gegenstände mit fehlender Zuordnung.

Die Mengen stammen aus dem Questlog, wenn der Client die Abgabe eindeutig zuordnen kann. Andernfalls zeigt Questfund die abgeglichene Classic-Referenz. Ruf, Vorquests und andere Voraussetzungen können die tatsächliche Abgabe beeinflussen.

Klicke auf einen Fund, um die Questzuordnung sowie Tasche oder Bankfach mit Platznummer zu sehen. Wenn der Client einen Questnamen laden kann, erscheint er in der Detailansicht. Die Quest-ID dient als Ersatz.

Die Zuordnung kombiniert Live-Daten mit einem fest eingebauten Forever-Index. Abdeckung und Quellen stehen in [DATA-SOURCES.md](DATA-SOURCES.md).
