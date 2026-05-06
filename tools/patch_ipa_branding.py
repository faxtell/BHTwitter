#!/usr/bin/env python3
"""
Patch an already-decrypted Twitter/X IPA to look closer to classic Twitter.

What this can do:
- Change the home-screen display name to Twitter.
- Add loose PNG app icon files and point Info.plist to them.
- Optionally compile and set a custom launch storyboard when Xcode/ibtool is available.

What this intentionally does not do:
- It does not include or download Twitter-owned logo artwork.
- It does not sign the IPA. Sign it afterwards with Feather, Sideloadly, ESign, AltStore, etc.

Example:
  python3 tools/patch_ipa_branding.py \
    --input packages/com.atebits.Tweetie2.ipa \
    --output packages/Twitter-branded.ipa \
    --display-name Twitter \
    --icon /path/to/your/icon.png \
    --launch-logo /path/to/your/launch-logo.png
"""

from __future__ import annotations

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Iterable


IPHONE_ICON_SIZES = {
    "TwitterPatchedIcon20x20": [40, 60],
    "TwitterPatchedIcon29x29": [58, 87],
    "TwitterPatchedIcon40x40": [80, 120],
    "TwitterPatchedIcon60x60": [120, 180],
}

IPAD_ICON_SIZES = {
    "TwitterPatchedIcon20x20": [20, 40],
    "TwitterPatchedIcon29x29": [29, 58],
    "TwitterPatchedIcon40x40": [40, 80],
    "TwitterPatchedIcon76x76": [76, 152],
    "TwitterPatchedIcon83.5x83.5": [167],
}


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def require_file(path: Path, label: str) -> None:
    if not path.exists() or not path.is_file():
        raise SystemExit(f"{label} not found: {path}")


def require_tool(name: str) -> str | None:
    return shutil.which(name)


def unzip_ipa(input_ipa: Path, workdir: Path) -> None:
    with zipfile.ZipFile(input_ipa, "r") as zf:
        zf.extractall(workdir)


