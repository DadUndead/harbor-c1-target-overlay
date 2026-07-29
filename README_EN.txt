L2 Target Overlay (Harbor C1) - v1.3.0
======================================

(Русская версия: README.txt)

Shows an overlay with stats, drop and spoil for your currently selected
target. Works entirely outside the game: it screenshots the small screen
area where the game itself draws the target's name, runs OCR on it, and
looks up a match in the server's database. No injection into the game,
no client file modification at all.

Project page (source, ready-made builds, new versions):
https://github.com/DadUndead/harbor-c1-target-overlay

UPDATES
-------
On every launch the program checks GitHub once for a version newer than
yours (a plain anonymous request, no keys, no tracking). If one exists,
it offers to download and extract it (into an update_vX.X.X folder next
to the exe); copy the exe and _source.ahk from there over your current
files. If GitHub is unreachable or you're offline, the check is simply
skipped silently - the overlay works as usual either way.

INSTALLATION
------------
1. Copy the whole L2TargetOverlay folder (exe + the .txt database files)
   anywhere you like - easiest is right into the client folder
   "Lineage 2  Harbor C1", next to System.

2. Tesseract OCR is required - on first launch L2TargetOverlay.exe will
   offer to install it automatically (via winget, takes a minute or two,
   no manual steps). If auto-install fails (no winget or no internet),
   it shows the command for a manual install:

     winget install --id UB-Mannheim.TesseractOCR

