from pathlib import Path
import tempfile, plistlib, xml.etree.ElementTree as ET, importlib.util, shutil
src=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('aps', src/'tool/apply_platform_setup.py')
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as d:
    r=Path(d)
    # fake source structure used by patch script
    shutil.copytree(src/'native', r/'native')
    (r/'android/app/src/main').mkdir(parents=True)
    (r/'android/app/src/main/AndroidManifest.xml').write_text('<?xml version="1.0" encoding="utf-8"?>\n<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="salah_focus"></application></manifest>')
    (r/'android/app').mkdir(parents=True, exist_ok=True)
    (r/'android/app/build.gradle.kts').write_text('''android {\n  compileOptions {\n  }\n  defaultConfig {\n  }\n}\n''')
    (r/'ios/Runner').mkdir(parents=True)
    with (r/'ios/Runner/Info.plist').open('wb') as h:
        plistlib.dump({'CFBundleDisplayName':'salah_focus'}, h)
    (r/'ios/Runner/AppDelegate.swift').write_text('// template')
    (r/'ios/Podfile').write_text("platform :ios, '13.0'\n")
    (r/'ios/Runner.xcodeproj').mkdir(parents=True)
    (r/'ios/Runner.xcodeproj/project.pbxproj').write_text('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')
    mod.ROOT=r
    mod.patch_android(); mod.patch_ios()

    manifest=r/'android/app/src/main/AndroidManifest.xml'
    ET.parse(manifest)
    txt=manifest.read_text()
    assert txt.index('<manifest') < txt.index('<uses-permission') < txt.index('<application')
    for token in ['POST_NOTIFICATIONS','SCHEDULE_EXACT_ALARM','ScheduledNotificationReceiver','ScheduledNotificationBootReceiver']:
        assert token in txt, token
    gradle=(r/'android/app/build.gradle.kts').read_text()
    assert 'isCoreLibraryDesugaringEnabled = true' in gradle
    assert 'desugar_jdk_libs:2.1.4' in gradle
    assert (r/'android/app/src/main/res/raw/keep.xml').is_file()
    assert (r/'android/app/src/main/kotlin/com/salahfocus/salah_focus/MainActivity.kt').is_file()

    with (r/'ios/Runner/Info.plist').open('rb') as h:
        info=plistlib.load(h)
    assert info['CFBundleDisplayName']=='SalahFocus'
    assert 'NSLocationWhenInUseUsageDescription' in info
    assert "platform :ios, '16.0'" in (r/'ios/Podfile').read_text()
    assert 'IPHONEOS_DEPLOYMENT_TARGET = 16.0;' in (r/'ios/Runner.xcodeproj/project.pbxproj').read_text()
    assert 'PrayerFocusBridge' in (r/'ios/Runner/AppDelegate.swift').read_text()
print('Platform patch smoke test passed')
