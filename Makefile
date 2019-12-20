refresh-public:
	cd src && rm -rf public/ && hugo && cd -

local:
	cd src && hugo server -D

page:
	cp -R src/public/* .

cleanup:
	rm *.html *.png *.xml *.json *.svg *.ico
	ls -d */ | grep -v "src/" | xargs rm -rf
