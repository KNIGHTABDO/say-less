# Say Less: "Postcards" scene pitch (draft for approval)

Reference image: `concepts/5-postcards.png`. Postcards is the default look. The other five concepts can become themes later on the same layout and gestures.

## Materials
- **Table**: a warm linen surface (subtle woven texture, soft daylight, gentle vignette) that the cards lie on.
- **Cards**: thick deckle-edged card stock with a small stamp in the corner and a postmark. They cast a real shadow that grows when you lift a card.
- **Text on the cards**: translated text is always set in a **large, clean serif**, readable upside down from across the table and in every script (Japanese, Arabic, Thai…). Handwriting is used only for decoration: "Dear…", signatures and the postmark.
- **Controls**: iOS 26 Liquid Glass. The speak capsule, the language chips and the drawer handle float above the table and bend the paper beneath them.
- **Colour**: sun-faded terracotta, sea blue and olive. Each language gets its own stamp colour.

## Conversation screen (where 90% of the time is spent)
- The screen is split across the fold: the **top half is rotated 180°** for the person opposite, the bottom half is yours. Each half has its own stack of cards.
- **The live card**: while someone speaks, a fresh card lies on top of their stack and the words appear **as they are recognised**, each settling from a soft blur into ink.
- When the sentence ends, the translated card **slides across the fold** to the other person's stack. The postmark **stamps** (haptic thud), and the voice plays as the stamp lands.
- Finished cards stack with a slight random tilt (±3°). Only the top card is large; older cards fan out underneath.

### Gestures
| Gesture | What it does |
|---|---|
| Hold the glass capsule on your half | Talk (push-to-talk) |
| Tap the capsule | Hands-free mode: the app detects who is speaking and takes turns automatically |
| Flick a card across the fold | Send it again and replay its voice |
| Long-press a card | Flip it over. The back shows the original text, a pronunciation guide, "say it slower", and copy |
| Swipe a card down off the table | Drop it into the **shoebox** (conversation history) |
| Pinch out on a stack | Spread it into a timeline of the whole conversation |
| Pull down the top edge | The **postcard rack** drawer: change languages |
| Turn the phone upside down, or swipe two fingers | Swap which half is yours |

## Language packs: the postcard rack
- A spinning souvenir-shop rack you turn with your finger. Each card is one language, with its name in its own script and the stamp shows the region.
- **Downloaded** cards are bright. A **downloading** card "develops" like a Polaroid as the progress fills. Cards not yet downloaded sit in a pale paper sleeve.
- Each card shows the pack size and what it includes (speech recognition, translation, and a voice or "read only").
- Delete a pack by tearing its card (a confirmation appears first).

## Onboarding: "Dear me…" (it does the real setup)
1. A blank postcard on the linen. The ink writes: *"Dear me, this trip I'm going to…"*
2. Tapping the stamp area asks for the microphone, explained by the moment itself ("tell me where").
   - The user speaks or types their destinations. Speech recognition for the user's own language downloads first, and typing is offered while it downloads.
3. Each destination becomes a **stamp** that lands on the card. Dropping a stamp starts that language pack downloading in the background.
4. While the packs download, the card flips, and the user's own sentence comes back **translated into the first destination's language**, played aloud. That is the first real translation.
5. A postmark with "Say Less" and today's date stamps the card, and it drops into the shoebox.
   - The shoebox is how the user finds history later.

## Motion and feel
- Every movement uses springs, no linear easing. The app runs at 120 Hz.
- **Haptics**: a soft slide when a card moves, a firm thud when the postmark stamps, a light tick as the rack turns.
- **Sound** (optional, can be turned off): faint paper sounds and a stamp thud.

## Diagnostics: "the back of the shoebox"
A hidden screen for testing:
- Live latency for each stage.
- Words per second.
- Peak memory and the phone's heat level.
- Which model is used for each language.
- A copy-log button so you can send me the numbers.

## Next
After approval, I publish a throwaway touch prototype as a web page you open on the iPhone. It covers gesture feel only; the glass there is fake.
