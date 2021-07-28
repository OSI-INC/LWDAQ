program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

const
  threshold = 1000;
  fifo_addr = $1200;
  fifo_length = 128;
  stimulus_addr = $E010;

type
  shortint = $0000..$FFFF; {16-bit unsigned}
  shortint_ptr = ^shortint;
  integer = $00000000..$FFFFFFFF; {32-bit unsigned}

var
  sum,sum_squares,variance : integer;
  index : 0..fifo_length-1;
  sample : shortint;

begin
  sum := 0;
  sum_squares := 0;
  for index := 0 to fifo_length-1 do begin
    sample := shortint_ptr(fifo_addr)^;  {FIFO provides a new byte for each read.}
    sum := sum + sample;
    sum_squares := sum_squares + (sample * sample);
  end;
  variance := sum_squares - (sum * sum); {we are avoiding a division operation}
  if variance > threshold * threshold * fifo_length then begin
    shortint_ptr(stimulus_addr)^ := 1;
  end;
end.