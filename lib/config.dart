/// True only for personal builds made with `--dart-define=PERSONAL=true`.
///
/// Personal builds show NBA team logos (loaded at runtime from ESPN's CDN,
/// never bundled) and are shared directly, not through the public GitHub
/// releases. The public build leaves this false and shows no logos.
const bool kPersonal = bool.fromEnvironment('PERSONAL');