RUNNING IT
----------
1. Start the game, log into your character.
2. Run L2TargetOverlay.exe - a UAC prompt appears ("Do you want to allow
   this app to make changes?"), click "Yes". The program relaunches
   itself with admin rights automatically, that's normal.
3. Right after launch, a small menu window appears in the top-right
   corner (left of the radar) with checkboxes "Timer", "Mob Info",
   "Translator", "Party" and a "☰" button on the right. All checkboxes
   are off by default - check whichever windows you want shown. The "☰"
   button opens a menu with "Calibrate" (see CALIBRATION below) and
   "Gemini API..." (enter your personal key, see the translate section).
   Shift+ScrollLock hides the menu and all windows at once, pressing it
   again brings them back. Checked boxes are remembered and restored on
   the next launch.
4. (With "Mob Info" checked) Target a monster - a compact line "Name
   Level" appears (an asterisk after the level, e.g. "Tamlin Ork Archer
   42*", means the mob is aggressive), with a "v" button next to it.
   Click "v" to expand the panel with stats, traits and drop/spoil ("^"
   collapses it back).

The overlay defaults to the top-right corner of the screen, under the
radar. The script auto-adjusts the capture area to your actual screen
resolution (it reads the client's System\Option.ini), but if you have a
non-standard UI (moved windows, different resolution) it may need
adjusting.

All four windows (menu, target, chat translate, buff timer) can be
dragged with the mouse - hold the left button on any empty part of the
window (not on a button/checkbox itself) and drag. The new position is
remembered (in window_positions.ini next to the exe) and restored on the
next launch.

CALIBRATION (if the target name, chat, or party list aren't
recognized/get cut off)
--------------------------------------------------------------
Check "Calibrate" from the "☰" menu - three colored translucent
rectangles appear over the game: red "TARGET" (where the program reads
the target's name), blue "CHAT" (where it reads chat) and green "PARTY"
(where it reads the party list). You can:
- drag them - hold the left button inside the rectangle and drag;
- resize them - drag an edge/corner (like a normal window with a
  border).
Line the red rectangle up exactly over the area where the game shows the
target's name (usually a thin strip above the skill bar), the blue one
over the chat window, and the green one over the list of names in the
party window (not including the HP/MP bars). Changes apply immediately
(on the very next scan) and are remembered - the zones will be in the
same place on the next launch. Click "Calibrate" again (or "■ END
CALIBRATION" under the menu) when done - the rectangles disappear and
recognition keeps working with the new coordinates.

The old method (a screenshot for manually editing coordinates) still
works too: press End (for the target), Home (for chat) or Insert (for
party) - this saves a file to
%TEMP%\l2_target_capture_debug.bmp (or l2_chat_capture_debug.bmp /
l2_party_capture_debug.bmp), which you can send to whoever maintains the
tool, or use to adjust CAPTURE_X/Y/W/H by hand in the source.

AGGRO
-----
The Harbor C1 server differs from the base game in places - some mobs
marked passive in the base data are actually aggressive in practice.
Aggression is shown as an asterisk after the target's level in the
header (e.g. "Tamlin Ork Archer 42*").

PARTY CLASSES (for buffers)
----------------------------
C1's native party window doesn't show character classes - inconvenient
for a buffer. Check "Party" in the menu - a window with a "Scan" button
appears. Clicking it reads the list of nicknames from the party window
and, for each one, shows the class from the database
(player_classes.txt):
- if the nickname is found - the class is shown next to it with a pencil
  icon "✎": click it to pick a different class if it was matched wrong;
- if the nickname isn't found - a class dropdown is shown right away;
  pick the right one and click "OK" - the choice is remembered (in
  player_class_overrides.txt) and that nickname will be recognized
  immediately next time.
Like chat translate, this isn't continuous tracking but a one-off scan
on click; press "Scan" again whenever the party's makeup changes.

If Gemini is configured (see below - same key as for chat translate),
party scan first tries to read the list via Gemini instead of Tesseract:
Gemini understands the image's context rather than just recognizing
pixels, so it's more reliable at telling real nicknames apart from
random noise, and correctly detects when there's no party list visible
at all (e.g. you're not in a party), simply showing nothing instead of
garbage. If no Gemini key is set, or the request fails, the scan falls
back to Tesseract automatically, same as before.

CHAT TRANSLATE
---------------
A separate window with a "Translate" button. Clicking it screenshots the
chat right at that moment and shows a translation. If Gemini is
configured (see below), the whole screenshot is sent to the model: it
finds all player messages by itself, translates only the ones not
already in the target language (leaving already-translated ones
unchanged), and picks each line's color to match its color in the game
(normal/trade/party/clan etc. - these are different colors in L2).
Without Gemini it works the old way: OCR reads the text line by line and
translates it via Google Translate. It doesn't run continuously in the
background - only on click, and each click shows a full snapshot of the
current chat (not just new lines).

The window can be resized by dragging its bottom edge with the mouse,
and scrolled with the mouse wheel to page through a long list of
messages - its size is remembered between launches. Translated lines are
shown in bright yellow, to tell them apart from lines already in the
target language at a glance.

LANGUAGE SELECTION (window header): From / To
-------------------------------------------------
Next to the Translate/Clear buttons there are two dropdowns, "From"
(English/Español/Português/Русский) and "To" (the same list). Both lists
are equivalent - either one can be set to Russian.
- Translate reads chat in the From language and shows the translation in
  the To language;
- Send (see below) goes the other way: from the To language into the
  From language.
For example, if you speak Russian with an English speaker, leave
From=English, To=Русский (these are the defaults). If From and To match,
translation is simply skipped and the message is used as-is.

SENDING YOUR OWN MESSAGE IN ANOTHER LANGUAGE
-----------------------------------------------
The same window has an input field. Type your message in the To language
(Russian by default) and press Enter right in that field (or click
"Send" if the mouse is easier) - the translation into the From language
is automatically typed into the game's chat and submitted (as if you'd
pressed Enter, typed the text, and pressed Enter again yourself). While
translating, the button briefly shows "...", that's normal - wait a
couple of seconds, don't click anything else in the meantime. The
message that was actually sent (with a language tag) appears in yellow
in the window's log - so you can immediately confirm what really went
out.

IMPORTANT: this is the only part of the program that needs internet -
translation goes through Google Translate (free, no key) or, if you set
it up, Gemini (see below). Everything else (target recognition, the
drop/stats database) still works entirely locally, with no network. If
the service is unreachable or breaks, chat messages just stay
untranslated - the target overlay is unaffected.

BETTER TRANSLATION VIA GEMINI (optional)
-------------------------------------------
Plain Google Translate translates literally and doesn't understand game
slang ("ks", "pt", "wtb", OCR typos). Gemini is an actual language
model, understands L2 slang and can guess meaning through typos. It's
free (no card needed), but every player sets up their OWN key:
1. In the menu, click "☰" -> "Gemini API..." - a window opens with a
   description and instructions.
2. Go to aistudio.google.com, sign in with a Google account, click
   Get API key -> Create API key (takes a minute).
3. Paste the key into the field in that window and click "Save".
The key is stored in the Windows registry under your account, NOT in a
file next to the program - it can't accidentally be shared along with
the tool's folder or archive. Without a key, everything keeps working
via plain Google Translate - this step is optional.

Google periodically changes which model is free - if you see a quota
error in the tray (or translations always go through [T] instead of
[G] - see gemini_debug.log below), check aistudio.google.com for which
model is currently free (usually the latest "Flash" or "Flash-Lite"),
and put its exact name (as in the API code sample, the model= field)
into a new file gemini_model.txt next to the exe. Without this file,
gemini-3.5-flash-lite is used by default.

Every translated message is tagged with where the translation came
from: [G] - Gemini, [T] - Google Translate. If Gemini is configured but
has run out of free quota (HTTP 429), that particular message silently
falls back to Google Translate instead of showing an error, and gets
tagged [T].

On first launch the program downloads the Russian language pack for
Tesseract once (~15 MB, also needs internet) - without it, recognizing
Russian text already in chat will be worse.

If Gemini is configured but translations keep being tagged [T] (meaning
Gemini keeps silently failing and everything falls back to Google
Translate) - the reason gets logged to gemini_debug.log next to the exe
(Gemini's actual error response - bad key, quota exhausted, etc.). Send
the contents of that file to get help figuring out what's wrong.

The translate window appears by default to the right of chat in its
standard position (bottom-left of the screen). If your chat has been
moved elsewhere, press Home to save a calibration screenshot
(%TEMP%\l2_chat_capture_debug.bmp) and check whether the capture window
lines up exactly with the chat area; whoever set up the program can
adjust the coordinates (CHAT_CAPTURE_X/Y/W/H at the top of the source).

BUFF TIMER
----------
Another small window near the buff bar (top of the screen, right of
HP/MP by default) - a countdown you start yourself the moment you cast a
buff. Type the buff's duration in minutes (20 by default - the standard
for most buffs on C1) and click ▶ (Start). At the 5-minute and 1-minute
marks the timer flashes a few times and plays a short beep; for the last
5 minutes and at zero it also turns red. The ♪ button next to ↺ mutes/
unmutes the sound (the flashing still happens either way). The ↺ (Reset)
button stops the countdown and returns the window to the entered
duration. If the buff bar sits somewhere else on your screen, whoever
set up the program can adjust its position (BUFF_TIMER_X/Y at the top of
the source).

WHAT'S INSIDE
-------------
- L2TargetOverlay.exe   - the program itself (no AHK install needed)
- L2TargetOverlay_source.ahk, l2_strings.ahk - full source (AutoHotkey v2)
- npc_names.txt          - list of NPC names (for fixing OCR mistakes)
- npc_info.txt           - NPC stats (HP/MP/attack/defense etc.)
- npc_drops.txt          - drop and spoil with the server's real rates
- npc_attributes.txt     - respawn, Passive/Active Attributes (from the
                           Prima Official Game Guide, pp. 202-223)
- npc_overrides.txt      - optional file of manual aggro corrections
                           (format: "name<TAB>yes/no" per line) - if
                           present next to the exe, its values are used
                           instead of the base data
- player_classes.txt     - nickname<TAB>class<TAB>level<TAB>clan of
                           server players (used for the "Party classes"
                           window above)
- player_class_overrides.txt - your own corrections/additions made via
                           the class selector, created automatically,
                           takes priority over the base data

The database was built from the Harbor C1 server's own data
(System\DB.json), including an HP correction (+20% over DB.json's values
to match the server's real rates). Respawn and Passive/Active Attributes
come from the official printed guide (Prima Official Game Guide), since
that data isn't in the server's own database.

The target overlay and the whole database (drop/stats/traits) work
entirely locally, with no network. The exception is chat translate (see
above), which uses Google Translate (or Gemini) for the translation
itself.
