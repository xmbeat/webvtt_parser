
class Cue{
  String? id;
  late TimeRange timeRange;
  late String text;

  Cue.fromString(String str){
    var parts = str.split('\n');
    TimeRange? timeRange;
    String text = '';
    for (int i = 0; i < parts.length; i++) {
      if (i == 0){
        timeRange = tryParseTimeRange(parts[i]);
        if (timeRange == null){
          id = parts[i];
        }
        else{
          this.timeRange = timeRange;
        }
      }
      else if (i == 1 && timeRange == null){
        timeRange = tryParseTimeRange(parts[i]);
        if (timeRange == null){
          throw "Invalid WebVTT file, cue $id has invalid time range";
        }
        this.timeRange = timeRange;
      }
      else{
        text += '${parts[i]}\n';
      }
    }
    if (text.isEmpty){
      throw "Invalid WebVTT file, cue $id has no text";
    }
    this.text = text.substring(0, text.length - 1);
  }
}

TimeRange? tryParseTimeRange(String text){
  var parts = text.split('-->');
  if (parts.length != 2){
    return null;
  }
  var start = parts[0].trim();
  var end = parts[1].trim();
  if (start.isEmpty || end.isEmpty){
    return null;
  }
  var startTime = tryParseDuration(start);
  var endTime = tryParseDuration(end);
  if (startTime == null || endTime == null){
    return null;
  }
  return TimeRange(startTime, endTime);
}
Duration? tryParseDuration(String text){
  var parts = text.split(':');
  if (parts.length != 3){
    return null;
  }
  var hours = int.parse(parts[0]);
  var minutes = int.parse(parts[1]);
  late int seconds;
  int milliseconds = 0;
  if (parts[2].contains('.') || parts[2].contains(',')){
    var decimal = parts[2].split(RegExp('[.,]'));
    seconds = int.parse(decimal[0]);
    if (decimal[1].length != 3){
      return null;
    }
    milliseconds = int.parse(decimal[1]);
  }
  else{
    seconds = int.parse(parts[2]);
  }
  return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
}

class TimeRange {
  Duration start;
  Duration end;

  TimeRange(this.start, this.end);
  
}

class WebVTTParser{
  late String _text;
  late List<Cue> _cues;
  late int _currentCueIndex;
  late Duration duration;
  List<Cue> get cues => _cues;
  WebVTTParser(String text){
    _text = text;
    _cues = parseCues();
    _cues.sort((a, b) {
      return a.timeRange.start.compareTo(b.timeRange.start);
    },);
    //Get cue with longest time range end time
    Duration? longestCueEndTime;
    for (int i = 0; i < _cues.length; i++) {
      if (longestCueEndTime == null || _cues[i].timeRange.end > longestCueEndTime){
        longestCueEndTime = _cues[i].timeRange.end;
      }
    }
    if (longestCueEndTime == null){
      throw "Invalid WebVTT file, no cue has a time range";
    }
    duration = longestCueEndTime;
    _currentCueIndex = 0;
  }

  Cue? getCueAtPercent(double percent){
    var time = Duration(milliseconds: (duration.inMilliseconds * percent).toInt());
    return getCueAtStartTime(time);
  }

  Cue? getCueAtStartTime(Duration time){
    //Binary search
    var startIndex = 0;
    var endIndex = _cues.length - 1;
    while (startIndex <= endIndex){
      var middleIndex = (startIndex + endIndex) ~/ 2;
      var middleCue = _cues[middleIndex];
      if (time >=  middleCue.timeRange.start && time <= middleCue.timeRange.end){
        return middleCue;
      }
      else if (time < middleCue.timeRange.start){
        endIndex = middleIndex - 1;
      }
      else{
        startIndex = middleIndex + 1;
      }
    }
    return null;
  }

  List<Cue> parseCues(){
    var cues = <Cue>[];
    String normalizedText = _text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var sections = normalizedText.split('\n\n');
    for (int i = 0; i < sections.length; i++) {
      if (i == 0){
        if (sections[i].startsWith('WEBVTT')){
          continue;          
        }
        throw "Invalid WebVTT file";
      }
      if (sections[i].startsWith("NOTE")){
        continue;
      }
      if (sections[i].isEmpty){
        continue;
      }
      cues.add(Cue.fromString(sections[i]));
    }
    return cues;
  }
  
  Cue? get currentCue{
    if (_cues.isEmpty){
      return null;
    }
    return _cues[_currentCueIndex];
  }
}

