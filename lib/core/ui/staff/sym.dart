import 'package:flutter/widgets.dart';

/// Material Symbols Rounded (font `MaterialSymbolsRounded`, trục FILL 0-1) - bộ icon của thiết kế staff.
/// Tên giữ đúng tên icon trong file Claude Design (snake_case -> camelCase).
///
/// Thêm icon mới: tra codepoint ở https://fonts.google.com/icons (mục "Code point"),
/// rồi thêm 1 dòng `static const tenIcon = IconData(0x..., fontFamily: _f);`.
/// Dùng: `Icon(Sym.calendarMonth, size: 24, fill: 1)` (fill 0 = viền, 1 = đặc).
class Sym {
  Sym._();
  static const _f = 'MaterialSymbolsRounded';

  static const accountCircle = IconData(0xe853, fontFamily: _f); // account_circle
  static const add = IconData(0xe145, fontFamily: _f); // add
  static const arrowBack = IconData(0xe5c4, fontFamily: _f); // arrow_back
  static const assignmentTurnedIn = IconData(0xe862, fontFamily: _f); // assignment_turned_in
  static const badge = IconData(0xea67, fontFamily: _f); // badge
  static const calendarMonth = IconData(0xebcc, fontFamily: _f); // calendar_month
  static const cancel = IconData(0xe5c9, fontFamily: _f); // cancel
  static const chat = IconData(0xe0b7, fontFamily: _f); // chat
  static const check = IconData(0xe5ca, fontFamily: _f); // check
  static const checkBox = IconData(0xe834, fontFamily: _f); // check_box
  static const checkBoxOutlineBlank = IconData(0xe835, fontFamily: _f); // check_box_outline_blank
  static const checkCircle = IconData(0xe86c, fontFamily: _f); // check_circle
  static const chevronRight = IconData(0xe409, fontFamily: _f); // chevron_right
  static const close = IconData(0xe14c, fontFamily: _f); // close
  static const coPresent = IconData(0xeaf0, fontFamily: _f); // co_present
  static const contentCopy = IconData(0xe14d, fontFamily: _f); // content_copy
  static const dateRange = IconData(0xe916, fontFamily: _f); // date_range
  static const description = IconData(0xe873, fontFamily: _f); // description
  static const devices = IconData(0xe1b1, fontFamily: _f); // devices
  static const edit = IconData(0xe150, fontFamily: _f); // edit
  static const editNote = IconData(0xe745, fontFamily: _f); // edit_note
  static const error = IconData(0xe000, fontFamily: _f); // error
  static const eventAvailable = IconData(0xe614, fontFamily: _f); // event_available
  static const eventBusy = IconData(0xe615, fontFamily: _f); // event_busy
  static const eventNote = IconData(0xe616, fontFamily: _f); // event_note
  static const eventRepeat = IconData(0xeb7b, fontFamily: _f); // event_repeat
  static const factCheck = IconData(0xf0c5, fontFamily: _f); // fact_check
  static const folderOpen = IconData(0xe2c8, fontFamily: _f); // folder_open
  static const groups = IconData(0xf233, fontFamily: _f); // groups
  static const history = IconData(0xe28e, fontFamily: _f); // history
  static const image = IconData(0xe251, fontFamily: _f); // image
  static const info = IconData(0xe88e, fontFamily: _f); // info
  static const link = IconData(0xe157, fontFamily: _f); // link
  static const locationOn = IconData(0xe0c8, fontFamily: _f); // location_on
  static const lock = IconData(0xe88d, fontFamily: _f); // lock
  static const lockOpen = IconData(0xe898, fontFamily: _f); // lock_open
  static const logout = IconData(0xe9ba, fontFamily: _f); // logout
  static const mail = IconData(0xe0be, fontFamily: _f); // mail
  static const meetingRoom = IconData(0xeb4f, fontFamily: _f); // meeting_room
  static const menuBook = IconData(0xea19, fontFamily: _f); // menu_book
  static const monitoring = IconData(0xf190, fontFamily: _f); // monitoring
  static const movie = IconData(0xe02c, fontFamily: _f); // movie
  static const notes = IconData(0xe26c, fontFamily: _f); // notes
  static const notifications = IconData(0xe7f4, fontFamily: _f); // notifications
  static const payments = IconData(0xef63, fontFamily: _f); // payments
  static const pendingActions = IconData(0xf1bb, fontFamily: _f); // pending_actions
  static const person = IconData(0xe7fd, fontFamily: _f); // person
  static const playArrow = IconData(0xe037, fontFamily: _f); // play_arrow
  static const public = IconData(0xe80b, fontFamily: _f); // public
  static const publicOff = IconData(0xf1ca, fontFamily: _f); // public_off
  static const radioButtonChecked = IconData(0xe837, fontFamily: _f); // radio_button_checked
  static const radioButtonUnchecked = IconData(0xe836, fontFamily: _f); // radio_button_unchecked
  static const rateReview = IconData(0xe560, fontFamily: _f); // rate_review
  static const receiptLong = IconData(0xef6e, fontFamily: _f); // receipt_long
  static const refresh = IconData(0xe5d5, fontFamily: _f); // refresh
  static const schedule = IconData(0xe192, fontFamily: _f); // schedule
  static const school = IconData(0xe80c, fontFamily: _f); // school
  static const search = IconData(0xe8b6, fontFamily: _f); // search
  static const send = IconData(0xe163, fontFamily: _f); // send
  static const star = IconData(0xe838, fontFamily: _f); // star
  static const swapHoriz = IconData(0xe8d4, fontFamily: _f); // swap_horiz
  static const swapVert = IconData(0xe0c3, fontFamily: _f); // swap_vert
  static const sync = IconData(0xe627, fontFamily: _f); // sync
  static const taskAlt = IconData(0xe2e6, fontFamily: _f); // task_alt
  static const tune = IconData(0xe429, fontFamily: _f); // tune
  static const upload = IconData(0xe2c6, fontFamily: _f); // upload
  static const uploadFile = IconData(0xe9fc, fontFamily: _f); // upload_file
  static const videocam = IconData(0xe04b, fontFamily: _f); // videocam
  static const visibility = IconData(0xe417, fontFamily: _f); // visibility
  static const visibilityOff = IconData(0xe8f5, fontFamily: _f); // visibility_off
}
