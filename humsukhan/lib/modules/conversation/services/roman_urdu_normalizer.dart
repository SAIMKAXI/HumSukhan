/// Conservative normalizer for the explicit Roman Urdu session mode.
/// It only converts Devanagari output to Latin; it never translates English or Urdu text.
class RomanUrduNormalizer {
  static const _map = <String,String>{'अ':'a','आ':'aa','इ':'i','ई':'ee','उ':'u','ऊ':'oo','ए':'e','ऐ':'ai','ओ':'o','औ':'au','क':'k','ख':'kh','ग':'g','घ':'gh','च':'ch','छ':'chh','ज':'j','झ':'jh','ट':'t','ठ':'th','ड':'d','ढ':'dh','त':'t','थ':'th','द':'d','ध':'dh','न':'n','प':'p','फ':'ph','ब':'b','भ':'bh','म':'m','य':'y','र':'r','ल':'l','व':'w','श':'sh','ष':'sh','स':'s','ह':'h','ा':'a','ि':'i','ी':'i','ु':'u','ू':'u','े':'e','ै':'ai','ो':'o','ौ':'au','ं':'n','ँ':'n','ः':'h','्':'','़':'','ृ':'ri',' ' :' '};
  static String normalize(String text) {
    if (!RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;
    final out=StringBuffer();
    for(final rune in text.runes){final ch=String.fromCharCode(rune);out.write(_map[ch]??ch);}
    return out.toString();
  }
}
