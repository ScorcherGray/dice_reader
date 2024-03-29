// import 'package:google_sheets_create_example/model/user.dart';
import 'package:gsheets/gsheets.dart';
import 'package:dice_reader/model/user.dart';

class CharacterSheetsApi {
  static const _credentials = r'''
{
  "type": "service_account",
  "project_id": "character-bonus-reader",
  "private_key_id": "2280d19f899fa96b01e7aba43f4e6fb11c538b4c",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC7JYB4w5SOPQ7Z\ncy0CpBEIFcBJgw/88iVjNXi/MuJx746R37rSGLbeF5Lysn5pfKB7q0USMToKHuHR\nU73tfj9IkCGqoDqmPBVAWxD5ED1xg7+5bSFJCRd2SKyEYigPyVaGvE/1ySMZnuNk\nrLQmZUjiylXTgnIIOh2KjiQnI41kEz/nWW5RJOUR1UChGLs+/DIQFp+SOwn8mW4y\nx2jPTgqIUuvBBx71P1GbHANGGcUmoyD/Y/JYV22H4/33kAKVoYqxslQKtWdtMUPo\njtc6lGouZIC04QbYRutaY3V7kE77ZV4zvt7v52CiDSOB3NNbtFFpYCVH+6XoQWM3\nSdwjSlL7AgMBAAECggEAGQw6Zy9qHSV/7Mu1DQLvgqECpPQlOiogpegcup5xX2V8\nM/r5UrBbHVuTX+dS8wRqqFKygm5TQdKDT9SA+Z3pk2kzEFa0stYc1Am8OlGZn61O\nBl/cUh2k5cBxUqCekwpUCeF/ZDqg94dkEO/qhq8Ms8n39cCiSYaZuJcwsIpaHLgZ\nka+qtiHwBfczAX96Fqoxjr4X1VzpVstiBlyEPblF0JcVIENsS2tUc9mQL3KF4iiS\nTjv7d6bYhb3fH6xS56U2Mdue6AbdgahNsA/s1LEAsaGHDnA6MZVLYRnbyOhMvH41\nrB13wQmxUNKZU7C2+Zn14thUKdA5FFgwvPLQRXqc2QKBgQD+9Bk12KlXYvDpahUY\njixvwUc7dGFz8dYGStzbki2mCQ+5ZnIyVaBDzgOaL6ixobwOhg3NXFG5mDGfHwhe\n8AlMUGXotxvMwbZf54ro0YG+aeAMutJ7AjmkGckScKg3B+tgfDWNe+cL+r1UBhgU\ns4zvuKz8v5aDrsWA8i8MkUDiwwKBgQC76icYTK9/vECcexM7i5PKgsU3vc7iPTun\ntnXWEGKGj34Z5qQkj99D/kW4SDJgVHTEusqAOpJ1iQpELwH/M9OVEsfOulMmStLN\nOolbCQOSI5FgcCl3R9EoTePdUmEXl6GtrlbCG9Vq82aSHNd6GwtOOq6p3Sch4w7Y\nPZ3+L4ZbaQKBgHzFZyUUAGP01uPUd7iJs7OJilvNa/f7LXvs3UNTuaVdH+Xi/hYm\nE4W7Z8Xodw1fkpIlBtIu0QwcMISoAke7/0Dqw8Ts/9zoHGG5BiFEjtNqKyzvrRxo\nDV+DAwVUPu6XoJiakPbJ4VvafReG1/ghmuKipX4YIQgW2y9s1pu25mNTAoGARvXJ\nBZgPvcCs9WpUfOvcR2DScJYwhaZx3Ic+QDO3wPB2wfkiitv5h4eBdHFu9Ilv/so6\npel4XQH+6niF3IUJpQWOhjY+J/uhVvZ/3+yreIgN4cj5H53zEbE4Ft+A4pPT7e4j\nvPEdymFXnl1d0TJdNpFaW7KzkExZ0raR7uaraeECgYBh5qkdmbK2l/lbTSjNyzpR\nsS5qStRKo5IbHi40lJAgX8oob1yj16wxnVHrcpWxcLCjivLOPhN47T6tMxHAwCF5\nf1S++3crPvwWbeL7nnhKgq8Y3qM9sonKfGeMgWoJXTGBN9jNTIReff4AUqYyF+9S\nAajZt8fCf4Uh5JbpgIUG5g==\n-----END PRIVATE KEY-----\n",
  "client_email": "scorchercodeserviceaccount@character-bonus-reader.iam.gserviceaccount.com",
  "client_id": "114643552090025330566",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/scorchercodeserviceaccount%40character-bonus-reader.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}

''';
  static const _speadsheetId = '1agmrC7c6Vg78xthEPbQO6fkuuQdXtlzC4kcJYhIw91s';
  static final _gsheets = GSheets(_credentials);
  static Worksheet? _userSheet;

  static Future init() async {
    try{
      final spreadsheet = await _gsheets.spreadsheet(_speadsheetId);
      _userSheet = await _getWorkSheet(spreadsheet, title: 'Sheet1');

      final firstRow = UserFields.getFields();
      _userSheet!.values.insertRow(1, firstRow); //Row to insert, info inserted
    } catch (e) {
    print('Init Error: $e');
    }
  }

  static Future<Worksheet> _getWorkSheet(
    Spreadsheet spreadsheet, {
      required String title,
  }) async {
      try {
      return await spreadsheet.addWorksheet(title);
    } catch (e) {
      return spreadsheet.worksheetByTitle(title)!;
    }
  }  

}