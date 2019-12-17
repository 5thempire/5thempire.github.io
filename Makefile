refresh-public:
	cd src && rm -rf public/ && hugo && cd -

local:
	cd src && hugo server -D

page:
	cp -R src/public/* .
