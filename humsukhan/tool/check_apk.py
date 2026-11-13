#!/usr/bin/env python3
"""Checks that a release APK carries only what the app needs.

    python3 tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk

Fails, listing every problem, when the APK
- asks for a permission not on PERMISSIONS,
- is debuggable, allows cleartext traffic or allows Android backup,
- exposes a component to other apps that is not on EXPOSED and not guarded
  by a permission,
- contains a file outside the expected set (such as a key, an env file,
  source code or an unexpected asset), or build metadata nothing on the
  phone reads,
- contains a secret: anything shaped like an API key or private key, or a
  Supabase key other than the public anon key.

Adding a permission, an exposed component or an asset is fine when it is
needed: add it here too, so the change is reviewed rather than slipped in by
a plugin update.
"""

import base64
import json
import re
import struct
import sys
import zipfile

# Every permission the app needs, and why.
PERMISSIONS = {
    'android.permission.RECORD_AUDIO',  # captions and sound alerts
    'android.permission.INTERNET',  # Supabase and cloud speech
    'android.permission.ACCESS_NETWORK_STATE',  # online/offline indicator
    'android.permission.VIBRATE',  # alert vibration
    'android.permission.FOREGROUND_SERVICE',  # sound alerts with the app closed
    'android.permission.FOREGROUND_SERVICE_MICROPHONE',
    'android.permission.POST_NOTIFICATIONS',  # alert and reminder notifications
    'android.permission.RECEIVE_BOOT_COMPLETED',  # reminders survive a restart
    # Declared by AndroidX for its own unexported receivers.
    'com.humsukhan.humsukhan.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}

# Components other apps may start without holding a permission.
EXPOSED = {
    'com.humsukhan.humsukhan.MainActivity',  # the launcher and the sign-in link
}

# Files the APK may contain, as patterns over their paths.
ALLOWED_FILES = [
    r'AndroidManifest\.xml',
    r'classes\d*\.dex',
    r'resources\.arsc',
    r'res/.+',
    r'lib/(arm64-v8a|armeabi-v7a)/lib[\w.-]+\.so',
    r'META-INF/(MANIFEST\.MF|[\w.-]+\.(SF|RSA|EC|DSA))',
    r'META-INF/services/[\w.$-]+',
    r'META-INF/(com/android/build/gradle/app-metadata\.properties|androidx|com)/.+',
    r'META-INF/[\w.-]+\.kotlin_module',
    r'kotlin/.+\.kotlin_builtins',
    r'assets/dexopt/baseline\.profm?',
    r'assets/flutter_assets/(AssetManifest\.bin|AssetManifest\.json|FontManifest\.json|NOTICES\.Z|NativeAssetsManifest\.json)',
    r'assets/flutter_assets/assets/(logo|icon_mark)\.webp',
    r'assets/flutter_assets/assets/environmental/(model\.int8\.onnx|class_labels_indices\.csv)',
    r'assets/flutter_assets/fonts/(MaterialIcons-Regular\.otf|noto_sans/Noto(Sans|NastaliqUrdu)-(Regular|Bold)\.ttf)',
    r'assets/flutter_assets/shaders/[\w.-]+\.frag',
    # The recorder plugin ships its web worker in every app; it is never run
    # on Android, and Flutter cannot leave one platform's package assets out.
    r'assets/flutter_assets/packages/record_web/assets/js/[\w.-]+\.js',
]

# Files that must never be present, whatever ALLOWED_FILES says.
FORBIDDEN_FILES = [
    r'(^|/)\.env', r'\.(jks|keystore|p12|pem|key)$', r'key\.properties$',
    r'google-services\.json$', r'\.dart$', r'(^|/)test/', r'\.map$',
    r'META-INF/[\w.-]+\.version$', r'version-control-info\.textproto$',
    r'DebugProbesKt\.bin$', r'kotlin-tooling-metadata\.json$',
]

SECRETS = {
    'API key (sk-)': rb'sk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}',
    'Google API key': rb'AIza[0-9A-Za-z_-]{35}',
    'Supabase secret key': rb'sb_secret_[A-Za-z0-9_-]{10,}',
    'GitHub token': rb'(?:ghp|gho|ghs|ghu)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}',
    'AWS key': rb'AKIA[0-9A-Z]{16}',
    'Hugging Face token': rb'hf_[A-Za-z0-9]{30,}',
    'private key': rb'-----BEGIN [A-Z ]*PRIVATE KEY-----',
}
JWT = rb'eyJ[A-Za-z0-9_-]{10,}\.(eyJ[A-Za-z0-9_-]{10,})\.[A-Za-z0-9_-]{10,}'

ANDROID_NS = 'http://schemas.android.com/apk/res/android'


def read_manifest(data):
    """Decodes Android's binary XML into (tag, {attribute: value}) pairs."""
    strings, elements, pos = [], [], 8
    u16 = lambda o: struct.unpack_from('<H', data, o)[0]
    u32 = lambda o: struct.unpack_from('<I', data, o)[0]
    while pos < len(data):
        kind, header, size = struct.unpack_from('<HHI', data, pos)
        if kind == 0x0001:  # string pool
            count, flags, start = u32(pos + 8), u32(pos + 16), u32(pos + 20)
            utf8 = flags & (1 << 8)
            for i in range(count):
                p = pos + start + u32(pos + 28 + i * 4)
                if utf8:
                    p += 2 if data[p] & 0x80 else 1
                    n = data[p]
                    p += 1
                    if n & 0x80:
                        n = ((n & 0x7F) << 8) | data[p]
                        p += 1
                    strings.append(data[p:p + n].decode('utf-8', 'replace'))
                else:
                    n = u16(p)
                    p += 2
                    if n & 0x8000:
                        n = ((n & 0x7FFF) << 16) | u16(p)
                        p += 2
                    strings.append(data[p:p + n * 2].decode('utf-16-le', 'replace'))
        elif kind == 0x0102:  # element start
            attributes = {}
            first = pos + header + u16(pos + 24)
            for i in range(u16(pos + 28)):
                a = first + i * 20
                name = strings[u32(a + 4)]
                raw, value_type, value = u32(a + 8), data[a + 15], u32(a + 16)
                if raw != 0xFFFFFFFF:
                    attributes[name] = strings[raw]
                elif value_type == 0x12:
                    attributes[name] = 'true' if value else 'false'
                else:
                    attributes[name] = str(value)
            elements.append((strings[u32(pos + 20)], attributes))
        pos += size
    return elements


def check_manifest(elements):
    problems = []
    for tag, attributes in elements:
        if tag == 'uses-permission' and attributes.get('name') not in PERMISSIONS:
            problems.append(f'unexpected permission: {attributes.get("name")}')
        if tag == 'application':
            if attributes.get('debuggable') == 'true':
                problems.append('the app is debuggable')
            if attributes.get('usesCleartextTraffic') == 'true':
                problems.append('the app allows unencrypted (cleartext) traffic')
            if attributes.get('testOnly') == 'true':
                problems.append('the app is marked test-only')
            if attributes.get('allowBackup') != 'false':
                problems.append('Android backup is allowed (set android:allowBackup="false")')
            if 'dataExtractionRules' not in attributes:
                problems.append('no data extraction rules: Android 12+ would still transfer app data to a new phone')
        if tag in ('activity', 'activity-alias', 'service', 'receiver', 'provider'):
            name = attributes.get('name')
            if attributes.get('exported') == 'true' and 'permission' not in attributes and name not in EXPOSED:
                problems.append(f'{tag} {name} is open to every app')
    return problems


def check_files(names):
    problems = []
    for name in names:
        if name.endswith('/'):
            continue
        if any(re.search(p, name) for p in FORBIDDEN_FILES):
            problems.append(f'forbidden file: {name}')
        elif not any(re.fullmatch(p, name) for p in ALLOWED_FILES):
            problems.append(f'unexpected file: {name}')
    return problems


def check_secrets(apk):
    problems = []
    for info in apk.infolist():
        if info.is_dir() or info.file_size > 64 * 1024 * 1024:
            continue
        data = apk.read(info)
        for label, pattern in SECRETS.items():
            for match in re.finditer(pattern, data):
                problems.append(f'{label} in {info.filename}: {match.group(0)[:12].decode(errors="replace")}...')
        for match in re.finditer(JWT, data):
            payload = match.group(1) + b'=' * (-len(match.group(1)) % 4)
            try:
                role = json.loads(base64.urlsafe_b64decode(payload)).get('role')
            except ValueError:
                role = None
            if role != 'anon':
                problems.append(f'a token with role {role!r} in {info.filename} (only the public anon key belongs in the app)')
    return problems


def main(path):
    with zipfile.ZipFile(path) as apk:
        problems = (
            check_manifest(read_manifest(apk.read('AndroidManifest.xml')))
            + check_files(apk.namelist())
            + check_secrets(apk)
        )
    for problem in problems:
        print(f'::error::{problem}')
    if problems:
        print(f'{len(problems)} problem(s) in {path}')
        return 1
    print(f'{path}: permissions, flags, exposed components, files and secrets as expected')
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
