# Minutes 0.1.9

Release scope: the System Audio picker lists call apps (FaceTime, WhatsApp,
Discord, Zoom, Teams, Slack, Webex, Signal, Telegram) alongside browsers,
grouped by kind. FaceTime capture includes avconferenced, which plays its call
audio. Browser-specific copy now says "app".

Version 0.1.9, build 10. Validate full tests, release bundle, archive, published
digest, remote tag, and the scoped Nix source pin/package. Preserve unrelated
staged dotfiles changes. No system activation or installed-app replacement.

Full test suites passed (48 and 35 reported tests). avconferenced was confirmed
as a tappable Core Audio process; live call capture in each app was not
verified before release.
