#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch_android() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    text = manifest.read_text(encoding="utf-8")
    permissions = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.VIBRATE",
        "android.permission.SCHEDULE_EXACT_ALARM",
    ]
    insertion = "\n".join(
        f'    <uses-permission android:name="{permission}" />'
        for permission in permissions
        if permission not in text
    )
    if insertion:
        text, count = re.subn(
            r"(<manifest\b[^>]*>)",
            lambda match: match.group(1) + "\n" + insertion,
            text,
            count=1,
        )
        if count != 1:
            raise RuntimeError("Could not locate <manifest> root element")

    receivers = """
        <!-- Required by flutter_local_notifications for scheduled reminders. -->
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
"""
    if "ScheduledNotificationReceiver" not in text:
        text, count = re.subn(
            r"</application\s*>",
            receivers + "    </application>",
            text,
            count=1,
        )
        if count != 1:
            raise RuntimeError("Could not locate </application> element")
    manifest.write_text(text, encoding="utf-8")

    kotlin_target = ROOT / "android/app/src/main/kotlin/com/salahfocus/salah_focus/MainActivity.kt"
    kotlin_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "native/android/MainActivity.kt", kotlin_target)

    gradle = ROOT / "android/app/build.gradle.kts"
    if gradle.exists():
        g = gradle.read_text(encoding="utf-8")
        if "isCoreLibraryDesugaringEnabled" not in g:
            g = g.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        if "multiDexEnabled = true" not in g:
            g = g.replace("defaultConfig {", "defaultConfig {\n        multiDexEnabled = true", 1)
        if "coreLibraryDesugaring(" not in g:
            g += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        gradle.write_text(g, encoding="utf-8")

    keep = ROOT / "android/app/src/main/res/raw/keep.xml"
    keep.parent.mkdir(parents=True, exist_ok=True)
    keep.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools"\n'
        '    tools:keep="@mipmap/ic_launcher" />\n',
        encoding="utf-8",
    )


def patch_ios() -> None:
    shutil.copy2(ROOT / "native/ios/AppDelegate.swift", ROOT / "ios/Runner/AppDelegate.swift")

    info_path = ROOT / "ios/Runner/Info.plist"
    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleDisplayName"] = "Salaty"
    info["NSLocationWhenInUseUsageDescription"] = (
        "Salaty uses your location to calculate local prayer times and Qibla direction."
    )
    with info_path.open("wb") as handle:
        plistlib.dump(info, handle, sort_keys=False)

    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        p = podfile.read_text(encoding="utf-8")
        if re.search(r"platform :ios, ['\"]\d+\.\d+['\"]", p):
            p = re.sub(r"platform :ios, ['\"]\d+\.\d+['\"]", "platform :ios, '16.0'", p)
        else:
            p = "platform :ios, '16.0'\n" + p
        podfile.write_text(p, encoding="utf-8")

    project = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    if project.exists():
        p = project.read_text(encoding="utf-8")
        p = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 16.0;", p)
        project.write_text(p, encoding="utf-8")


if __name__ == "__main__":
    patch_android()
    patch_ios()
    print("Platform setup applied.")
