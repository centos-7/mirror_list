if ( "${path}" !~ */opt/dell/srvadmin/bin* ) then
	set path = ( $path /opt/dell/srvadmin/bin )
endif
if ( "${path}" !~ */opt/dell/srvadmin/sbin* ) then
	if ( `id -u` == 0 ) then
		set path = ( $path /opt/dell/srvadmin/sbin )
	endif
endif
