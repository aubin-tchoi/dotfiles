# Raycast

`extensions.json` records the installed Store extensions from this Mac. Open
each Store URL to reinstall it, then sign in again where needed. The inventory
does not contain extension preferences, credentials, aliases, or hotkeys.

Raycast 2 stores settings in encrypted databases. Its supported backup is
[Export Settings & Data](https://manual.raycast.com/import-export), which creates
an encrypted `.rayconfig` file. Keep that file and its passphrase in private
storage: exports also include categories such as clipboard history, AI chats,
and notes. All `.rayconfig` files are ignored by this repository.

To restore, run **Import Settings & Data**, choose the private backup, enter its
passphrase, and select **Settings, Aliases & Hotkeys** and **Extensions installed
from the Store**. Choose other categories only if you want to restore their data.

The current repository contains the extension inventory only; a private settings
export still needs to be created in Raycast.
