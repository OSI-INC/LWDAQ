program p;

const
	width=40;
	height=20;

var
	i,j:integer;
	
begin
	for j:=1 to height do begin
		for i:=1 to width do 
			if i=j then write('X')
			 else if (i+j=22) then write ('X')
			else write(' ');
		writeln;
	end;
end.