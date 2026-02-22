# DeathNotificationLib — Known Issues & Future Work

## Wire-format escaping (partially addressed)

`encodeMessage()` now escapes `last_words` and `extra_data` at the wire
level (`~` → `\t`, `|` → `\p`, `\` → `\\`) and dynamically truncates
`last_words` so the total message fits within Blizzard's 255-byte limit.

### Remaining items


- [ ] **Message fragmentation for full `last_words` preservation.**
  The current approach truncates `last_words` to ~120-160 encoded
  characters depending on other field sizes. A fragmentation scheme
  (numbered chunks reassembled on receive) would preserve the full
  255-character chat message but adds significant protocol complexity
  and requires changes to all three receive paths (channel broadcast,
  addon whisper query response, sync entry).
