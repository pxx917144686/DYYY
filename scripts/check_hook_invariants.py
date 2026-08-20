#!/usr/bin/env python3
"""Fail when known multi-file Logos hook chains change unexpectedly."""

from __future__ import annotations

import collections
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"

EXPECTED_DUPLICATES = {
    ("AWEAwemePlayVideoViewController", "-", "setIsAutoPlay:"): 2,
    ("AWECommentContainerViewController", "-", "viewDidAppear:"): 2,
    ("AWECommentContainerViewController", "-", "viewDidDisappear:"): 4,
    ("AWECommentContainerViewController", "-", "viewDidLayoutSubviews"): 3,
    ("AWECommentContainerViewController", "-", "viewWillAppear:"): 4,
    ("AWECommentInputBackgroundView", "-", "didMoveToWindow"): 2,
    ("AWECommentInputBackgroundView", "-", "layoutSubviews"): 3,
    ("AWEDPlayerFeedPlayerViewController", "-", "adjustPlaybackSpeed:"): 2,
    ("AWEDPlayerFeedPlayerViewController", "-", "prepareForDisplay"): 2,
    ("AWEDPlayerFeedPlayerViewController", "-", "setIsAutoPlay:"): 2,
    ("AWEElementStackView", "-", "setAlpha:"): 2,
    ("AWEFeedVideoButton", "-", "layoutSubviews"): 2,
    ("AWEIMFeedVideoQuickReplayInputViewController", "-", "viewDidLayoutSubviews"): 2,
    ("AWEListKitMagicCollectionView", "-", "layoutSubviews"): 2,
    ("AWENormalModeTabBar", "-", "layoutSubviews"): 2,
    ("AWENormalModeTabBarBadgeContainerView", "-", "layoutSubviews"): 2,
    ("AWENormalModeTabBarTextView", "-", "layoutSubviews"): 2,
    ("AWEPlayInteractionViewController", "-", "onVideoPlayerViewDoubleClicked:"): 2,
    ("AWEPlayInteractionViewController", "-", "viewDidAppear:"): 3,
    ("AWEPlayInteractionViewController", "-", "viewDidDisappear:"): 2,
    ("AWEPlayInteractionViewController", "-", "viewDidLayoutSubviews"): 2,
    ("AWEPlayInteractionViewController", "-", "viewWillAppear:"): 2,
    ("UILabel", "-", "setText:"): 2,
    ("UIView", "-", "setBackgroundColor:"): 2,
}

DELAYED_LONG_PRESS_HOOKS = {
    "AWELongPressPanelManager",
    "AWELongPressPanelDataManager",
    "AWELongPressPanelABSettings",
    "AWEModernLongPressPanelUIConfig",
}


def selector_from_declaration(declaration: str) -> tuple[str, str] | None:
    match = re.match(r"^([+-])\s*\([^)]*\)\s*", declaration)
    if not match:
        return None
    kind = match.group(1)
    tail = declaration[match.end() :].split("{", 1)[0]
    labels = re.findall(r"([A-Za-z_]\w*)\s*:", tail)
    if labels:
        return kind, "".join(f"{label}:" for label in labels)
    name = re.match(r"([A-Za-z_]\w*)", tail)
    return (kind, name.group(1)) if name else None


def scan_hooks():
    methods = collections.defaultdict(list)
    hook_groups = collections.defaultdict(list)
    for path in sorted(SOURCES.rglob("*.xm")):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        stack: list[tuple[str, str]] = []
        index = 0
        while index < len(lines):
            stripped = lines[index].strip()
            group_match = re.match(r"%group\s+(\w+)", stripped)
            if group_match:
                stack.append(("group", group_match.group(1)))
                index += 1
                continue
            hook_match = re.match(r"%hook\s+(\w+)", stripped)
            if hook_match:
                class_name = hook_match.group(1)
                group = next((name for kind, name in reversed(stack) if kind == "group"), "_ungrouped")
                hook_groups[class_name].append((group, path.relative_to(ROOT), index + 1))
                stack.append(("hook", class_name))
                index += 1
                continue
            if stripped.startswith("%end"):
                if stack:
                    stack.pop()
                index += 1
                continue
            current_hook = next((name for kind, name in reversed(stack) if kind == "hook"), None)
            if current_hook and re.match(r"^[+-]\s*\(", stripped):
                declaration = stripped
                start_line = index + 1
                while "{" not in declaration and index + 1 < len(lines) and len(declaration) < 1000:
                    index += 1
                    declaration += " " + lines[index].strip()
                parsed = selector_from_declaration(declaration)
                if parsed:
                    kind, selector = parsed
                    methods[(current_hook, kind, selector)].append((path.relative_to(ROOT), start_line))
            index += 1
    return methods, hook_groups


def main() -> int:
    methods, hook_groups = scan_hooks()
    actual_duplicates = {key: len(locations) for key, locations in methods.items() if len(locations) > 1}
    errors = []
    if actual_duplicates != EXPECTED_DUPLICATES:
        for key in sorted(set(actual_duplicates) | set(EXPECTED_DUPLICATES)):
            actual = actual_duplicates.get(key, 0)
            expected = EXPECTED_DUPLICATES.get(key, 0)
            if actual != expected:
                errors.append(f"duplicate {key[0]} {key[1]}{key[2]}: expected {expected}, got {actual}")

    delayed_file = pathlib.Path("Sources/Hooks/DYYYLongPressPanelManagerHooks.xm")
    for class_name in sorted(DELAYED_LONG_PRESS_HOOKS):
        locations = hook_groups.get(class_name, [])
        if len(locations) != 1 or locations[0][0] != "needDelay" or locations[0][1] != delayed_file:
            errors.append(f"{class_name} must appear once in needDelay at {delayed_file}; got {locations}")

    if errors:
        print("Hook invariant check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Hook invariants OK: {len(EXPECTED_DUPLICATES)} duplicate chains allowlisted; 4 delayed hooks grouped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
