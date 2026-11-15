# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Use GitHub's private reporting instead: on the repository page open **Security → Report a vulnerability**.
Describe what you found, how to reproduce it and which version of the app you used. You will get a reply
as soon as possible, and credit in the release notes if you want it.

## What is in scope

- The app itself: handling of credentials, call control, notifications, background service, stored data.
- The build configuration in this repository.

Out of scope: your PBX, third-party packages (report those upstream — but do tell us if the app uses them
in an unsafe way).

## Good to know

- The password is kept in Android Keystore-backed storage; history and contacts are excluded from backups.
- `ws://` addresses are not encrypted — the app warns about it. Use `wss://`.
- A build made with `--dart-define=SADO_SIP_LOG=true` writes complete SIP messages to the system log.
  It is meant for debugging on your own device only — never distribute such a build.
- The web build is a preview: a browser cannot protect a saved password the way Android does.

---

# Безопасность

Нашли уязвимость — пожалуйста, **не создавайте открытую задачу**. Напишите закрыто: на странице
репозитория **Security → Report a vulnerability**. Опишите, что нашли, как это повторить и какая у вас
версия приложения.
