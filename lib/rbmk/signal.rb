module Signal
	%w( CHLD INT HUP QUIT TERM ).each { |signame| const_set signame.to_sym, list[signame] }
end
