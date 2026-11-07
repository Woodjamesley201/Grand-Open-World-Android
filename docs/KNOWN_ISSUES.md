# Known issues & limitations

- **Asset download is mandatory** (by design): first launch requires ~1 GB downloaded
  from GitHub Releases. If GitHub is unreachable the menu shows an error; retry later.
- Trees and palms have no collision (cars drive through them). Chosen for mobile
  performance.
- Traffic cars sometimes bump at sharp intersections; the AI brakes late at high density.
- Swimming has no dive mechanic — Marcus floats on the surface.
- Sidewalks are visual-only (no curb collision) so vehicles can mount them freely.
- Vehicle "damage" is health-based (smoke → fire → explosion); no mesh deformation.
- Buildings have no interiors except the three shops and the tunnel.
- Music crossfades between tracks are a simple hard switch.
- The debug keystore used by CI is fine for sideloading; a release keystore is needed
  for Play Store distribution.
- Minimum viable device: ~3 GB RAM, Android 10. Very old GPUs may fall back to slow
  software rendering (rare).
