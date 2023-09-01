program p;

uses
	sysutils;

var
	tt:qword;
	
function clock_milliseconds:qword;
var
	tdt:TDateTime;
	tts:TTimeStamp;
begin
	tdt:=Now;
	tts:=DateTimeToTimeStamp(tdt);
	clock_milliseconds:=round(TimeStampToMSecs(tts));
end;

begin
	tt:=clock_milliseconds;
	write('Pause and press return: ');
	readln;
	writeln('You paused for ',clock_milliseconds-tt,' ms.');
end.