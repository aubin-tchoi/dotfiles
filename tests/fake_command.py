"""Fail-closed stand-ins for installers; all writes stay in the test directory."""
import json
import os
from pathlib import Path
import shlex
import shutil
import sys

name, args = Path(sys.argv[0]).name, sys.argv[1:]
state = Path(os.environ["TEST_STATE"])
state.mkdir(exist_ok=True)
with (state / "calls").open("a") as output:
    output.write(json.dumps([name, *args]) + "\n")


def executable(file, content="#!/bin/bash\nexit 0\n"):
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(content)
    file.chmod(0o755)


def reject():
    raise SystemExit(f"Unexpected mock command: {name} {args}")


if name == "uname":
    print("arm64" if args == ["-m"] else os.environ.get("TEST_PLATFORM", "Darwin"))
elif name == "xcode-select":
    if args != ["-p"]:
        reject()
    print("/mock/CommandLineTools")
elif name == "brew":
    if args == ["shellenv"]:
        print("export HOMEBREW_PREFIX=" + shlex.quote(str(state / "brew")))
    elif args[:2] in (["bundle", "check"], ["bundle", "install"]):
        manifest = next(a.split("=", 1)[1] for a in args if a.startswith("--file="))
        marker = state / Path(manifest).name
        if args[1] == "check":
            sys.exit(0 if marker.exists() else 1)
        if os.environ.get("TEST_FAIL_BREW"):
            sys.exit(42)
        marker.touch()
    else:
        reject()
elif name == "git":
    if args[0] == "clone":
        url, destination = args[-2:]
        destination = Path(destination)
        destination.mkdir(exist_ok=True)
        project = url.rsplit("/", 1)[-1]
        filenames = {
            "ohmyzsh": "oh-my-zsh.sh", "powerlevel10k": "powerlevel10k.zsh-theme",
            "zsh-autoswitch-virtualenv": "autoswitch_virtualenv.plugin.zsh",
            "zsh-you-should-use": "you-should-use.plugin.zsh",
        }
        if os.environ.get("TEST_FAIL_CLONE") == project:
            (destination / "partial").touch()
            sys.exit(42)
        if project == "nvm":
            shutil.copyfile(Path(__file__).with_name("fake_nvm.sh"), destination / "nvm.sh")
        else:
            (destination / filenames.get(project, project + ".plugin.zsh")).touch()
    elif args[0] == "-C" and args[2:5] == ["config", "--local", "--get"]:
        hooks = os.environ.get("TEST_HOOKS", "")
        if hooks:
            print(hooks)
        else:
            sys.exit(1)
    elif args[0] == "-C" and args[2:] == ["config", "--local", "core.hooksPath", ".githooks"]:
        (state / "hooks").touch()
    else:
        reject()
elif name == "npm":
    if args[:3] != ["install", "--global", "--prefix"]:
        reject()
    executable(Path(args[3]) / "bin" / args[4])
elif name == "pipx":
    if args != ["install", "poetry"]:
        reject()
    executable(Path(os.environ["DOTFILES_TARGET_DIR"]) / ".local/bin/poetry")
elif name == "sudo":
    if args[0] != "apt-get":
        reject()
    if args[1] == "update":
        pass
    elif args[1:4] == ["install", "-y", "--no-install-recommends"]:
        (state / "packages").write_text("\n".join(args[4:]))
    else:
        reject()
elif name == "dpkg-query":
    installed = (state / "packages").read_text().splitlines() if (state / "packages").exists() else []
    if args[-1] in installed:
        print("install ok installed")
    else:
        sys.exit(1)
elif name == "defaults":
    db = state / "defaults.json"
    data = json.loads(db.read_text()) if db.exists() else {}
    operation, domain, key = args[:3]
    lookup = domain + "/" + key
    if operation in ("read", "read-type"):
        if lookup not in data:
            print("The domain/default pair does not exist", file=sys.stderr)
            sys.exit(1)
        kind, value = data[lookup]
        print("Type is " + kind if operation == "read-type" else (int(value) if kind == "boolean" else value))
    elif operation == "write":
        kind = {"-bool": "boolean", "-int": "integer", "-float": "float", "-string": "string"}[args[3]]
        value = {"boolean": lambda v: v == "true", "integer": int, "float": float, "string": str}[kind](args[4])
        data[lookup] = [kind, value]
        db.write_text(json.dumps(data))
    elif operation == "delete":
        del data[lookup]
        db.write_text(json.dumps(data))
    else:
        reject()
elif name == "curl":
    # Only scanner release fixtures are allowed; never download an installer.
    fixture = os.environ.get("TEST_DOWNLOADS")
    url = next(a for a in args if a.startswith("https://"))
    if not fixture or "/gitleaks/gitleaks/releases/" not in url:
        reject()
    shutil.copyfile(Path(fixture) / url.rsplit("/", 1)[-1], args[args.index("-o") + 1])
elif name == "gitleaks":
    if args[0] != "git" or "--redact" not in args:
        reject()
else:
    reject()