def zip_ipa(workdir: Path, output_ipa: Path) -> None:
    if output_ipa.exists():
        output_ipa.unlink()
    with zipfile.ZipFile(output_ipa, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(workdir.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(workdir))


def find_app_bundle(workdir: Path) -> Path:
    payload = workdir / "Payload"
    if not payload.exists():
        raise SystemExit("Invalid IPA: Payload directory was not found")

    apps = [p for p in payload.iterdir() if p.suffix == ".app" and p.is_dir()]
    if not apps:
        raise SystemExit("Invalid IPA: .app bundle was not found inside Payload")
    if len(apps) > 1:
        print(f"[warn] Multiple .app bundles found. Using: {apps[0].name}")
    return apps[0]


def load_info_plist(app_dir: Path) -> tuple[Path, dict]:
    info_path = app_dir / "Info.plist"
    require_file(info_path, "Info.plist")
    with info_path.open("rb") as f:
        info = plistlib.load(f)
    return info_path, info


def save_info_plist(info_path: Path, info: dict) -> None:
    with info_path.open("wb") as f:
        plistlib.dump(info, f, sort_keys=False)


def resize_png_with_sips(source: Path, dest: Path, pixels: int) -> None:
    sips = require_tool("sips")
    if not sips:
        raise SystemExit("sips was not found. Run this script on macOS, or pre-create icon PNGs manually.")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
    run([sips, "-z", str(pixels), str(pixels), str(dest)])


def make_icon_files(app_dir: Path, icon_path: Path) -> None:
    print("[info] Writing loose icon PNGs")

    for base, sizes in IPHONE_ICON_SIZES.items():
        for pixels in sizes:
            scale = "@3x" if pixels % 3 == 0 and pixels // 3 in (20, 29, 40, 60) else "@2x"
            if pixels in (20, 29, 40, 76):
                scale = ""
            out = app_dir / f"{base}{scale}.png"
            resize_png_with_sips(icon_path, out, pixels)

    for base, sizes in IPAD_ICON_SIZES.items():
        for pixels in sizes:
            if pixels in (20, 29, 40, 76):
                suffix = "~ipad"
            elif pixels == 167:
                suffix = "@2x~ipad"
            else:
                suffix = "@2x~ipad"
            out = app_dir / f"{base}{suffix}.png"
            resize_png_with_sips(icon_path, out, pixels)


def patch_icon_plist(info: dict) -> None:
    iphone_icon_files = list(IPHONE_ICON_SIZES.keys())
    ipad_icon_files = list(IPAD_ICON_SIZES.keys())

    info["CFBundleIcons"] = {
        "CFBundlePrimaryIcon": {
            "CFBundleIconFiles": iphone_icon_files,
            "UIPrerenderedIcon": False,
        }
    }

    info["CFBundleIcons~ipad"] = {
        "CFBundlePrimaryIcon": {
            "CFBundleIconFiles": ipad_icon_files,
            "UIPrerenderedIcon": False,
        }
    }

    # Remove asset-catalog icon name so iOS is more likely to use the loose PNG names above.
    info["CFBundleIcons"]["CFBundlePrimaryIcon"].pop("CFBundleIconName", None)
    info["CFBundleIcons~ipad"]["CFBundlePrimaryIcon"].pop("CFBundleIconName", None)


def write_launch_storyboard_source(temp_dir: Path) -> Path:
    storyboard = temp_dir / "TwitterLaunchScreen.storyboard"
    storyboard.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="23504" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="23506"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView clipsSubviews="YES" userInteractionEnabled="NO" contentMode="scaleAspectFit" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="TwitterLaunchLogo" translatesAutoresizingMaskIntoConstraints="NO" id="logo-view">
                                <rect key="frame" x="76.5" y="376" width="240" height="100"/>
                                <constraints>
                                    <constraint firstAttribute="width" constant="240" id="logo-width"/>
                                    <constraint firstAttribute="height" constant="100" id="logo-height"/>
                                </constraints>
                            </imageView>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" red="0.1137254902" green="0.631372549" blue="0.9490196078" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="logo-view" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="center-x"/>
                            <constraint firstItem="logo-view" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="center-y"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="TwitterLaunchLogo" width="240" height="100"/>
    </resources>
</document>
""",
        encoding="utf-8",
    )
    return storyboard


def patch_launch_screen(app_dir: Path, info: dict, launch_logo: Path) -> bool:
    ibtool = require_tool("ibtool")
    if not ibtool:
        print("[warn] ibtool was not found. Skipping real LaunchScreen patch; runtime splash from the deb will still work.")
        return False

    launch_logo_dest = app_dir / "TwitterLaunchLogo.png"
    shutil.copy2(launch_logo, launch_logo_dest)

    with tempfile.TemporaryDirectory(prefix="twitter-launch-") as td:
        temp_dir = Path(td)
        storyboard = write_launch_storyboard_source(temp_dir)
        out_dir = app_dir / "TwitterLaunchScreen.storyboardc"
        if out_dir.exists():
            shutil.rmtree(out_dir)
        run([ibtool, "--compile", str(out_dir), str(storyboard)])

    info["UILaunchStoryboardName"] = "TwitterLaunchScreen"
    print("[info] Patched UILaunchStoryboardName=TwitterLaunchScreen")
    return True


def remove_code_signature(app_dir: Path) -> None:
    signature = app_dir / "_CodeSignature"
    if signature.exists():
        shutil.rmtree(signature)
    embedded = app_dir / "embedded.mobileprovision"
    if embedded.exists():
        embedded.unlink()


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser(description="Patch a Twitter/X IPA branding as much as possible before signing.")
    parser.add_argument("--input", required=True, type=Path, help="Input decrypted IPA")
    parser.add_argument("--output", required=True, type=Path, help="Output patched IPA")
    parser.add_argument("--display-name", default="Twitter", help="Home-screen display name")
    parser.add_argument("--icon", type=Path, help="Square PNG icon to use for home-screen app icon")
    parser.add_argument("--launch-logo", type=Path, help="Transparent PNG logo for the launch screen")
    parser.add_argument("--keep-signature", action="store_true", help="Do not remove old signature files")
    args = parser.parse_args(list(argv))

    require_file(args.input, "Input IPA")
    if args.icon:
        require_file(args.icon, "Icon PNG")
    if args.launch_logo:
        require_file(args.launch_logo, "Launch logo PNG")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="twitter-ipa-") as td:
        workdir = Path(td)
        unzip_ipa(args.input, workdir)
        app_dir = find_app_bundle(workdir)
        info_path, info = load_info_plist(app_dir)

        print(f"[info] App bundle: {app_dir.name}")
        info["CFBundleDisplayName"] = args.display_name
        info["CFBundleName"] = args.display_name

        if args.icon:
            make_icon_files(app_dir, args.icon)
            patch_icon_plist(info)
        else:
            print("[warn] --icon was not provided. Home-screen icon files were not changed.")

        if args.launch_logo:
            patch_launch_screen(app_dir, info, args.launch_logo)
        else:
            print("[warn] --launch-logo was not provided. Real LaunchScreen was not changed.")

        save_info_plist(info_path, info)

        if not args.keep_signature:
            remove_code_signature(app_dir)

        zip_ipa(workdir, args.output)

    print(f"[done] Wrote patched IPA: {args.output}")
    print("[next] Sign/install the IPA with your usual sideloading tool.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
