// Upstream: src/util/chars.ts

// Tests on UTF-16 code units, as the lexers read them with charCodeAt. Past the end of a string
// the code is -1 (NaN in JS), which is none of these.

/// Whitespace as `\s` sees it.
bool isSpace(int c) {
  if (c < 0) return false;
  if (c < 128) return c == 32 || (c >= 9 && c <= 13);
  return c == 0xa0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000 ||
      c == 0xfeff;
}

bool isBlank(int c) {
  return c == 32 || c == 9;
}

/// A line terminator: what `.` does not match.
bool isLineEnd(int c) {
  return c == 10 || c == 13 || c == 0x2028 || c == 0x2029;
}

bool isDigit(int c) {
  return c >= 48 && c <= 57;
}

bool isLetter(int c) {
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
}

bool isHex(int c) {
  return (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
}

/// A character of `\w`.
bool isWord(int c) {
  return (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95;
}
