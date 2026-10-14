# Islam Quiz – toegankelijkheid (op pauze, aan het einde oppakken)

## Status
- Alleen kleurcontrast is doorgevoerd in index.html (voor/na-vergelijking getoond, verschil klein).
- Rest nog niet gebouwd. Backup van de versie ervoor: index.pre-a11y.html.

## Al gedaan (kleuren)
- --muted #66756c -> #5a695f
- Nieuw --gold-text #8a5a14 voor gouden tekstlabels (.mode-card .sub, .q-num, .rev-item .qn, .rank-n): contrast 2,3 -> 5,9
- --bad #d9534f -> #bf3f3a (wit op rood 4,0 -> 5,3)
- Focusrand donkergroen #1b4332 i.p.v. goud (knoppen en kleurkiezer)

## Nog te doen
1. Bevinding: `<div id="app" aria-live="polite">` laat schermlezers bij elke render alles voorlezen. Vervangen door `<main id="app">` plus twee verborgen live-gebieden (polite en assertive) en een `announce()`-functie.
2. Focusbeheer per scherm: bij schermwissel focus naar de kop; bij nieuwe vraag focus naar de vraagkaart (role=group, aria-labelledby + aria-describedby met de 4 opties); na antwoord kort "Goed!"/"Fout." (assertive), daarna focus naar de uitleg. Focus herstellen na hertekenen (zelfde data-act).
3. Timer: aankondigen bij 10 sec (polite) en 5/3 sec (assertive); visuele balk aria-hidden.
4. Labels: categoriekaarten (titel, niveaus, beste score), speler verwijderen ("Verwijder speler Aisha"), wisselknoppen met huidige stand, vergrendelde niveaus (aria-disabled + "Vergrendeld"), Reis-stops met landnaam, kleurkiezer met kleurnamen i.p.v. hex, tabs/land-chips als aria-pressed-knoppen.
5. Dialogen: role=dialog, aria-labelledby, #app en badges-knop inert tijdens dialoog, Escape sluit, focus terug naar opener; disclaimer- en badges-modal idem.
6. Optionele schakelaar "Spreek vragen uit" via speechSynthesis (nl-NL), knop "Lees voor", instellingen-dialoog "Toegankelijkheid" (icoon in topbalk); presentator-mp3 uit als dit aan staat; waarschuwing: zet uit bij gebruik van een schermlezer.
7. Automatisch doorgaan na resultaat (8 sec) uitzetbaar ("Niet automatisch doorgaan"); standaard uit als voorlezen aan staat.
8. Overig: document.title per scherm, focus-visible algemeen, .icon-btn.small naar 44px, .option.dim opacity .8, sr-only klasse.
