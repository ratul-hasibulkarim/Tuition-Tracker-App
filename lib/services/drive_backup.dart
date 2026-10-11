import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// OAuth "Web application" client ID from Google Cloud, required on Android.
/// Passed at build time: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// Saves one backup file in the user's Drive "appDataFolder": a hidden
/// folder only this app can see. It stays there after the app is uninstalled.
class DriveBackup {
  static const backupName = 'tuition_tracker_backup.zip';
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  final _signIn = GoogleSignIn.instance;
  bool _initialized = false;
  GoogleSignInAccount? account;

  Future<void> _init() async {
    if (_initialized) return;
    await _signIn.initialize(
      serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId,
    );
    _initialized = true;
  }

  /// Signs in again without showing UI if the user signed in before.
  Future<GoogleSignInAccount?> restoreSession() async {
    await _init();
    try {
      account = await _signIn.attemptLightweightAuthentication();
    } catch (_) {
      account = null;
    }
    return account;
  }

  Future<GoogleSignInAccount> signIn() async {
    await _init();
    account = await _signIn.authenticate(scopeHint: _scopes);
    await account!.authorizationClient.authorizeScopes(_scopes);
    return account!;
  }

  Future<void> signOut() async {
    await _init();
    await _signIn.disconnect();
    account = null;
  }

  /// [interactive] allows showing the consent screen if access was revoked.
  Future<drive.DriveApi> _api({bool interactive = true}) async {
    final acc = account;
    if (acc == null) throw StateError('Not signed in');
    final authz = await acc.authorizationClient.authorizationForScopes(_scopes) ??
        (interactive ? await acc.authorizationClient.authorizeScopes(_scopes) : null);
    if (authz == null) throw StateError('Drive access not granted');
    return drive.DriveApi(authz.authClient(scopes: _scopes));
  }

  Future<drive.File?> _find(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupName' and trashed = false",
      $fields: 'files(id, name, modifiedTime, size)',
      orderBy: 'modifiedTime desc',
    );
    final files = list.files ?? [];
    return files.isEmpty ? null : files.first;
  }

  /// When the backup on Drive was last saved, or null if there is none.
  Future<DateTime?> lastBackupTime() async {
    final f = await _find(await _api(interactive: false));
    return f?.modifiedTime?.toLocal();
  }

  Future<void> upload(List<int> bytes, {bool interactive = true}) async {
    final api = await _api(interactive: interactive);
    final media = drive.Media(Stream.value(bytes), bytes.length,
        contentType: 'application/zip');
    final existing = await _find(api);
    if (existing?.id != null) {
      await api.files.update(drive.File(), existing!.id!, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = backupName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
  }

  /// Returns the backup's bytes, or null if there is no backup yet.
  Future<List<int>?> download() async {
    final api = await _api();
    final f = await _find(api);
    if (f?.id == null) return null;
    final media = await api.files.get(
      f!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
