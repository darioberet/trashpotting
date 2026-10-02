import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Tutte le icone dell'app, da un unico set (Phosphor, stile "regular";
/// "fill" per gli stati selezionati/attivi). Usare sempre queste invece di
/// `Icons.*`, così lo stile resta coerente e si cambia da un solo punto.
abstract final class AppIcons {
  // ── Navigazione ──────────────────────────────────────────────────────────
  static const IconData map = PhosphorIconsRegular.mapTrifold;
  static const IconData mapActive = PhosphorIconsFill.mapTrifold;
  static const IconData leaderboard = PhosphorIconsRegular.trophy;
  static const IconData leaderboardActive = PhosphorIconsFill.trophy;
  static const IconData profile = PhosphorIconsRegular.user;
  static const IconData profileActive = PhosphorIconsFill.user;
  static const IconData report = PhosphorIconsFill.mapPinPlus;
  static const IconData notifications = PhosphorIconsRegular.bell;
  static const IconData notificationsOff = PhosphorIconsRegular.bellSlash;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData dropdown = PhosphorIconsRegular.caretDown;
  static const IconData openExternal = PhosphorIconsRegular.arrowSquareOut;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData share = PhosphorIconsRegular.export;

  // ── Utente e account ─────────────────────────────────────────────────────
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData userFilled = PhosphorIconsFill.user;
  static const IconData userAdd = PhosphorIconsRegular.userPlus;
  static const IconData users = PhosphorIconsRegular.users;
  static const IconData usersGroup = PhosphorIconsRegular.usersThree;
  static const IconData email = PhosphorIconsRegular.envelopeSimple;
  static const IconData emailUnread = PhosphorIconsRegular.envelopeSimpleOpen;
  static const IconData lock = PhosphorIconsRegular.lock;
  static const IconData username = PhosphorIconsRegular.at;
  static const IconData visible = PhosphorIconsRegular.eye;
  static const IconData hidden = PhosphorIconsRegular.eyeSlash;
  static const IconData verified = PhosphorIconsFill.sealCheck;
  static const IconData logout = PhosphorIconsRegular.signOut;
  static const IconData delete = PhosphorIconsRegular.trash;

  // ── Segnalazioni e mappa ─────────────────────────────────────────────────
  static const IconData place = PhosphorIconsRegular.mapPin;
  static const IconData addPlace = PhosphorIconsRegular.mapPinPlus;
  static const IconData myLocation = PhosphorIconsRegular.crosshair;
  static const IconData nearMe = PhosphorIconsRegular.navigationArrow;
  static const IconData locationOff = PhosphorIconsRegular.mapPinLine;
  static const IconData radius = PhosphorIconsRegular.target;
  static const IconData filter = PhosphorIconsRegular.funnelSimple;
  static const IconData wasteType = PhosphorIconsRegular.leaf;
  static const IconData leaf = PhosphorIconsFill.leaf;
  static const IconData camera = PhosphorIconsRegular.camera;
  static const IconData cameraFilled = PhosphorIconsFill.camera;
  static const IconData gallery = PhosphorIconsRegular.images;
  static const IconData image = PhosphorIconsRegular.image;
  static const IconData imageBroken = PhosphorIconsRegular.imageBroken;
  static const IconData send = PhosphorIconsRegular.paperPlaneTilt;
  static const IconData upload = PhosphorIconsRegular.cloudArrowUp;
  static const IconData myReports = PhosphorIconsRegular.clipboardText;
  static const IconData landscape = PhosphorIconsRegular.mountains;

  // ── Stati ────────────────────────────────────────────────────────────────
  static const IconData statusReported = PhosphorIconsRegular.warning;
  static const IconData statusOpen = PhosphorIconsRegular.clock;
  static const IconData statusInProgress = PhosphorIconsRegular.broom;
  static const IconData statusEvent = PhosphorIconsRegular.calendarBlank;
  static const IconData statusCleaned = PhosphorIconsRegular.checkCircle;
  static const IconData statusCleanedFilled = PhosphorIconsFill.checkCircle;
  static const IconData statusGone = PhosphorIconsRegular.question;
  static const IconData clean = PhosphorIconsRegular.broom;
  static const IconData tools = PhosphorIconsRegular.wrench;
  static const IconData calendar = PhosphorIconsRegular.calendarBlank;
  static const IconData time = PhosphorIconsRegular.clock;
  static const IconData start = PhosphorIconsRegular.play;
  static const IconData joinGroup = PhosphorIconsRegular.userPlus;
  static const IconData vote = PhosphorIconsRegular.handPointing;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData dot = PhosphorIconsFill.circle;
  static const IconData circle = PhosphorIconsRegular.circle;
  static const IconData radioOn = PhosphorIconsFill.radioButton;
  static const IconData radioOff = PhosphorIconsRegular.circle;

  // ── Tipi di rifiuto (marker e dettaglio) ─────────────────────────────────
  static const IconData wasteDump = PhosphorIconsFill.trash;
  static const IconData wasteAbandoned = PhosphorIconsFill.bagSimple;
  static const IconData wasteHazardous = PhosphorIconsFill.biohazard;
  static const IconData wasteUnknown = PhosphorIconsFill.trashSimple;

  /// Icona del tipo scelto in Segnala (`segnala_screen.dart`, `_types`).
  static IconData forWasteType(String? type) => switch (type) {
    'Discarica abusiva' => wasteDump,
    'Rifiuti abbandonati' => wasteAbandoned,
    'Rifiuti pericolosi' => wasteHazardous,
    _ => wasteUnknown,
  };

  // Marker degli stati in cui il tipo conta meno dell'avanzamento.
  static const IconData markerEvent = PhosphorIconsFill.calendarBlank;
  static const IconData markerCleaning = PhosphorIconsFill.broom;
  static const IconData markerCleaned = PhosphorIconsFill.checkCircle;
  static const IconData markerGone = PhosphorIconsFill.question;

  // ── Classifica ───────────────────────────────────────────────────────────
  static const IconData trophy = PhosphorIconsRegular.trophy;
  static const IconData star = PhosphorIconsRegular.star;

  // ── Moderazione ──────────────────────────────────────────────────────────
  static const IconData flag = PhosphorIconsRegular.flag;
  static const IconData flagFilled = PhosphorIconsFill.flag;
  static const IconData block = PhosphorIconsRegular.prohibit;
  static const IconData shield = PhosphorIconsRegular.shield;
  static const IconData shieldOk = PhosphorIconsRegular.shieldCheck;
  static const IconData restore = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData refresh = PhosphorIconsRegular.arrowClockwise;

  // ── Impostazioni e aiuto ─────────────────────────────────────────────────
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData help = PhosphorIconsRegular.question;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData themeLight = PhosphorIconsRegular.sun;
  static const IconData themeDark = PhosphorIconsRegular.moon;
  static const IconData themeAuto = PhosphorIconsRegular.circleHalf;
  static const IconData tune = PhosphorIconsRegular.faders;

  // ── Errori ───────────────────────────────────────────────────────────────
  static const IconData offline = PhosphorIconsRegular.cloudSlash;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData linkBroken = PhosphorIconsRegular.linkBreak;
}
