# PC setup

A simple semi-automated script to set up your environment after formatting your PC.

> semi-automated means it still need some manual operation such UAC and software custome settings.

This script use scoop and winget to manage apps.
Use [`scoop`](https://scoop.sh/) manage cli tools such as busybox and python.
Use [`winget`](https://github.com/microsoft/winget-cli) manage GUI apps such as Chrome and PowerToys.

## Q&A

### winget connection very slowly

`winget settings` and add content.

```
"network": {
  "downloader": "wininet"
}
```
