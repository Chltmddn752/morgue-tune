import 'package:flutter_test/flutter_test.dart';
import 'package:mornye/utils/file_access.dart';

void main() {
  test('iCloud stub sits next to the file as a hidden .icloud file', () {
    expect(
      iCloudPlaceholderPath('/Mobile Documents/Music/Album/Song.flac'),
      '/Mobile Documents/Music/Album/.Song.flac.icloud',
    );
    expect(iCloudPlaceholderPath('Song.flac'), '.Song.flac.icloud');
  });
}
